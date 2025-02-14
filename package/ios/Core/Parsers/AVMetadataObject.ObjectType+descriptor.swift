//
//  AVMetadataObject.ObjectType+descriptor.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 03.10.23.
//  Copyright © 2023 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

extension AVMetadataObject.ObjectType {
  init(withString string: String) throws {
    switch string {
    case "code-128":
      self = .code128
      return
    case "code-39":
      self = .code39
      return
    case "code-93":
      self = .code93
      return
    case "codabar":
      if #available(iOS 15.4, *) {
        self = .codabar
      } else {
        throw CameraError.codeScanner(.codeTypeNotSupported(codeType: string))
      }
      return
    case "gs1-data-bar":
      if #available(iOS 15.4, *) {
        self = .gs1DataBar
      } else {
        throw CameraError.codeScanner(.codeTypeNotSupported(codeType: string))
      }
    case "gs1-data-bar-limited":
      if #available(iOS 15.4, *) {
        self = .gs1DataBarLimited
      } else {
        throw CameraError.codeScanner(.codeTypeNotSupported(codeType: string))
      }
    case "gs1-data-bar-expanded":
      if #available(iOS 15.4, *) {
        self = .gs1DataBarExpanded
      } else {
        throw CameraError.codeScanner(.codeTypeNotSupported(codeType: string))
      }
    case "ean-13":
      self = .ean13
      return
    case "ean-8":
      self = .ean8
      return
    case "itf":
      self = .interleaved2of5
      return
    case "itf-14":
      self = .itf14
      return
    case "upc-e":
      self = .upce
      return
    case "upc-a":
      self = .ean13
      return
    case "qr":
      self = .qr
      return
    case "pdf-417":
      self = .pdf417
      return
    case "aztec":
      self = .aztec
      return
    case "data-matrix":
      self = .dataMatrix
      return
    default:
      throw EnumParserError.invalidValue
    }
  }

  var descriptor: String {
    if #available(iOS 15.4, *) {
      if self == .codabar {
        return "codabar"
      }
    }
    if #available(iOS 15.4, *) {
      if self == .gs1DataBar {
        return "gs1-data-bar"
      }
    }
    if #available(iOS 15.4, *) {
      if self == .gs1DataBarLimited {
        return "gs1-data-bar-limited"
      }
    }
    if #available(iOS 15.4, *) {
      if self == .gs1DataBarExpanded {
        return "gs1-data-bar-expanded"
      }
    }

    switch self {
    case .code128:
      return "code-128"
    case .code39:
      return "code-39"
    case .code93:
      return "code-93"
    case .ean13:
      return "ean-13"
    case .ean8:
      return "ean-8"
    case .interleaved2of5:
      return "itf"
    case .itf14:
      return "itf-14"
    case .upce:
      return "upce"
    case .qr:
      return "qr"
    case .pdf417:
      return "pdf-417"
    case .aztec:
      return "aztec"
    case .dataMatrix:
      return "data-matrix"
    default:
      return "unknown"
    }
  }
}
