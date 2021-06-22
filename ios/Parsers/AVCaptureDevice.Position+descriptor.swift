//
//  AVCaptureDevice.Position+String.swift
//  Cuvent
//
//  Created by Marc Rousavy on 15.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

extension AVCaptureDevice.Position {
  var descriptor: String {
    switch self {
    case .back:
      return "back"
    case .front:
      return "front"
    case .unspecified:
      return "unspecified"
    @unknown default:
      fatalError("AVCaptureDevice.Position has unknown state.")
    }
  }
}
