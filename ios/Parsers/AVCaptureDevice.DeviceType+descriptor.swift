//
//  AVCaptureDevice.DeviceType+descriptor.swift
//  Cuvent
//
//  Created by Marc Rousavy on 15.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

extension AVCaptureDevice.DeviceType {
  var descriptor: String {
    if #available(iOS 13.0, *) {
      switch self {
      case .builtInDualWideCamera:
        return "dual-wide-camera"
      case .builtInTripleCamera:
        return "triple-camera"
      case .builtInUltraWideCamera:
        return "ultra-wide-angle-camera"
      default:
        break
      }
    }
    switch self {
    case .builtInDualCamera:
      return "dual-camera"
    case .builtInTelephotoCamera:
      return "telephoto-camera"
    case .builtInWideAngleCamera:
      return "wide-angle-camera"
    default:
      // e.g. `.builtInTrueDepthCamera`
      fatalError("AVCaptureDevice.Position has unknown state.")
    }
  }
}
