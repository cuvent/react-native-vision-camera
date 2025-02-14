//
//  CameraSessionDelegate.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 11.10.23.
//  Copyright © 2023 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

/**
 A listener for [CameraSession] events
 */
protocol CameraSessionDelegate: AnyObject {
  /**
   Called when there is a Runtime Error in the [CameraSession]
   */
  func onError(_ error: CameraError)
  /**
   Called when the [CameraSession] successfully initializes
   */
  func onSessionInitialized()
  /**
   Called when the [CameraSession] starts streaming frames. (isActive=true)
   */
  func onCameraStarted()
  /**
   Called when the [CameraSession] stopped streaming frames. (isActive=false)
   */
  func onCameraStopped()
  /**
   Called just before a photo or snapshot is captured.
   */
  func onCaptureShutter(shutterType: ShutterType)
  /**
   Called whenever the output orientation of the [CameraSession] changes.
   */
  func onOutputOrientationChanged(_ outputOrientation: Orientation)
  /**
   Called whenever the preview orientation of the [CameraSession]/[PreviewView] changes.
   */
  func onPreviewOrientationChanged(_ previewOrientation: Orientation)
  /**
   Called for every frame (if video or frameProcessor is enabled)
   */
  func onFrame(sampleBuffer: CMSampleBuffer, orientation: Orientation, isMirrored: Bool, depthData: AVDepthData?)
  /**
   Called whenever a QR/Barcode has been scanned. Only if the CodeScanner Output is enabled
   */
  func onCodeScanned(codes: [CameraSession.Code], scannerFrame: CameraSession.CodeScannerFrame)
}
