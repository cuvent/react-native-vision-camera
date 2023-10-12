//
//  Orientation.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 11.10.23.
//  Copyright © 2023 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

/**
 The Orientation used for the Preview, Photo, Video and Frame Processor outputs.
 */
enum Orientation {
  /**
   Phone is in upright portrait mode, home button/indicator is at the bottom
   */
  case portrait
  /**
   Phone is in landscape mode, home button/indicator is on the left
   */
  case landscapeLeft
  /**
   Phone is in upside-down portrait mode, home button/indicator is at the top
   */
  case portraitUpsideDown
  /**
   Phone is in landscape mode, home button/indicator is on the right
   */
  case landscapeRight

  init(fromTypeScriptUnion union: String) throws {
    switch union {
    case "portrait":
      self = .portrait
    case "landscape-left":
      self = .landscapeLeft
    case "portrait-upside-down":
      self = .portraitUpsideDown
    case "landscape-right":
      self = .landscapeRight
    default:
      throw CameraError.parameter(.invalid(unionName: "orientation", receivedValue: union))
    }
  }
  
  func toJSValue() -> String {
    switch self {
    case .portrait:
      return "portrait"
    case .landscapeLeft:
      return "landscape-left"
    case .portraitUpsideDown:
      return "portrait-upside-down"
    case .landscapeRight:
      return "landscape-right"
    }
  }

  func toAVCaptureVideoOrientation() -> AVCaptureVideoOrientation {
    switch self {
    case .portrait:
      return .portrait
    case .landscapeLeft:
      return .landscapeLeft
    case .portraitUpsideDown:
      return .portraitUpsideDown
    case .landscapeRight:
      return .landscapeRight
    }
  }

  func toDegrees() -> Double {
    switch self {
    case .portrait:
      return 0
    case .landscapeLeft:
      return 90
    case .portraitUpsideDown:
      return 180
    case .landscapeRight:
      return 270
    }
  }
  
  func rotateRight() -> Orientation {
    switch self {
    case .portrait:
      return .landscapeLeft
    case .landscapeLeft:
      return .portraitUpsideDown
    case .portraitUpsideDown:
      return .landscapeRight
    case .landscapeRight:
      return .portrait
    }
  }
}
