//
//  CameraSession.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 11.10.23.
//  Copyright © 2023 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation
import UIKit

/**
 A fully-featured Camera Session supporting preview, video, photo, frame processing, and code scanning outputs.
 All changes to the session have to be controlled via the `configure` function.
 */
final class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
  // Configuration
  private var isInitialized = false
  var configuration: CameraConfiguration?
  var currentConfigureCall: DispatchTime = .now()
  // Capture Session
  let captureSession = AVCaptureSession()
  let audioCaptureSession = AVCaptureSession()
  // Inputs & Outputs
  var videoDeviceInput: AVCaptureDeviceInput?
  var audioDeviceInput: AVCaptureDeviceInput?
  var photoOutput: AVCapturePhotoOutput?
  var videoOutput: AVCaptureVideoDataOutput?
  var audioOutput: AVCaptureAudioDataOutput?
  var codeScannerOutput: AVCaptureMetadataOutput?
  // State
  var metadataProvider = MetadataProvider()
  var recordingSession: RecordingSession?
  var didCancelRecording = false
  var orientationManager = OrientationManager()

  // Callbacks
  weak var delegate: CameraSessionDelegate?

  // Public accessors
  var maxZoom: Double {
    if let device = videoDeviceInput?.device {
      return device.activeFormat.videoMaxZoomFactor
    }
    return 1.0
  }

  /**
   Create a new instance of the `CameraSession`.
   The `onError` callback is used for any runtime errors.
   */
  override init() {
    super.init()
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(sessionRuntimeError),
                                           name: .AVCaptureSessionRuntimeError,
                                           object: captureSession)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(sessionRuntimeError),
                                           name: .AVCaptureSessionRuntimeError,
                                           object: audioCaptureSession)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(audioSessionInterrupted),
                                           name: AVAudioSession.interruptionNotification,
                                           object: AVAudioSession.sharedInstance)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(deviceOrientationChanged),
                                           name: UIDevice.orientationDidChangeNotification,
                                           object: nil)
  }

  private func initialize() {
    if isInitialized {
      return
    }
    orientationManager.delegate = self
    isInitialized = true
  }

  deinit {
    NotificationCenter.default.removeObserver(self,
                                              name: .AVCaptureSessionRuntimeError,
                                              object: captureSession)
    NotificationCenter.default.removeObserver(self,
                                              name: .AVCaptureSessionRuntimeError,
                                              object: audioCaptureSession)
    NotificationCenter.default.removeObserver(self,
                                              name: AVAudioSession.interruptionNotification,
                                              object: AVAudioSession.sharedInstance)
    NotificationCenter.default.removeObserver(self,
                                              name: UIDevice.orientationDidChangeNotification,
                                              object: nil)
  }

  /**
   Creates a PreviewView for the current Capture Session
   */
  func createPreviewView(frame: CGRect) -> PreviewView {
    return PreviewView(frame: frame, session: captureSession)
  }

  func onConfigureError(_ error: Error) {
    if let error = error as? CameraError {
      // It's a typed Error
      delegate?.onError(error)
    } else {
      // It's any kind of unknown error
      let cameraError = CameraError.unknown(message: error.localizedDescription)
      delegate?.onError(cameraError)
    }
  }

  /**
   Update the session configuration.
   Any changes in here will be re-configured only if required, and under a lock (in this case, the serial cameraQueue DispatchQueue).
   The `configuration` object is a copy of the currently active configuration that can be modified by the caller in the lambda.
   */
  func configure(_ lambda: @escaping (_ configuration: CameraConfiguration) throws -> Void) {
    initialize()

    VisionLogger.log(level: .info, message: "configure { ... }: Waiting for lock...")

    // Set up Camera (Video) Capture Session (on camera queue, acts like a lock)
    CameraQueues.cameraQueue.async {
      // Let caller configure a new configuration for the Camera.
      let config = CameraConfiguration(copyOf: self.configuration)
      do {
        try lambda(config)
      } catch CameraConfiguration.AbortThrow.abort {
        // call has been aborted and changes shall be discarded
        return
      } catch {
        // another error occured, possibly while trying to parse enums
        self.onConfigureError(error)
        return
      }
      let difference = CameraConfiguration.Difference(between: self.configuration, and: config)

      VisionLogger.log(level: .info, message: "configure { ... }: Updating CameraSession Configuration... \(difference)")

      do {
        // If needed, configure the AVCaptureSession (inputs, outputs)
        if difference.isSessionConfigurationDirty {
          self.captureSession.beginConfiguration()

          // 1. Update input device
          if difference.inputChanged {
            try self.configureDevice(configuration: config)
          }
          // 2. Update outputs
          if difference.outputsChanged {
            try self.configureOutputs(configuration: config)
          }
          // 3. Update Video Stabilization
          if difference.videoStabilizationChanged {
            self.configureVideoStabilization(configuration: config)
          }
          // 4. Update target output orientation
          if difference.orientationChanged {
            self.orientationManager.setTargetOutputOrientation(config.outputOrientation)
          }
        }

        guard let device = self.videoDeviceInput?.device else {
          throw CameraError.device(.noDevice)
        }

        // If needed, configure the AVCaptureDevice (format, zoom, low-light-boost, ..)
        if difference.isDeviceConfigurationDirty {
          try device.lockForConfiguration()
          defer {
            device.unlockForConfiguration()
          }

          // 5. Configure format
          if difference.formatChanged {
            try self.configureFormat(configuration: config, device: device)
          }
          // 6. After step 2. and 4., we also need to configure some output properties that depend on format.
          //    This needs to be done AFTER we updated the `format`, as this controls the supported properties.
          if difference.outputsChanged || difference.formatChanged {
            self.configureVideoOutputFormat(configuration: config)
            self.configurePhotoOutputFormat(configuration: config)
          }
          // 7. Configure side-props (fps, lowLightBoost)
          if difference.sidePropsChanged {
            try self.configureSideProps(configuration: config, device: device)
          }
          // 8. Configure zoom
          if difference.zoomChanged {
            self.configureZoom(configuration: config, device: device)
          }
          // 9. Configure exposure bias
          if difference.exposureChanged {
            self.configureExposure(configuration: config, device: device)
          }
        }

        if difference.isSessionConfigurationDirty {
          // We commit the session config updates AFTER the device config,
          // that way we can also batch those changes into one update instead of doing two updates.
          self.captureSession.commitConfiguration()
        }

        // 10. Start or stop the session if needed
        self.checkIsActive(configuration: config)

        // 11. Enable or disable the Torch if needed (requires session to be running)
        if difference.torchChanged {
          try device.lockForConfiguration()
          defer {
            device.unlockForConfiguration()
          }
          try self.configureTorch(configuration: config, device: device)
        }

        // After configuring, set this to the new configuration.
        self.configuration = config
      } catch {
        self.onConfigureError(error)
      }

      // Set up Audio Capture Session (on audio queue)
      if difference.audioSessionChanged {
        CameraQueues.audioQueue.async {
          do {
            // Lock Capture Session for configuration
            VisionLogger.log(level: .info, message: "Beginning AudioSession configuration...")
            self.audioCaptureSession.beginConfiguration()

            try self.configureAudioSession(configuration: config)

            // Unlock Capture Session again and submit configuration to Hardware
            self.audioCaptureSession.commitConfiguration()
            VisionLogger.log(level: .info, message: "Committed AudioSession configuration!")
          } catch {
            self.onConfigureError(error)
          }
        }
      }

      // Set up Location streaming (on location queue)
      if difference.locationChanged {
        CameraQueues.locationQueue.async {
          do {
            VisionLogger.log(level: .info, message: "Beginning Location Output configuration...")
            try self.configureLocationOutput(configuration: config)
            VisionLogger.log(level: .info, message: "Finished Location Output configuration!")
          } catch {
            self.onConfigureError(error)
          }
        }
      }
    }
  }

  /**
   Starts or stops the CaptureSession if needed (`isActive`)
   */
  private func checkIsActive(configuration: CameraConfiguration) {
    if configuration.isActive == captureSession.isRunning {
      return
    }

    // Start/Stop session
    if configuration.isActive {
      captureSession.startRunning()
      updateCaptureSessionInputOrientation()
      delegate?.onCameraStarted()
    } else {
      captureSession.stopRunning()
      delegate?.onCameraStopped()
    }
  }

  public final func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    switch captureOutput {
    case is AVCaptureVideoDataOutput:
      onVideoFrame(sampleBuffer: sampleBuffer, orientation: connection.orientation, isMirrored: connection.isVideoMirrored)
    case is AVCaptureAudioDataOutput:
      onAudioFrame(sampleBuffer: sampleBuffer)
    default:
      break
    }
  }

  private final func onVideoFrame(sampleBuffer: CMSampleBuffer, orientation: Orientation, isMirrored: Bool) {
    if let recordingSession {
      do {
        // Write the Video Buffer to the .mov/.mp4 file
        try recordingSession.append(buffer: sampleBuffer, ofType: .video)
      } catch let error as CameraError {
        delegate?.onError(error)
      } catch {
        delegate?.onError(.capture(.unknown(message: error.localizedDescription)))
      }
    }

    if let delegate {
      // Call Frame Processor (delegate) for every Video Frame
      delegate.onFrame(sampleBuffer: sampleBuffer, orientation: orientation, isMirrored: isMirrored)
    }
  }

  private final func onAudioFrame(sampleBuffer: CMSampleBuffer) {
    if let recordingSession {
      do {
        // Synchronize the Audio Buffer with the Video Session's time because it's two separate
        // AVCaptureSessions, then write it to the .mov/.mp4 file
        audioCaptureSession.synchronizeBuffer(sampleBuffer, toSession: captureSession)
        try recordingSession.append(buffer: sampleBuffer, ofType: .audio)
      } catch let error as CameraError {
        delegate?.onError(error)
      } catch {
        delegate?.onError(.capture(.unknown(message: error.localizedDescription)))
      }
    }
  }

  // pragma MARK: Notifications

  @objc
  func sessionRuntimeError(notification: Notification) {
    VisionLogger.log(level: .error, message: "Unexpected Camera Runtime Error occured!")
    guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
      return
    }

    // Notify consumer about runtime error
    delegate?.onError(.unknown(message: error._nsError.description, cause: error._nsError))

    let shouldRestart = configuration?.isActive == true
    if shouldRestart {
      // restart capture session after an error occured
      CameraQueues.cameraQueue.async {
        self.captureSession.startRunning()
        self.updateCaptureSessionInputOrientation()
      }
    }
  }

  @objc
  func deviceOrientationChanged(notification _: Notification) {
    updateCaptureSessionInputOrientation()
  }

  func updateCaptureSessionInputOrientation() {
    // Lock the camera session, to be sure that it doesn't conflict with other session changes.
    CameraQueues.cameraQueue.async {
      // Because statusBarOrientation requires it, as it's an UI operation.
      DispatchQueue.main.async {
        let interfaceOrientation = UIApplication.shared.statusBarOrientation // Set up orientation for all connections.
        for connection in self.captureSession.connections {
          switch interfaceOrientation {
          case .portrait:
            connection.videoOrientation = .portrait
          case .landscapeLeft:
            connection.videoOrientation = .landscapeLeft
          case .landscapeRight:
            connection.videoOrientation = .landscapeRight
          case .portraitUpsideDown:
            connection.videoOrientation = .portraitUpsideDown
          case .unknown:
            connection.videoOrientation = .portrait
          }
        }
      }
    }
  }
}
