//
//  AVCaptureSession.Preset+descriptor.swift
//  Cuvent
//
//  Created by Marc Rousavy on 15.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

extension AVCaptureSession.Preset {
  init(withString string: String) throws {
    switch string {
    case "cif-352x288":
      self = .cif352x288
      return
    case "hd-1280x720":
      self = .hd1280x720
      return
    case "hd-1920x1080":
      self = .hd1920x1080
      return
    case "hd-3840x2160":
      self = .hd4K3840x2160
      return
    case "high":
      self = .high
      return
    case "iframe-1280x720":
      self = .iFrame1280x720
      return
    case "iframe-960x540":
      self = .iFrame960x540
      return
    case "input-priority":
      self = .inputPriority
      return
    case "low":
      self = .low
      return
    case "medium":
      self = .medium
      return
    case "photo":
      self = .photo
      return
    case "vga-640x480":
      self = .vga640x480
      return
    default:
      throw EnumParserError.invalidValue
    }
  }
}
