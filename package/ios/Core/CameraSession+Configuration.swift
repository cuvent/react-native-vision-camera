//
//  CameraSession+Configuration.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 12.10.23.
//  Copyright © 2023 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

extension CameraSession {
  // pragma MARK: Input Device

  /**
   Configures the Input Device (`cameraId`)
   */
  func configureDevice(configuration: CameraConfiguration) throws {
    VisionLogger.log(level: .info, message: "Configuring Input Device...")

    // Remove all inputs
    for input in captureSession.inputs {
      captureSession.removeInput(input)
    }
    videoDeviceInput = nil

    #if targetEnvironment(simulator)
      // iOS Simulators don't have Cameras
      throw CameraError.device(.notAvailableOnSimulator)
    #endif

    guard let cameraId = configuration.cameraId else {
      throw CameraError.device(.noDevice)
    }

    VisionLogger.log(level: .info, message: "Configuring Camera \(cameraId)...")
    // Video Input (Camera Device/Sensor)
    guard let videoDevice = AVCaptureDevice(uniqueID: cameraId) else {
      throw CameraError.device(.invalid)
    }
    let input = try AVCaptureDeviceInput(device: videoDevice)
    guard captureSession.canAddInput(input) else {
      throw CameraError.parameter(.unsupportedInput(inputDescriptor: "video-input"))
    }
    captureSession.addInput(input)
    videoDeviceInput = input

    // Update Orientation manager (uses device relative sensor orientation)
    orientationManager.setInputDevice(videoDevice)

    VisionLogger.log(level: .info, message: "Successfully configured Input Device!")
  }

  // pragma MARK: Outputs

  /**
   Configures all outputs (`photo` + `video` + `depth` + `codeScanner`)
   */
  func configureOutputs(configuration: CameraConfiguration) throws {
    VisionLogger.log(level: .info, message: "Configuring Outputs...")

    // Remove all outputs
    for output in captureSession.outputs {
      captureSession.removeOutput(output)
    }
    photoOutput = nil
    videoOutput = nil
    depthOutput = nil
    codeScannerOutput = nil
    outputSynchronizer = nil

    // Photo Output
    if case let .enabled(photo) = configuration.photo {
      VisionLogger.log(level: .info, message: "Adding Photo output...")

      // 1. Add
      let photoOutput = AVCapturePhotoOutput()
      guard captureSession.canAddOutput(photoOutput) else {
        throw CameraError.parameter(.unsupportedOutput(outputDescriptor: "photo-output"))
      }
      captureSession.addOutput(photoOutput)

      // 2. Configure
      if #available(iOS 13.0, *) {
        let qualityPrioritization = AVCapturePhotoOutput.QualityPrioritization(fromQualityBalance: photo.qualityBalance)
        photoOutput.maxPhotoQualityPrioritization = qualityPrioritization
      }
      if photoOutput.isDepthDataDeliverySupported {
        photoOutput.isDepthDataDeliveryEnabled = photo.enableDepthData
      }
      if photoOutput.isPortraitEffectsMatteDeliverySupported {
        photoOutput.isPortraitEffectsMatteDeliveryEnabled = photo.enablePortraitEffectsMatte
      }
      photoOutput.isMirrored = configuration.isMirrored
      // TODO: Enable isResponsiveCaptureEnabled? (iOS 17+)
      // TODO: Enable isFastCapturePrioritizationEnabled? (iOS 17+)

      self.photoOutput = photoOutput
    }

