//
//  Promise.swift
//  Cuvent
//
//  Created by Marc Rousavy on 14.01.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import Foundation

// MARK: - Promise

/**
 * Represents a JavaScript Promise instance. `reject()` and `resolve()` should only be called once.
 */
class Promise {
  init(resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
    self.resolver = resolver
    self.rejecter = rejecter
  }

  func reject(error: CameraError, cause: NSError?) {
    rejecter(error.code, error.message, cause)
  }

  func reject(error: CameraError) {
    reject(error: error, cause: nil)
  }

  func resolve(_ value: Any?) {
    resolver(value)
  }

  func resolve() {
    resolve(nil)
  }

  // MARK: Private

  private let resolver: RCTPromiseResolveBlock
  private let rejecter: RCTPromiseRejectBlock
}

/**
 * Wrap a block with an automatic promise resolver and rejecter.
 *
 * The value returned by the `block` must be serializable by the React Native bridge, or `nil`.
 * The error thrown by the `block` should be a `CameraError`
 */
func withPromise(_ promise: Promise, _ block: () throws -> Any?) {
  do {
    let result = try block()
    promise.resolve(result)
  } catch let error as CameraError {
    promise.reject(error: error)
  } catch let error as NSError {
    promise.reject(error: CameraError.unknown(message: error.description), cause: error)
  }
}

/**
 * Wrap a block with an automatic promise resolver and rejecter.
 *
 * The value returned by the `block` must be serializable by the React Native bridge, or `nil`.
 * The error thrown by the `block` should be a `CameraError`
 */
func withPromise(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock, _ block: () throws -> Any?) {
  return withPromise(Promise(resolver: resolve, rejecter: reject), block)
}
