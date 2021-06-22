//
//  ReactLogger.swift
//  Cuvent
//
//  Created by Marc Rousavy on 15.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import Foundation

// MARK: - ReactLogger

enum ReactLogger {
  /**
   A function that logs to the JavaScript console.
   */
  static var ConsoleLogFunction: ConsoleLogFunction?

  /**
   Log a message to the console in the format of `VisionCamera.[caller-function-name]: [message]`

   @discussion
   If the global ConsoleLogFunction is set, this function also logs to the JavaScript console (console.log, console.trace, console.warn or console.error)
   This function also always logs to [RCTDefaultLogFunction].
   In non-DEBUG builds, this function is no-op.
   */
  @inlinable
  static func log(level: RCTLogLevel,
                  message: String,
                  alsoLogToJS: Bool = false,
                  _ file: String = #file,
                  _ lineNumber: Int = #line,
                  _ function: String = #function) {
    #if DEBUG
      if alsoLogToJS, let log = ConsoleLogFunction {
        log(level, "[native] VisionCamera.\(function): \(message)")
      }
      RCTDefaultLogFunction(level, RCTLogSource.native, file, lineNumber as NSNumber, "VisionCamera.\(function): \(message)")
    #endif
  }
}
