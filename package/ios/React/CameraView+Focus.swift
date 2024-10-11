//
//  CameraView+Focus.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 12.10.23.
//  Copyright © 2023 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

extension CameraView {
  func focus(pointInPreviewViewCoordinates point: CGPoint, promise: Promise) {
    withPromise(promise) {
      guard let previewView = self.previewView else {
        throw CameraError.capture(.focusRequiresPreview)
      }
      let normalized = previewView.captureDevicePointConverted(fromLayerPoint: point)
      try cameraSession.focus(point: normalized)
      return nil
    }
  }

  func focus(pointInCameraCoordinates point: CGPoint, promise: Promise) {
    withPromise(promise) {
      try cameraSession.focus(point: point)
      return nil
    }
  }
}
