//
//  AVCaptureDevice+toDictionary.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 21.09.23.
//  Copyright © 2023 mrousavy. All rights reserved.
//

import AVFoundation

extension AVCaptureDevice {
  func toDictionary() -> [String: Any] {
    let formats = formats.map { CameraDeviceFormat(fromFormat: $0) }

    return [
      "id": uniqueID,
      "physicalDevices": physicalDevices.map(\.deviceType.physicalDeviceDescriptor),
      "position": position.descriptor,
      "name": localizedName,
      "hasFlash": hasFlash,
      "hasTorch": hasTorch,
      "minFocusDistance": minFocusDistance,
      "minZoom": minAvailableVideoZoomFactor,
      "maxZoom": maxAvailableVideoZoomFactor,
      "neutralZoom": neutralZoomFactor,
      "minExposure": minExposureTargetBias,
      "maxExposure": maxExposureTargetBias,
      "isMultiCam": isMultiCam,
      "supportsRawCapture": false, // TODO: supportsRawCapture
      "supportsLowLightBoost": isLowLightBoostSupported,
      "supportsFocus": isFocusPointOfInterestSupported,
      "hardwareLevel": HardwareLevel.full.jsValue,
      "sensorOrientation": sensorOrientation.jsValue,
      "formats": formats.map { $0.toJSValue() },
      "supportsDepthData": hasMediaType(.depthData),
    ]
  }
}
