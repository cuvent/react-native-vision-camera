//
//  Collection+safe.swift
//  Cuvent
//
//  Created by Marc Rousavy on 10.01.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import Foundation

extension Collection {
  /**
   Returns the element at the specified index if it is within bounds, otherwise nil.
   */
  subscript(safe index: Index) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}
