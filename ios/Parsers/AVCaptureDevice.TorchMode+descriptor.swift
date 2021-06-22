//
//  AVCaptureDevice.TorchMode+descriptor.swift
//  Cuvent
//
//  Created by Marc Rousavy on 18.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation

extension AVCaptureDevice.TorchMode {
  init?(withString string: String) {
    switch string {
    case "on":
      self = .on
      return
    case "off":
      self = .off
      return
    case "auto":
      self = .auto
      return
    default:
      return nil
    }
  }
}
