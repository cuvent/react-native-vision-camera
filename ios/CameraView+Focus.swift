//
//  CameraView+focus.swift
//  mrousavy
//
//  Created by Marc Rousavy on 19.02.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import Foundation

extension CameraView {
  private func rotateFrameSize(frameSize: CGSize, orientation: UIInterfaceOrientation) -> CGSize {
    switch orientation {
    case .portrait, .portraitUpsideDown, .unknown:
      // swap width and height since the input orientation is rotated
      return CGSize(width: frameSize.height, height: frameSize.width)
    case .landscapeLeft, .landscapeRight:
      // is same as camera sensor orientation
      return frameSize
    @unknown default:
      return frameSize
    }
  }

  /// Converts a Point in the UI View Layer to a Point in the Camera Frame coordinate system
  func convertLayerPointToFramePoint(layerPoint point: CGPoint) -> CGPoint {
    guard let previewView = previewView else {
      invokeOnError(.session(.cameraNotReady))
      return .zero
    }
    guard let videoDeviceInput = videoDeviceInput else {
      invokeOnError(.session(.cameraNotReady))
      return .zero
    }
    guard let viewScale = window?.screen.scale else {
      invokeOnError(.unknown(message: "View has no parent Window!"))
      return .zero
    }

    let frameSize = rotateFrameSize(frameSize: videoDeviceInput.device.activeFormat.videoDimensions,
                                    orientation: outputOrientation)
    let viewSize = CGSize(width: previewView.bounds.width * viewScale,
                          height: previewView.bounds.height * viewScale)
    let scale = min(frameSize.width / viewSize.width, frameSize.height / viewSize.height)
    let scaledViewSize = CGSize(width: viewSize.width * scale, height: viewSize.height * scale)

    let overlapX = scaledViewSize.width - frameSize.width
    let overlapY = scaledViewSize.height - frameSize.height

    let scaledPoint = CGPoint(x: point.x * scale, y: point.y * scale)

    return CGPoint(x: scaledPoint.x - (overlapX / 2), y: scaledPoint.y - (overlapY / 2))
  }

  /// Converts a Point in the UI View Layer to a Point in the Camera Device Sensor coordinate system (x: [0..1], y: [0..1])
  func captureDevicePointConverted(fromLayerPoint pointInLayer: CGPoint) -> CGPoint {
    guard let videoDeviceInput = videoDeviceInput else {
      invokeOnError(.session(.cameraNotReady))
      return .zero
    }
    let frameSize = rotateFrameSize(frameSize: videoDeviceInput.device.activeFormat.videoDimensions,
                                    orientation: outputOrientation)
    let pointInFrame = convertLayerPointToFramePoint(layerPoint: pointInLayer)
    return CGPoint(x: pointInFrame.x / frameSize.width, y: pointInFrame.y / frameSize.height)
  }

  func focus(point: CGPoint, promise: Promise) {
    withPromise(promise) {
      guard let device = self.videoDeviceInput?.device else {
        throw CameraError.session(SessionError.cameraNotReady)
      }
      if !device.isFocusPointOfInterestSupported {
        throw CameraError.device(DeviceError.focusNotSupported)
      }

      // in {0..1} system
      var normalizedPoint = captureDevicePointConverted(fromLayerPoint: point)
      if let previewView = previewView as? PreviewView {
        // previewView is of type PreviewView can use the built in captureDevicePointConverted
        normalizedPoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
      }

      do {
        try device.lockForConfiguration()

        device.focusPointOfInterest = normalizedPoint
        device.focusMode = .autoFocus

        if device.isExposurePointOfInterestSupported {
          device.exposurePointOfInterest = normalizedPoint
          device.exposureMode = .autoExpose
        }

        // Enable subject area change monitoring
        device.isSubjectAreaChangeMonitoringEnabled = true

        // Remove any existing observer for subject area change notifications
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)

        // Register observer for subject area change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)

        device.unlockForConfiguration()
        return nil
      } catch {
        throw CameraError.device(DeviceError.configureError)
      }
    }
  }

  @objc func subjectAreaDidChange(notification: NSNotification) {
    guard let device = self.videoDeviceInput?.device else {
      invokeOnError(.session(.cameraNotReady))
      return
    }
    do {
      try device.lockForConfiguration()

      // Reset focus and exposure settings to continuous mode
      if device.isFocusPointOfInterestSupported {
        device.focusMode = .continuousAutoFocus
      }

      if device.isExposurePointOfInterestSupported {
        device.exposureMode = .continuousAutoExposure
      }
      
      device.isSubjectAreaChangeMonitoringEnabled = false

      device.unlockForConfiguration()
    } catch {
      invokeOnError(.device(.configureError))
    }
  }
}
