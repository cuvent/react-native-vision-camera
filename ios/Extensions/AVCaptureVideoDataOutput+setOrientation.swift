//
//  AVCaptureVideoDataOutput+setOrientation.swift
//  Cuvent
//
//  Created by Marc Rousavy on 18.01.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import AVFoundation

extension AVCaptureVideoDataOutput {
  func setOrientation(forCameraPosition position: AVCaptureDevice.Position) {
    let isMirrored = position == .front
    connections.forEach { connection in
      if connection.isVideoMirroringSupported {
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = isMirrored
      }
      if connection.isVideoOrientationSupported {
        connection.videoOrientation = .portrait
      }
    }
  }
}
