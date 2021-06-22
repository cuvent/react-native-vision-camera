//
//  AVCaptureDevice+neutralZoom.swift
//  Cuvent
//
//  Created by Marc Rousavy on 10.01.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import AVFoundation

extension AVCaptureDevice {
  /**
   Get the value at which the Zoom factor is neutral.

   For normal wide-angle devices, this is always going to be 1.0, since this is the default scale.
   For devices with an ultra-wide-angle camera, this value is going to be the value where the wide-angle device will switch over.
   */
  var neutralZoomFactor: CGFloat {
    if #available(iOS 13.0, *) {
      if let indexOfWideAngle = self.constituentDevices.firstIndex(where: { $0.deviceType == .builtInWideAngleCamera }) {
        if let zoomFactor = self.virtualDeviceSwitchOverVideoZoomFactors[safe: indexOfWideAngle - 1] {
          return CGFloat(zoomFactor.doubleValue)
        }
      }
    }
    return 1.0
  }
}
