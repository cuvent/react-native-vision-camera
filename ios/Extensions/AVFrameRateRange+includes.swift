//
//  AVFrameRateRange+includes.swift
//  Cuvent
//
//  Created by Marc Rousavy on 15.01.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import AVFoundation

extension AVFrameRateRange {
  /**
   * Returns true if this [AVFrameRateRange] contains the given [fps]
   */
  func includes(fps: Double) -> Bool {
    return fps >= minFrameRate && fps <= maxFrameRate
  }
}
