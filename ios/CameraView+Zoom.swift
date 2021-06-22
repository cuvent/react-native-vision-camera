//
//  CameraView+Zoom.swift
//  Cuvent
//
//  Created by Marc Rousavy on 18.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import Foundation

extension CameraView {
  var minAvailableZoom: CGFloat {
    return videoDeviceInput?.device.minAvailableVideoZoomFactor ?? 1
  }

  var maxAvailableZoom: CGFloat {
    return videoDeviceInput?.device.activeFormat.videoMaxZoomFactor ?? 1
  }

  @objc
  final func onPinch(_ gesture: UIPinchGestureRecognizer) {
    guard let device = videoDeviceInput?.device else {
      return
    }

    let scale = max(min(gesture.scale * pinchScaleOffset, device.activeFormat.videoMaxZoomFactor), CGFloat(1.0))
    if gesture.state == .ended {
      pinchScaleOffset = scale
      return
    }

    do {
      try device.lockForConfiguration()
      device.videoZoomFactor = scale
      device.unlockForConfiguration()
    } catch {
      invokeOnError(.device(.configureError))
    }
  }

  func addPinchGestureRecognizer() {
    removePinchGestureRecognizer()
    pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
    addGestureRecognizer(pinchGestureRecognizer!)
  }

  func removePinchGestureRecognizer() {
    if let pinchGestureRecognizer = self.pinchGestureRecognizer {
      removeGestureRecognizer(pinchGestureRecognizer)
      self.pinchGestureRecognizer = nil
    }
  }

  @objc
  final func zoom(factor: CGFloat, animated: Bool) {
    guard let device = videoDeviceInput?.device else {
      return
    }

    do {
      try device.lockForConfiguration()
      let clamped = max(min(factor, device.activeFormat.videoMaxZoomFactor), CGFloat(1.0))
      if animated {
        device.ramp(toVideoZoomFactor: clamped, withRate: 1)
      } else {
        device.videoZoomFactor = clamped
      }
      device.unlockForConfiguration()
    } catch {
      invokeOnError(.device(.configureError))
    }
  }
}
