//
//  CameraView+AVCaptureSession.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 26.03.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

/**
 Extension for CameraView that sets up the AVCaptureSession, Device and Format.
 */
extension CameraView {
  // pragma MARK: Configure Capture Session

  /**
   Configures the Capture Session.
   */
  final func configureCaptureSession() {
    ReactLogger.log(level: .info, message: "Configuring Session...")
    isReady = false

    #if targetEnvironment(simulator)
      invokeOnError(.device(.notAvailableOnSimulator))
      return
    #endif

    guard cameraId != nil else {
      invokeOnError(.device(.noDevice))
      return
    }
    let cameraId = self.cameraId! as String

    ReactLogger.log(level: .info, message: "Initializing Camera with device \(cameraId)...")
    captureSession.beginConfiguration()
    defer {
      captureSession.commitConfiguration()
    }

    // If preset is set, use preset. Otherwise use format.
    if let preset = self.preset {
      var sessionPreset: AVCaptureSession.Preset?
      do {
        sessionPreset = try AVCaptureSession.Preset(withString: preset)
      } catch let EnumParserError.unsupportedOS(supportedOnOS: os) {
        invokeOnError(.parameter(.unsupportedOS(unionName: "Preset", receivedValue: preset, supportedOnOs: os)))
        return
      } catch {
        invokeOnError(.parameter(.invalid(unionName: "Preset", receivedValue: preset)))
        return
      }
      if sessionPreset != nil {
        if captureSession.canSetSessionPreset(sessionPreset!) {
          captureSession.sessionPreset = sessionPreset!
        } else {
          // non-fatal error, so continue with configuration
          invokeOnError(.format(.invalidPreset(preset: preset)))
        }
      }
    }

    // pragma MARK: Capture Session Inputs
    // Video Input
    do {
      if let videoDeviceInput = self.videoDeviceInput {
        captureSession.removeInput(videoDeviceInput)
        self.videoDeviceInput = nil
      }
      ReactLogger.log(level: .info, message: "Adding Video input...")
      guard let videoDevice = AVCaptureDevice(uniqueID: cameraId) else {
        invokeOnError(.device(.invalid))
        return
      }
      videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
      guard captureSession.canAddInput(videoDeviceInput!) else {
        invokeOnError(.parameter(.unsupportedInput(inputDescriptor: "video-input")))
        return
      }
      captureSession.addInput(videoDeviceInput!)
    } catch {
      invokeOnError(.device(.invalid))
      return
    }

    // pragma MARK: Capture Session Outputs

    // Photo Output
    if let photoOutput = self.photoOutput {
      captureSession.removeOutput(photoOutput)
      self.photoOutput = nil
    }
    if photo?.boolValue == true {
      ReactLogger.log(level: .info, message: "Adding Photo output...")
      photoOutput = AVCapturePhotoOutput()
      photoOutput!.isDepthDataDeliveryEnabled = photoOutput!.isDepthDataDeliverySupported && enableDepthData

      if enableHighQualityCapture?.boolValue == true {
        photoOutput!.isHighResolutionCaptureEnabled = true
        if #available(iOS 13.0, *) {
          photoOutput!.isVirtualDeviceConstituentPhotoDeliveryEnabled = photoOutput!.isVirtualDeviceConstituentPhotoDeliverySupported
          photoOutput!.maxPhotoQualityPrioritization = .quality
        } else {
          photoOutput!.isDualCameraDualPhotoDeliveryEnabled = photoOutput!.isDualCameraDualPhotoDeliverySupported
        }
      }
      if #available(iOS 12.0, *) {
        photoOutput!.isPortraitEffectsMatteDeliveryEnabled = photoOutput!.isPortraitEffectsMatteDeliverySupported && self.enablePortraitEffectsMatteDelivery
      }
      guard captureSession.canAddOutput(photoOutput!) else {
        invokeOnError(.parameter(.unsupportedOutput(outputDescriptor: "photo-output")))
        return
      }
      captureSession.addOutput(photoOutput!)
      if videoDeviceInput!.device.position == .front {
        photoOutput!.mirror()
      }
    }

    // Video Output + Frame Processor
    if let videoOutput = self.videoOutput {
      captureSession.removeOutput(videoOutput)
      self.videoOutput = nil
    }
    if video?.boolValue == true {
      ReactLogger.log(level: .info, message: "Adding Video Data output...")
      videoOutput = AVCaptureVideoDataOutput()
      guard captureSession.canAddOutput(videoOutput!) else {
        invokeOnError(.parameter(.unsupportedOutput(outputDescriptor: "video-output")))
        return
      }
      videoOutput!.setSampleBufferDelegate(self, queue: videoQueue)
      videoOutput!.alwaysDiscardsLateVideoFrames = true
      captureSession.addOutput(videoOutput!)
      if videoDeviceInput!.device.position == .front {
        videoOutput!.mirror()
      }
    }

    invokeOnInitialized()
    isReady = true
    ReactLogger.log(level: .info, message: "Session successfully configured!")
  }

  // pragma MARK: Configure Device

  /**
   Configures the Video Device with the given FPS, HDR and ColorSpace.
   */
  final func configureDevice() {
    ReactLogger.log(level: .info, message: "Configuring Device...")
    guard let device = videoDeviceInput?.device else {
      invokeOnError(.session(.cameraNotReady))
      return
    }

    do {
      try device.lockForConfiguration()

      if let fps = self.fps?.int32Value {
        let duration = CMTimeMake(value: 1, timescale: fps)
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
      } else {
        device.activeVideoMinFrameDuration = CMTime.invalid
        device.activeVideoMaxFrameDuration = CMTime.invalid
      }
      if hdr != nil {
        if hdr == true && !device.activeFormat.isVideoHDRSupported {
          invokeOnError(.format(.invalidHdr))
          return
        }
        if !device.automaticallyAdjustsVideoHDREnabled {
          if device.isVideoHDREnabled != hdr!.boolValue {
            device.isVideoHDREnabled = hdr!.boolValue
          }
        }
      }
      if lowLightBoost != nil {
        if lowLightBoost == true && !device.isLowLightBoostSupported {
          invokeOnError(.device(.lowLightBoostNotSupported))
          return
        }
        if device.automaticallyEnablesLowLightBoostWhenAvailable != lowLightBoost!.boolValue {
          device.automaticallyEnablesLowLightBoostWhenAvailable = lowLightBoost!.boolValue
        }
      }
      if colorSpace != nil, let avColorSpace = try? AVCaptureColorSpace(string: String(colorSpace!)) {
        device.activeColorSpace = avColorSpace
      }

      device.unlockForConfiguration()
      ReactLogger.log(level: .info, message: "Device successfully configured!")
    } catch let error as NSError {
      invokeOnError(.device(.configureError), cause: error)
      return
    }
  }

  // pragma MARK: Configure Format

  /**
   Configures the Video Device to find the best matching Format.
   */
  final func configureFormat() {
    ReactLogger.log(level: .info, message: "Configuring Format...")
    guard let filter = self.format else {
      // Format Filter was null. Ignore it.
      return
    }
    guard let device = videoDeviceInput?.device else {
      invokeOnError(.session(.cameraNotReady))
      return
    }

    if device.activeFormat.matchesFilter(filter) {
      ReactLogger.log(level: .info, message: "Active format already matches filter.")
      return
    }

    // get matching format
    let matchingFormats = device.formats.filter { $0.matchesFilter(filter) }.sorted { $0.isBetterThan($1) }
    guard let format = matchingFormats.first else {
      invokeOnError(.format(.invalidFormat))
      return
    }

    do {
      try device.lockForConfiguration()
      device.activeFormat = format
      device.unlockForConfiguration()
      ReactLogger.log(level: .info, message: "Format successfully configured!")
    } catch let error as NSError {
      invokeOnError(.device(.configureError), cause: error)
      return
    }
  }

  // pragma MARK: Notifications/Interruptions

  @objc
  func sessionRuntimeError(notification: Notification) {
    ReactLogger.log(level: .error, message: "Unexpected Camera Runtime Error occured!", alsoLogToJS: true)
    guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
      return
    }

    invokeOnError(.unknown(message: error._nsError.description), cause: error._nsError)

    if isActive {
      // restart capture session after an error occured
      cameraQueue.async {
        self.captureSession.startRunning()
      }
    }
  }
}
