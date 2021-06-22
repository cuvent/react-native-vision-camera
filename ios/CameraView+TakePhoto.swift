//
//  CameraView+TakePhoto.swift
//  Cuvent
//
//  Created by Marc Rousavy on 16.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation

// MARK: - TakePhotoOptions

struct TakePhotoOptions {
  init(fromDictionary dictionary: NSDictionary) {
    if let videoCodec = dictionary.value(forKey: "videoCodec") as? String {
      self.videoCodec = AVVideoCodecType(withString: videoCodec)
    }
    qualityPrioritization = dictionary.value(forKey: "qualityPrioritization") as? String
  }

  var videoCodec: AVVideoCodecType?
  var qualityPrioritization: String?
}

extension CameraView {
  func takePhoto(options: NSDictionary, promise: Promise) {
    cameraQueue.async {
      guard let photoOutput = self.photoOutput,
            let videoDeviceInput = self.videoDeviceInput else {
        if self.photo?.boolValue == true {
          promise.reject(error: .session(.cameraNotReady))
          return
        } else {
          promise.reject(error: .capture(.photoNotEnabled))
          return
        }
      }

      ReactLogger.log(level: .info, message: "Capturing photo...")

      var format: [String: Any]?
      // photo codec
      if let photoCodecString = options["photoCodec"] as? String {
        guard let photoCodec = AVVideoCodecType(withString: photoCodecString) else {
          promise.reject(error: .parameter(.invalid(unionName: "PhotoCodec", receivedValue: photoCodecString)))
          return
        }
        if photoOutput.availablePhotoCodecTypes.contains(photoCodec) {
          format = [AVVideoCodecKey: photoCodec]
        } else {
          promise.reject(error: .capture(.invalidPhotoCodec))
          return
        }
      }

      // Create photo settings
      let photoSettings = AVCapturePhotoSettings(format: format)

      // default, overridable settings if high quality capture was enabled
      if self.enableHighQualityPhotos?.boolValue == true {
        photoSettings.isHighResolutionPhotoEnabled = true
        if #available(iOS 13.0, *) {
          photoSettings.photoQualityPrioritization = .quality
        }
      }

      // flash
      if videoDeviceInput.device.isFlashAvailable, let flash = options["flash"] as? String {
        guard let flashMode = AVCaptureDevice.FlashMode(withString: flash) else {
          promise.reject(error: .parameter(.invalid(unionName: "FlashMode", receivedValue: flash)))
          return
        }
        photoSettings.flashMode = flashMode
      }

      // depth data
      photoSettings.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliveryEnabled
      if #available(iOS 12.0, *) {
        photoSettings.isPortraitEffectsMatteDeliveryEnabled = photoOutput.isPortraitEffectsMatteDeliveryEnabled
      }

      // quality prioritization
      if #available(iOS 13.0, *), let qualityPrioritization = options["qualityPrioritization"] as? String {
        guard let photoQualityPrioritization = AVCapturePhotoOutput.QualityPrioritization(withString: qualityPrioritization) else {
          promise.reject(error: .parameter(.invalid(unionName: "QualityPrioritization", receivedValue: qualityPrioritization)))
          return
        }
        photoSettings.photoQualityPrioritization = photoQualityPrioritization
      }

      // red-eye reduction
      if #available(iOS 12.0, *), let autoRedEyeReduction = options["enableAutoRedEyeReduction"] as? Bool {
        photoSettings.isAutoRedEyeReductionEnabled = autoRedEyeReduction
      }

      // stabilization
      if let enableAutoStabilization = options["enableAutoStabilization"] as? Bool {
        photoSettings.isAutoStillImageStabilizationEnabled = enableAutoStabilization
      }

      // distortion correction
      if #available(iOS 14.1, *), let enableAutoDistortionCorrection = options["enableAutoDistortionCorrection"] as? Bool {
        photoSettings.isAutoContentAwareDistortionCorrectionEnabled = enableAutoDistortionCorrection
      }

      photoOutput.capturePhoto(with: photoSettings, delegate: PhotoCaptureDelegate(promise: promise))

      // Assume that `takePhoto` is always called with the same parameters, so prepare the next call too.
      photoOutput.setPreparedPhotoSettingsArray([photoSettings], completionHandler: nil)
    }
  }
}
