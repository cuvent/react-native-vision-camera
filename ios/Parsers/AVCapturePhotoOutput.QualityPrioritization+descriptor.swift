//
//  AVCapturePhotoOutput.QualityPrioritization+descriptor.swift
//  Cuvent
//
//  Created by Marc Rousavy on 15.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

@available(iOS 13.0, *)
extension AVCapturePhotoOutput.QualityPrioritization {
  init?(withString string: String) {
    switch string {
    case "speed":
      self = .speed
      return
    case "quality":
      self = .quality
      return
    case "balanced":
      self = .balanced
      return
    default:
      return nil
    }
  }
}
