//
//  AVCaptureSession+setVideoStabilizationMode.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 02.06.21.
//  Copyright © 2021 Facebook. All rights reserved.
//

import Foundation
import AVFoundation

extension AVCaptureSession {
  /**
   Set the given video stabilization mode for all capture connections.
   */
  func setVideoStabilizationMode(_ mode: String) {
    guard let mode = try? AVCaptureVideoStabilizationMode(withString: mode) else {
      return
    }
    connections.forEach { connection in
      if connection.isVideoStabilizationSupported {
        connection.preferredVideoStabilizationMode = mode
      }
    }
  }
}