    // Video Output + Frame Processor
    if case let .enabled(video) = configuration.video {
      VisionLogger.log(level: .info, message: "Adding Video Data output...")

      // 1. Add
      let videoOutput = AVCaptureVideoDataOutput()
      guard captureSession.canAddOutput(videoOutput) else {
        throw CameraError.parameter(.unsupportedOutput(outputDescriptor: "video-output"))
      }
      captureSession.addOutput(videoOutput)

      // 2. Configure Video
      if configuration.isMirrored {
        // 2.1. If mirroring is enabled, mirror all connections along the vertical axis
        videoOutput.isMirrored = true
        if videoOutput.orientation.isLandscape {
          // 2.2. If we have a landscape orientation, we need to flip it to counter the mirroring on the wrong axis.
          videoOutput.orientation = videoOutput.orientation.flipped()
          VisionLogger.log(level: .info, message: "AVCaptureVideoDataOutput will rotate Frames to \(videoOutput.orientation)...")
        }
      }

      // 3. Configure Depth
      if video.enableDepth {
        // Video is synchronized with depth data - use a joined delegate!
        // 3.1. Create depth output
        let depthOutput = AVCaptureDepthDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = false
        depthOutput.alwaysDiscardsLateDepthData = false
        depthOutput.isFilteringEnabled = false
        // 3.2. Add depth output to session
        captureSession.addOutput(depthOutput)
        depthOutput.orientation = videoOutput.orientation
        // 3.3. Set up a synchronizer between video and depth data
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [depthOutput, videoOutput])
        outputSynchronizer!.setDelegate(self, queue: CameraQueues.videoQueue)
        self.depthOutput = depthOutput
      } else {
        // Video is the only output - use it's own delegate
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: CameraQueues.videoQueue)
      }

      self.videoOutput = videoOutput
    }

    // Code Scanner
    if case let .enabled(codeScanner) = configuration.codeScanner {
      VisionLogger.log(level: .info, message: "Adding Code Scanner output...")
      let codeScannerOutput = AVCaptureMetadataOutput()

      // 1. Add
      guard captureSession.canAddOutput(codeScannerOutput) else {
        throw CameraError.codeScanner(.notCompatibleWithOutputs)
      }
      captureSession.addOutput(codeScannerOutput)

      // 2. Configure
      let options = codeScanner.options
      codeScannerOutput.setMetadataObjectsDelegate(self, queue: CameraQueues.codeScannerQueue)
      for type in codeScanner.options.codeTypes {
        // CodeScanner::availableMetadataObjectTypes depends on the connection to the
        // AVCaptureSession, so this list is only available after we add the output to the session.
        if !codeScannerOutput.availableMetadataObjectTypes.contains(type) {
          throw CameraError.codeScanner(.codeTypeNotSupported(codeType: type.descriptor))
        }
      }
      codeScannerOutput.metadataObjectTypes = options.codeTypes
      if let rectOfInterest = options.regionOfInterest {
        codeScannerOutput.rectOfInterest = rectOfInterest
      }

      self.codeScannerOutput = codeScannerOutput
    }

    // Re-initialize Orientations
    configurePreviewOrientation(orientationManager.previewOrientation)
    configureOutputOrientation(orientationManager.outputOrientation)

    // Done!
    VisionLogger.log(level: .info, message: "Successfully configured all outputs!")

    // Notify delegate
    delegate?.onSessionInitialized()
  }

  // pragma MARK: Video Stabilization
  func configureVideoStabilization(configuration: CameraConfiguration) {
    for output in captureSession.outputs {
      for connection in output.connections {
        if connection.isVideoStabilizationSupported {
          connection.preferredVideoStabilizationMode = configuration.videoStabilizationMode.toAVCaptureVideoStabilizationMode()
        }
      }
    }
  }

  // pragma MARK: Format

  /**
   Configures the active format (`format`)
   */
  func configureFormat(configuration: CameraConfiguration, device: AVCaptureDevice) throws {
    guard let targetFormat = configuration.format else {
      // No format was set, just use the default.
      return
    }

    VisionLogger.log(level: .info, message: "Configuring Format (\(targetFormat))...")

    let currentFormat = CameraDeviceFormat(fromFormat: device.activeFormat)
    if currentFormat == targetFormat {
      VisionLogger.log(level: .info, message: "Already selected active format, no need to configure.")
      return
    }

    // Find matching format (JS Dictionary -> strongly typed Swift class)
    let format = device.formats.first { targetFormat.isEqualTo(format: $0) }
    guard let format else {
      throw CameraError.format(.invalidFormat)
    }

    // Set new device Format
    device.activeFormat = format

    VisionLogger.log(level: .info, message: "Successfully configured Format!")
  }

  func configureVideoOutputFormat(configuration: CameraConfiguration) {
    guard case let .enabled(video) = configuration.video,
          let videoOutput else {
      // Video is not enabled
      return
    }

    do {
      // Configure the VideoOutput Settings to use the given Pixel Format.
      // We need to run this after device.activeFormat has been set, otherwise the VideoOutput can't stream the given Pixel Format.
      let pixelFormatType = try video.getPixelFormat(for: videoOutput)
      videoOutput.videoSettings = [
        String(kCVPixelBufferPixelFormatTypeKey): pixelFormatType,
      ]
    } catch {
      // Catch the error and send to JS as a soft-exception.
      // The default PixelFormat will be used.
      onConfigureError(error)
    }
  }

  func configurePhotoOutputFormat(configuration _: CameraConfiguration) {
    guard let videoDeviceInput, let photoOutput else {
      // Photo is not enabled
      return
    }

    // Configure the PhotoOutput Settings to use the given max-resolution.
    // We need to run this after device.activeFormat has been set, otherwise the resolution is different.
    let format = videoDeviceInput.device.activeFormat
    if #available(iOS 16.0, *) {
      photoOutput.maxPhotoDimensions = format.photoDimensions
    } else {
      photoOutput.isHighResolutionCaptureEnabled = true
    }
  }

  // pragma MARK: Side-Props

  /**
   Configures format-dependant "side-props" (`fps`, `lowLightBoost`)
   */
  func configureSideProps(configuration: CameraConfiguration, device: AVCaptureDevice) throws {
    // Configure FPS
    if let minFps = configuration.minFps,
       let maxFps = configuration.maxFps {
      let fpsRanges = device.activeFormat.videoSupportedFrameRateRanges
      if !fpsRanges.contains(where: { $0.minFrameRate <= Double(minFps) }) {
        throw CameraError.format(.invalidFps(fps: Int(minFps)))
      }
      if !fpsRanges.contains(where: { $0.maxFrameRate >= Double(maxFps) }) {
        throw CameraError.format(.invalidFps(fps: Int(maxFps)))
      }

      device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: minFps)
      device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: maxFps)
    } else {
      device.activeVideoMaxFrameDuration = CMTime.invalid
      device.activeVideoMinFrameDuration = CMTime.invalid
    }

    // Configure Low-Light-Boost
    if device.automaticallyEnablesLowLightBoostWhenAvailable != configuration.enableLowLightBoost {
      guard device.isLowLightBoostSupported else {
        throw CameraError.device(.lowLightBoostNotSupported)
      }
      device.automaticallyEnablesLowLightBoostWhenAvailable = configuration.enableLowLightBoost
    }

    // Configure auto-focus
    if device.isFocusModeSupported(.continuousAutoFocus) {
      if device.isFocusPointOfInterestSupported {
        device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
      }
      device.focusMode = .continuousAutoFocus
    }
    if device.isExposureModeSupported(.continuousAutoExposure) {
      if device.isExposurePointOfInterestSupported {
        device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
      }
      device.exposureMode = .continuousAutoExposure
    }
  }

  /**
   Configures the torch.
   The CaptureSession has to be running for the Torch to work.
   */
  func configureTorch(configuration: CameraConfiguration, device: AVCaptureDevice) throws {
    // Configure Torch
    let torchMode = configuration.torch.toTorchMode()
    if device.torchMode != torchMode {
      guard device.hasTorch else {
        throw CameraError.device(.flashUnavailable)
      }

      device.torchMode = torchMode
      if torchMode == .on {
        try device.setTorchModeOn(level: 1.0)
      }
    }
  }

  // pragma MARK: Zoom

  /**
   Configures zoom (`zoom`)
   */
  func configureZoom(configuration: CameraConfiguration, device: AVCaptureDevice) {
    guard let zoom = configuration.zoom else {
      return
    }

    let clamped = max(min(zoom, device.activeFormat.videoMaxZoomFactor), device.minAvailableVideoZoomFactor)
    device.videoZoomFactor = clamped
  }

  // pragma MARK: Exposure

  /**
   Configures exposure (`exposure`) as a bias that adjusts exposureTime and ISO.
   */
  func configureExposure(configuration: CameraConfiguration, device: AVCaptureDevice) {
    guard let exposure = configuration.exposure else {
      return
    }

    let clamped = min(max(exposure, device.minExposureTargetBias), device.maxExposureTargetBias)
    device.setExposureTargetBias(clamped)
  }

  // pragma MARK: Audio

  /**
   Configures the Audio Capture Session with an audio input and audio data output.
   */
  func configureAudioSession(configuration: CameraConfiguration) throws {
    VisionLogger.log(level: .info, message: "Configuring Audio Session...")

    // Prevent iOS from automatically configuring the Audio Session for us
    audioCaptureSession.automaticallyConfiguresApplicationAudioSession = false
    let enableAudio = configuration.audio != .disabled

    // Check microphone permission
    if enableAudio {
      let audioPermissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
      if audioPermissionStatus != .authorized {
        throw CameraError.permission(.microphone)
      }
    }

    // Remove all current inputs
    for input in audioCaptureSession.inputs {
      audioCaptureSession.removeInput(input)
    }
    audioDeviceInput = nil

    // Audio Input (Microphone)
    if enableAudio {
      VisionLogger.log(level: .info, message: "Adding Audio input...")
      guard let microphone = AVCaptureDevice.default(for: .audio) else {
        throw CameraError.device(.microphoneUnavailable)
      }
      let input = try AVCaptureDeviceInput(device: microphone)
      guard audioCaptureSession.canAddInput(input) else {
        throw CameraError.parameter(.unsupportedInput(inputDescriptor: "audio-input"))
      }
      audioCaptureSession.addInput(input)
      audioDeviceInput = input
    }

    // Remove all current outputs
    for output in audioCaptureSession.outputs {
      audioCaptureSession.removeOutput(output)
    }
    audioOutput = nil

    // Audio Output
    if enableAudio {
      VisionLogger.log(level: .info, message: "Adding Audio Data output...")
      let output = AVCaptureAudioDataOutput()
      guard audioCaptureSession.canAddOutput(output) else {
        throw CameraError.parameter(.unsupportedOutput(outputDescriptor: "audio-output"))
      }
      output.setSampleBufferDelegate(self, queue: CameraQueues.audioQueue)
      audioCaptureSession.addOutput(output)
      audioOutput = output
    }
  }
}
