//
//  AVCaptureDevice+isMultiCam.swift
//  Cuvent
//
//  Created by Marc Rousavy on 07.01.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import AVFoundation

extension AVCaptureDevice {
  /**
   Returns true if the device is a virtual multi-cam, false otherwise.
   */
  var isMultiCam: Bool {
    if #available(iOS 13.0, *) {
      return self.isVirtualDevice
    } else {
      return false
    }
  }
}
