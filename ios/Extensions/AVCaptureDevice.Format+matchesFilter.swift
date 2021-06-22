//
//  AVCaptureDevice.Format+matchesFilter.swift
//  Cuvent
//
//  Created by Marc Rousavy on 15.01.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import AVFoundation

extension AVCaptureDevice.Format {
  /**
   * Checks whether the given filter (NSDictionary, JSON Object) matches the given AVCaptureDevice Format.
   * The `dictionary` dictionary must be of type `CameraDeviceFormat` (from `CameraDevice.d.ts`)
   */
  func matchesFilter(_ filter: NSDictionary) -> Bool {
    if let photoHeight = filter.value(forKey: "photoHeight") as? NSNumber {
      if highResolutionStillImageDimensions.height != photoHeight.intValue {
        return false
      }
    }
    if let photoWidth = filter.value(forKey: "photoWidth") as? NSNumber {
      if highResolutionStillImageDimensions.width != photoWidth.intValue {
        return false
      }
    }

    if #available(iOS 13.0, *) {
      if let videoHeight = filter.value(forKey: "videoHeight") as? NSNumber {
        if self.formatDescription.presentationDimensions().height != CGFloat(videoHeight.doubleValue) {
          return false
        }
      }
      if let videoWidth = filter.value(forKey: "videoWidth") as? NSNumber {
        if self.formatDescription.presentationDimensions().width != CGFloat(videoWidth.doubleValue) {
          return false
        }
      }
      if let isHighestPhotoQualitySupported = filter.value(forKey: "isHighestPhotoQualitySupported") as? Bool {
        if self.isHighestPhotoQualitySupported != isHighestPhotoQualitySupported {
          return false
        }
      }
    }
    if let maxISO = filter.value(forKey: "maxISO") as? NSNumber {
      if self.maxISO != maxISO.floatValue {
        return false
      }
    }
    if let minISO = filter.value(forKey: "minISO") as? NSNumber {
      if self.minISO != minISO.floatValue {
        return false
      }
    }
    if let fieldOfView = filter.value(forKey: "fieldOfView") as? NSNumber {
      if videoFieldOfView != fieldOfView.floatValue {
        return false
      }
    }
    if let maxZoom = filter.value(forKey: "maxZoom") as? NSNumber {
      if videoMaxZoomFactor != CGFloat(maxZoom.floatValue) {
        return false
      }
    }
    if let colorSpaces = filter.value(forKey: "colorSpaces") as? [String] {
      let avColorSpaces = colorSpaces.map { try? AVCaptureColorSpace(string: $0) }
      let allColorSpacesIncluded = supportedColorSpaces.allSatisfy { avColorSpaces.contains($0) }
      if !allColorSpacesIncluded {
        return false
      }
    }
    if let frameRateRanges = filter.value(forKey: "frameRateRanges") as? [NSDictionary] {
      let allFrameRateRangesIncluded = videoSupportedFrameRateRanges.allSatisfy { range -> Bool in
        frameRateRanges.contains { dict -> Bool in
          guard let max = dict.value(forKey: "maxFrameRate") as? NSNumber,
                let min = dict.value(forKey: "minFrameRate") as? NSNumber
          else {
            return false
          }
          return range.maxFrameRate == max.doubleValue && range.minFrameRate == min.doubleValue
        }
      }
      if !allFrameRateRangesIncluded {
        return false
      }
    }
    if let autoFocusSystem = filter.value(forKey: "autoFocusSystem") as? String,
       let avAutoFocusSystem = try? AVCaptureDevice.Format.AutoFocusSystem(withString: autoFocusSystem) {
      if self.autoFocusSystem != avAutoFocusSystem {
        return false
      }
    }
    if let videoStabilizationModes = filter.value(forKey: "videoStabilizationModes") as? [String] {
      let avVideoStabilizationModes = videoStabilizationModes.map { try? AVCaptureVideoStabilizationMode(withString: $0) }
      let allStabilizationModesIncluded = self.videoStabilizationModes.allSatisfy { avVideoStabilizationModes.contains($0) }
      if !allStabilizationModesIncluded {
        return false
      }
    }

    return true
  }
}
