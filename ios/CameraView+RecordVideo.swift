//
//  CameraView+RecordVideo.swift
//  Cuvent
//
//  Created by Marc Rousavy on 16.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation

private var hasLoggedVideoFrameDropWarning = false
private var hasLoggedFrameProcessorFrameDropWarning = false

// MARK: - CameraView + AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate

extension CameraView: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
  /**
   Starts a video + audio recording with a custom Asset Writer.
   */
  func startRecording(options: NSDictionary, callback jsCallbackFunc: @escaping RCTResponseSenderBlock) {
    cameraQueue.async {
      ReactLogger.log(level: .info, message: "Starting Video recording...")
      let callback = Callback(jsCallbackFunc)

      var fileType = AVFileType.mov
      if let fileTypeOption = options["fileType"] as? String {
        guard let parsed = try? AVFileType(withString: fileTypeOption) else {
          callback.reject(error: .parameter(.invalid(unionName: "fileType", receivedValue: fileTypeOption)))
          return
        }
        fileType = parsed
      }

      let errorPointer = ErrorPointer(nilLiteral: ())
      let fileExtension = fileType.descriptor ?? "mov"
      guard let tempFilePath = RCTTempFilePath(fileExtension, errorPointer) else {
        callback.reject(error: .capture(.createTempFileError), cause: errorPointer?.pointee)
        return
      }

      ReactLogger.log(level: .info, message: "File path: \(tempFilePath)")
      let tempURL = URL(string: "file://\(tempFilePath)")!

      if let flashMode = options["flash"] as? String {
        // use the torch as the video's flash
        self.setTorchMode(flashMode)
      }

      guard let videoOutput = self.videoOutput else {
        if self.video?.boolValue == true {
          callback.reject(error: .session(.cameraNotReady))
          return
        } else {
          callback.reject(error: .capture(.videoNotEnabled))
          return
        }
      }
      guard let videoInput = self.videoDeviceInput else {
        callback.reject(error: .session(.cameraNotReady))
        return
      }

      // TODO: The startRecording() func cannot be async because RN doesn't allow
      //       both a callback and a Promise in a single function. Wait for TurboModules?
      //       This means that any errors that occur in this function have to be delegated through
      //       the callback, but I'd prefer for them to throw for the original function instead.

      let enableAudio = self.audio?.boolValue == true

      let onFinish = { (status: AVAssetWriter.Status, error: Error?) in
        defer {
          self.recordingSession = nil
          if enableAudio {
            self.audioQueue.async {
              self.deactivateAudioSession()
            }
          }
        }

        self.isRecording = false
        ReactLogger.log(level: .info, message: "RecordingSession finished with status \(status.descriptor).")

        if let error = error as NSError? {
          if error.domain == "capture/aborted" {
            callback.reject(error: .capture(.aborted), cause: error)
          } else {
            callback.reject(error: .capture(.unknown(message: "An unknown recording error occured! \(error.description)")), cause: error)
          }
        } else {
          if status == .completed {
            callback.resolve([
              "path": self.recordingSession!.url.absoluteString,
              "duration": self.recordingSession!.duration,
            ])
          } else {
            callback.reject(error: .unknown(message: "AVAssetWriter completed with status: \(status.descriptor)"))
          }
        }
      }

      do {
        self.recordingSession = try RecordingSession(url: tempURL,
                                                     fileType: fileType,
                                                     completion: onFinish)
      } catch let error as NSError {
        callback.reject(error: .capture(.createRecorderError(message: nil)), cause: error)
        return
      }

      // Init Video
      guard let videoSettings = videoOutput.recommendedVideoSettingsForAssetWriter(writingTo: fileType),
            !videoSettings.isEmpty else {
        callback.reject(error: .capture(.createRecorderError(message: "Failed to get video settings!")))
        return
      }
      // get pixel format (420f, 420v)
      let pixelFormat = CMFormatDescriptionGetMediaSubType(videoInput.device.activeFormat.formatDescription)
      self.recordingSession!.initializeVideoWriter(withSettings: videoSettings,
                                                   pixelFormat: pixelFormat)

      // Init Audio (optional, async)
      if enableAudio {
        // Activate Audio Session (blocking)
        self.activateAudioSession()

        if let audioOutput = self.audioOutput,
           let audioSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: fileType) as? [String: Any] {
          self.recordingSession!.initializeAudioWriter(withSettings: audioSettings)
        }
      }

      // start recording session with or without audio.
      do {
        try self.recordingSession!.start()
      } catch {
        callback.reject(error: .capture(.createRecorderError(message: "RecordingSession failed to start writing.")))
        return
      }
      self.isRecording = true
    }
  }

  func stopRecording(promise: Promise) {
    cameraQueue.async {
      self.isRecording = false

      withPromise(promise) {
        guard let recordingSession = self.recordingSession else {
          throw CameraError.capture(.noRecordingInProgress)
        }
        recordingSession.finish()
        return nil
      }
    }
  }

  // TODO: Implement for JS
  func pauseRecording(promise: Promise) {
    cameraQueue.async {
      withPromise(promise) {
        if self.isRecording {
          self.isRecording = false
          return nil
        } else {
          throw CameraError.capture(.noRecordingInProgress)
        }
      }
    }
  }

  // TODO: Implement for JS
  func resumeRecording(promise: Promise) {
    cameraQueue.async {
      withPromise(promise) {
        if !self.isRecording {
          self.isRecording = true
          return nil
        } else {
          throw CameraError.capture(.noRecordingInProgress)
        }
      }
    }
  }

  public final func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
    // Video Recording runs in the same queue
    if isRecording {
      guard let recordingSession = recordingSession else {
        invokeOnError(.capture(.unknown(message: "isRecording was true but the RecordingSession was null!")))
        return
      }

      switch captureOutput {
      case is AVCaptureVideoDataOutput:
        recordingSession.appendBuffer(sampleBuffer, type: .video, timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
      case is AVCaptureAudioDataOutput:
        let timestamp = CMSyncConvertTime(CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
                                          from: audioCaptureSession.masterClock!,
                                          to: captureSession.masterClock!)
        recordingSession.appendBuffer(sampleBuffer, type: .audio, timestamp: timestamp)
      default:
        break
      }
    }

    // TODO: resize using VideoToolbox (VTPixelTransferSession)

    if let frameProcessor = frameProcessorCallback,
       captureOutput is AVCaptureVideoDataOutput {
      // check if last frame was x nanoseconds ago, effectively throttling FPS
      let diff = DispatchTime.now().uptimeNanoseconds - lastFrameProcessorCall.uptimeNanoseconds
      let secondsPerFrame = 1.0 / frameProcessorFps.doubleValue
      let nanosecondsPerFrame = secondsPerFrame * 1_000_000_000.0

      if diff > UInt64(nanosecondsPerFrame) {
        if !isRunningFrameProcessor {
          // we're not in the middle of executing the Frame Processor, so prepare for next call.
          var bufferCopy: CMSampleBuffer?
          CMSampleBufferCreateCopy(allocator: kCFAllocatorDefault,
                                   sampleBuffer: sampleBuffer,
                                   sampleBufferOut: &bufferCopy)
          if let bufferCopy = bufferCopy {
            // successfully copied buffer, dispatch frame processor call.
            CameraQueues.frameProcessorQueue.async {
              self.isRunningFrameProcessor = true
              let frame = Frame(buffer: bufferCopy, orientation: self.bufferOrientation)
              frameProcessor(frame)
              self.isRunningFrameProcessor = false
            }
            lastFrameProcessorCall = DispatchTime.now()
          } else {
            // failed to create a buffer copy.
            ReactLogger.log(level: .error, message: "Failed to copy buffer! Frame Processor cannot be called.", alsoLogToJS: true)
          }
        } else {
          // we're still in the middle of executing a Frame Processor for a previous frame, notify user about dropped frame.
          if !hasLoggedFrameProcessorFrameDropWarning {
            ReactLogger.log(level: .warning,
                            message: "Your Frame Processor took so long to execute that a frame was dropped. " +
                              "Either throttle your Frame Processor's frame rate using the `frameProcessorFps` prop, or optimize " +
                              "it's execution speed. (This warning will only be shown once)",
                            alsoLogToJS: true)
            hasLoggedFrameProcessorFrameDropWarning = true
          }
        }
      }
    }
  }

  #if DEBUG
    public final func captureOutput(_ captureOutput: AVCaptureOutput, didDrop buffer: CMSampleBuffer, from _: AVCaptureConnection) {
      if !hasLoggedVideoFrameDropWarning && captureOutput is AVCaptureVideoDataOutput {
        let reason = findFrameDropReason(inBuffer: buffer)
        ReactLogger.log(level: .warning,
                        message: "Dropped a Frame - This might indicate that your frame rate is higher than the phone can currently process. " +
                          "Throttle the Camera frame rate using the `fps` prop and make sure the device stays in optimal condition for recording. " +
                          "Frame drop reason: \(reason). (This warning will only be shown once)",
                        alsoLogToJS: true)
        hasLoggedVideoFrameDropWarning = true
      }
    }

    private final func findFrameDropReason(inBuffer buffer: CMSampleBuffer) -> String {
      var mode: CMAttachmentMode = 0
      guard let reason = CMGetAttachment(buffer,
                                         key: kCMSampleBufferAttachmentKey_DroppedFrameReason,
                                         attachmentModeOut: &mode) else {
        return "unknown"
      }
      return String(describing: reason)
    }
  #endif

  /**
   Gets the orientation of the CameraView's images (CMSampleBuffers).
   */
  var bufferOrientation: UIImage.Orientation {
    guard let cameraPosition = videoDeviceInput?.device.position else {
      return .up
    }

    switch UIDevice.current.orientation {
    case .portrait:
      return cameraPosition == .front ? .leftMirrored : .right

    case .landscapeLeft:
      return cameraPosition == .front ? .downMirrored : .up

    case .portraitUpsideDown:
      return cameraPosition == .front ? .rightMirrored : .left

    case .landscapeRight:
      return cameraPosition == .front ? .upMirrored : .down

    case .unknown, .faceUp, .faceDown:
      fallthrough
    @unknown default:
      return .up
    }
  }
}
