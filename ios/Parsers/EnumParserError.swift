//
//  EnumParserError.swift
//  Cuvent
//
//  Created by Marc Rousavy on 18.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import Foundation

/**
 An error raised when the given descriptor (TypeScript string union type) cannot be parsed and converted to a Swift enum.
 */
enum EnumParserError: Error {
  /**
   Raised when the descriptor is not supported on the current OS.
   */
  case unsupportedOS(supportedOnOS: String)
  /**
   Raised when the descriptor does not match any of the possible values.
   */
  case invalidValue
}
