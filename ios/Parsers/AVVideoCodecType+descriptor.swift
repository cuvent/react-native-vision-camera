//
//  AVVideoCodecType+descriptor.swift
//  Cuvent
//
//  Created by Marc Rousavy on 15.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

extension AVVideoCodecType {
  init?(withString string: String) {
    switch string {
    case "h264":
      self = .h264
      return
    case "hevc":
      self = .hevc
      return
    case "hevc-alpha":
      if #available(iOS 13.0, *) {
        self = .hevcWithAlpha
        return
      } else {
        return nil
      }
    case "jpeg":
      self = .jpeg
      return
    case "pro-res-422":
      self = .proRes422
      return
    case "pro-res-422-hq":
      if #available(iOS 13.0, *) {
        self = .proRes422HQ
        return
      } else {
        return nil
      }
    case "pro-res-422-lt":
      if #available(iOS 13.0, *) {
        self = .proRes422LT
        return
      } else {
        return nil
      }
    case "pro-res-422-proxy":
      if #available(iOS 13.0, *) {
        self = .proRes422Proxy
        return
      } else {
        return nil
      }
    case "pro-res-4444":
      self = .proRes4444
      return
    default:
      return nil
    }
  }

  var descriptor: String {
    if #available(iOS 13.0, *) {
      switch self {
      case .hevcWithAlpha:
        return "hevc-alpha"
      case .proRes422HQ:
        return "pro-res-422-hq"
      case .proRes422LT:
        return "pro-res-422-lt"
      case .proRes422Proxy:
        return "pro-res-422-proxy"
      default:
        break
      }
    }
    switch self {
    case .h264:
      return "h264"
    case .hevc:
      return "hevc"
    case .jpeg:
      return "jpeg"
    case .proRes422:
      return "pro-res-422"
    case .proRes4444:
      return "pro-res-4444"
    default:
      fatalError("AVVideoCodecType has unknown state.")
    }
  }
}
