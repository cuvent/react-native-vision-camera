//
//  CodeScannerOptions.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 03.10.23.
//  Copyright © 2023 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

struct CodeScannerOptions: Equatable {
  let codeTypes: [AVMetadataObject.ObjectType]
  let interval: Int
  let regionOfInterest: CGRect?

  init(fromJsValue dictionary: NSDictionary) throws {
    if let codeTypes = dictionary["codeTypes"] as? [String] {
      self.codeTypes = try codeTypes.compactMap { value in
        return try AVMetadataObject.ObjectType(withString: value)
      }
    } else {
      throw CameraError.parameter(.invalidCombination(provided: "codeScanner", missing: "codeTypes"))
    }

    if let interval = dictionary["interval"] as? Double {
      self.interval = Int(interval)
    } else {
      interval = 300
    }

    if let regionOfInterest = dictionary["regionOfInterest"] as? NSDictionary {
      guard let x = regionOfInterest["x"] as? Double,
            let y = regionOfInterest["y"] as? Double,
            let width = regionOfInterest["width"] as? Double,
            let height = regionOfInterest["height"] as? Double else {
        throw CameraError.parameter(.invalid(unionName: "regionOfInterest", receivedValue: regionOfInterest.description))
      }

      self.regionOfInterest = CGRect(x: x, y: y, width: width, height: height)
    } else {
      regionOfInterest = nil
    }
  }
}
