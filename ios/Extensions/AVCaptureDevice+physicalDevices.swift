//
//  AVCaptureDevice+physicalDevices.swift
//  Cuvent
//
//  Created by Marc Rousavy on 10.01.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import AVFoundation

extension AVCaptureDevice {
  /**
   If the device is a virtual multi-cam, this returns `constituentDevices`, otherwise this returns an array of a single element, `self`
   */
  var physicalDevices: [AVCaptureDevice] {
    if #available(iOS 13.0, *), isVirtualDevice {
      return self.constituentDevices
    } else {
      return [self]
    }
  }
}
