//
//  AVAudioSession+updateCategory.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 01.06.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

extension AVAudioSession {
  /**
   Calls [setCategory] if the given category or options are not equal to the currently set category and options and reactivates the session.
   */
  func updateCategory(_ category: AVAudioSession.Category, options: AVAudioSession.CategoryOptions = []) throws {
    if self.category != category || categoryOptions.rawValue != options.rawValue {
      ReactLogger.log(level: .info,
                      message: "Changing AVAudioSession category from \(self.category.rawValue) -> \(category.rawValue)",
                      alsoLogToJS: true)
      //try setActive(false, options: .notifyOthersOnDeactivation)
      try setCategory(category, options: options)
      //try setActive(true)
    }
  }
}
