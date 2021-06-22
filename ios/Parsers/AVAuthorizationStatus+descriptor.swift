//
//  AVAuthorizationStatus+descriptor.swift
//  Cuvent
//
//  Created by Marc Rousavy on 29.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation

extension AVAuthorizationStatus {
  var descriptor: String {
    switch self {
    case .authorized:
      return "authorized"
    case .denied:
      return "denied"
    case .notDetermined:
      return "not-determined"
    case .restricted:
      return "restricted"
    @unknown default:
      fatalError("AVAuthorizationStatus has unknown state.")
    }
  }
}
