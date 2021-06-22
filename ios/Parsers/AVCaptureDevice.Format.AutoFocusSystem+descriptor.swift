//
//  AVCaptureDevice.Format.AutoFocusSystem+descriptor.swift
//  Cuvent
//
//  Created by Marc Rousavy on 29.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation

extension AVCaptureDevice.Format.AutoFocusSystem {
  init(withString string: String) throws {
    switch string {
    case "contrast-detection":
      self = .contrastDetection
      return
    case "phase-detection":
      self = .phaseDetection
      return
    case "none":
      self = .none
      return
    default:
      throw EnumParserError.invalidValue
    }
  }

  var descriptor: String {
    switch self {
    case .contrastDetection:
      return "contrast-detection"
    case .phaseDetection:
      return "phase-detection"
    case .none:
      return "none"
    @unknown default:
      fatalError("AVCaptureDevice.Format has unknown state.")
    }
  }
}
