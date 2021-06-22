//
//  AVCaptureDevice.Format+toDictionary.swift
//  Cuvent
//
//  Created by Marc Rousavy on 15.01.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import AVFoundation

private func getAllVideoStabilizationModes() -> [AVCaptureVideoStabilizationMode] {
  var modes: [AVCaptureVideoStabilizationMode] = [.auto, .cinematic, .off, .standard]
  if #available(iOS 13, *) {
    modes.append(.cinematicExtended)
  }
  return modes
}

extension AVCaptureDevice.Format {
  var videoStabilizationModes: [AVCaptureVideoStabilizationMode] {
    return getAllVideoStabilizationModes().filter { self.isVideoStabilizationModeSupported($0) }
  }

  func toDictionary() -> [String: Any] {
    var dict: [String: Any] = [
      "videoStabilizationModes": videoStabilizationModes.map(\.descriptor),
      "autoFocusSystem": autoFocusSystem.descriptor,
      "photoHeight": highResolutionStillImageDimensions.height,
      "photoWidth": highResolutionStillImageDimensions.width,
      "maxISO": maxISO,
      "minISO": minISO,
      "fieldOfView": videoFieldOfView,
      "maxZoom": videoMaxZoomFactor,
      "colorSpaces": supportedColorSpaces.map(\.descriptor),
      "supportsVideoHDR": isVideoHDRSupported,
      "supportsPhotoHDR": false,
      "frameRateRanges": videoSupportedFrameRateRanges.map {
        [
          "minFrameRate": $0.minFrameRate,
          "maxFrameRate": $0.maxFrameRate,
        ]
      },
    ]
    if #available(iOS 13.0, *) {
      dict["isHighestPhotoQualitySupported"] = self.isHighestPhotoQualitySupported
      dict["videoHeight"] = self.formatDescription.presentationDimensions().height
      dict["videoWidth"] = self.formatDescription.presentationDimensions().width
    }
    return dict
  }
}
