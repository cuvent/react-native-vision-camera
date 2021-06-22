//
//  MakeReactError.swift
//  Cuvent
//
//  Created by Marc Rousavy on 15.01.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import Foundation

func makeReactError(_ cameraError: CameraError, cause: NSError?) -> [String: Any] {
  var causeDictionary: [String: Any]?
  if let cause = cause {
    causeDictionary = RCTMakeError("\(cause.domain): \(cause.code) \(cause.description)", nil, cause.userInfo)
  }
  return RCTMakeError(
    "\(cameraError.code): \(cameraError.message)",
    nil,
    [
      "code": cameraError.code,
      "message": cameraError.message,
      "cause": causeDictionary ?? NSNull(),
    ]
  )
}

func makeReactError(_ cameraError: CameraError) -> [String: Any] {
  return makeReactError(cameraError, cause: nil)
}
