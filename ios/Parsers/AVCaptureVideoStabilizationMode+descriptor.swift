//
//  AVCaptureVideoStabilizationMode+descriptor.swift
//  Cuvent
//
//  Created by Marc Rousavy on 29.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation

extension AVCaptureVideoStabilizationMode {
  init(withString string: String) throws {
    switch string {
    case "auto":
      self = .auto
      return
    case "cinematic":
      self = .cinematic
      return
    case "cinematic-extended":
      if #available(iOS 13.0, *) {
        self = .cinematicExtended
        return
      } else {
        throw EnumParserError.unsupportedOS(supportedOnOS: "iOS 13.0")
      }
    case "off":
      self = .off
      return
    case "standard":
      self = .standard
      return
    default:
      throw EnumParserError.invalidValue
    }
  }

  var descriptor: String {
    if #available(iOS 13.0, *) {
      switch self {
      case .cinematicExtended:
        return "cinematic-extended"
      default:
        break
      }
    }

    switch self {
    case .auto:
      return "auto"
    case .cinematic:
      return "cinematic"
    case .off:
      return "off"
    case .standard:
      return "standard"
    default:
      fatalError("AVCaptureVideoStabilizationMode has unknown state.")
    }
  }
}
