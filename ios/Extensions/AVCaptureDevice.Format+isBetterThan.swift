//
//  AVCaptureDevice.Format+isBetterThan.swift
//  Cuvent
//
//  Created by Marc Rousavy on 19.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation

extension AVCaptureDevice.Format {
  /** Compares the current Format to the given format and returns true if the current format has either:
   * 1. Higher still image capture dimensions
   * 2. Higher video format dimensions (iOS 13.0)
   * 3. Higher FPS
   */
  func isBetterThan(_ other: AVCaptureDevice.Format) -> Bool {
    // compare still image dimensions
    let leftDimensions = highResolutionStillImageDimensions
    let rightDimensions = other.highResolutionStillImageDimensions
    if leftDimensions.height * leftDimensions.width > rightDimensions.height * rightDimensions.width {
      return true
    }

    if #available(iOS 13.0, *) {
      // compare video dimensions
      let leftVideo = self.formatDescription.presentationDimensions()
      let rightVideo = other.formatDescription.presentationDimensions()
      if leftVideo.height * leftVideo.width > rightVideo.height * rightVideo.width {
        return true
      }
    }

    // compare max fps
    if let leftMaxFps = videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate > $1.maxFrameRate }),
       let rightMaxFps = other.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate > $1.maxFrameRate }) {
      if leftMaxFps.maxFrameRate > rightMaxFps.maxFrameRate {
        return true
      }
    }

    return false
  }
}
