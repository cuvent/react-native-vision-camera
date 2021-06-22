//
//  AVCaptureColorSpace+descriptor.swift
//  Cuvent
//
//  Created by Marc Rousavy on 19.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation

extension AVCaptureColorSpace {
  init(string: String) throws {
    switch string {
    case "hlg-bt2020":
      if #available(iOS 14.1, *) {
        self = .HLG_BT2020
      } else {
        throw EnumParserError.unsupportedOS(supportedOnOS: "14.1")
      }
      return
    case "p3-d65":
      self = .P3_D65
      return
    case "srgb":
      self = .sRGB
      return
    default:
      throw EnumParserError.invalidValue
    }
  }

  var descriptor: String {
    switch self {
    case .HLG_BT2020:
      return "hlg-bt2020"
    case .P3_D65:
      return "p3-d65"
    case .sRGB:
      return "srgb"
    default:
      fatalError("AVCaptureDevice.Position has unknown state.")
    }
  }
}
