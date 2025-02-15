//
//  CameraConfiguration.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 11.10.23.
//  Copyright © 2023 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

// MARK: - CameraConfiguration

final class CameraConfiguration {
  // pragma MARK: Configuration Props

  // Input
  var cameraId: String?

  // Outputs
  var photo: OutputConfiguration<Photo> = .disabled
  var video: OutputConfiguration<Video> = .disabled
  var codeScanner: OutputConfiguration<CodeScanner> = .disabled
  var isMirrored = false

  // Location
  var enableLocation = false

  // Video Stabilization
  var videoStabilizationMode: VideoStabilizationMode = .off

  // Orientation
  var outputOrientation: OutputOrientation = .device

  // Format
  var format: CameraDeviceFormat?

  // Side-Props
  var minFps: Int32?
  var maxFps: Int32?
  var enableLowLightBoost = false
  var torch: Torch = .off

  // Zoom
  var zoom: CGFloat?

  // Exposure
  var exposure: Float?

  // isActive (Start/Stop)
  var isActive = false

  var enableIdleTimer = false

  // Audio Session
  var audio: OutputConfiguration<Audio> = .disabled

  init(copyOf other: CameraConfiguration?) {
    if let other {
      // copy over all values
      cameraId = other.cameraId
      photo = other.photo
      video = other.video
      codeScanner = other.codeScanner
      isMirrored = other.isMirrored
      enableLocation = other.enableLocation
      videoStabilizationMode = other.videoStabilizationMode
      outputOrientation = other.outputOrientation
      format = other.format
      minFps = other.minFps
      maxFps = other.maxFps
      enableLowLightBoost = other.enableLowLightBoost
      torch = other.torch
      zoom = other.zoom
      exposure = other.exposure
      isActive = other.isActive
      enableIdleTimer = other.enableIdleTimer
      audio = other.audio
    } else {
      // self will just be initialized with the default values.
    }
  }

  // pragma MARK: Types

  /**
   Throw this to abort calls to configure { ... } and apply no changes.
   */
  @frozen
  enum AbortThrow: Error {
    case abort
  }

  struct Difference {
    let inputChanged: Bool
    let outputsChanged: Bool
    let videoStabilizationChanged: Bool
    let orientationChanged: Bool
    let formatChanged: Bool
    let sidePropsChanged: Bool
    let torchChanged: Bool
    let zoomChanged: Bool
    let exposureChanged: Bool

    let audioSessionChanged: Bool
    let locationChanged: Bool

    /**
     Returns `true` when props that affect the AVCaptureSession configuration (i.e. props that require beginConfiguration()) have changed.
     [`inputChanged`, `outputsChanged`, `orientationChanged`]
     */
    var isSessionConfigurationDirty: Bool {
      return inputChanged || outputsChanged || videoStabilizationChanged || orientationChanged
    }

    /**
     Returns `true` when props that affect the AVCaptureDevice configuration (i.e. props that require lockForConfiguration()) have changed.
     [`formatChanged`, `sidePropsChanged`, `zoomChanged`, `exposureChanged`]
     */
    var isDeviceConfigurationDirty: Bool {
      return isSessionConfigurationDirty || formatChanged || sidePropsChanged || zoomChanged || exposureChanged
    }

    init(between left: CameraConfiguration?, and right: CameraConfiguration) {
      // cameraId
      inputChanged = left?.cameraId != right.cameraId
      // photo, video, codeScanner
      outputsChanged = inputChanged || left?.photo != right.photo || left?.video != right.video
        || left?.codeScanner != right.codeScanner || left?.isMirrored != right.isMirrored
      // videoStabilizationMode
      videoStabilizationChanged = outputsChanged || left?.videoStabilizationMode != right.videoStabilizationMode
      // orientation
      orientationChanged = outputsChanged || left?.outputOrientation != right.outputOrientation
      // format (depends on cameraId)
      formatChanged = inputChanged || left?.format != right.format
      // side-props (depends on format)
      sidePropsChanged = formatChanged || left?.minFps != right.minFps || left?.maxFps != right.maxFps || left?.enableLowLightBoost != right.enableLowLightBoost
      // torch (depends on isActive)
      let wasInactiveAndNeedsToEnableTorchAgain = left?.isActive == false && right.isActive == true && right.torch == .on
      torchChanged = inputChanged || wasInactiveAndNeedsToEnableTorchAgain || left?.torch != right.torch
      // zoom (depends on format)
      zoomChanged = formatChanged || left?.zoom != right.zoom
      // exposure (depends on device)
      exposureChanged = inputChanged || left?.exposure != right.exposure

      // audio session
      audioSessionChanged = left?.audio != right.audio

      // location
      locationChanged = left?.enableLocation != right.enableLocation
    }
  }

  @frozen
  enum OutputConfiguration<T: Equatable>: Equatable {
    case disabled
    case enabled(config: T)

    public static func == (lhs: OutputConfiguration, rhs: OutputConfiguration) -> Bool {
      switch (lhs, rhs) {
      case (.disabled, .disabled):
        return true
      case let (.enabled(a), .enabled(b)):
        return a == b
      default:
        return false
      }
    }
  }

  /**
   A Photo Output configuration
   */
  struct Photo: Equatable {
    var qualityBalance: QualityBalance = .balanced
    var enableDepthData = false
    var enablePortraitEffectsMatte = false
  }

  /**
   A Video Output configuration
   */
  struct Video: Equatable {
    var pixelFormat: PixelFormat = .yuv
    var enableBufferCompression = false
    var enableHdr = false
    var enableFrameProcessor = false
  }

  /**
   An Audio Output configuration
   */
  struct Audio: Equatable {
    // no props for audio at the moment
  }

  /**
   A CodeScanner Output configuration
   */
  struct CodeScanner: Equatable {
    var options: CodeScannerOptions
  }
}

extension CameraConfiguration.Video {
  /**
   Returns the pixel format that should be used for the given AVCaptureVideoDataOutput.
   If HDR is enabled, this will return YUV 4:2:0 10-bit.
   If HDR is disabled, this will return whatever the user specified as a pixelFormat, or the most efficient format as a fallback.
   */
  func getPixelFormat(for videoOutput: AVCaptureVideoDataOutput) throws -> OSType {
    let available = videoOutput.availableVideoPixelFormatTypes.map { $0.toString() }
    VisionLogger.log(level: .info, message: "Available Pixel Formats: \(available), finding best match... " +
      "(pixelFormat=\"\(pixelFormat)\", enableHdr={\(enableHdr)}, enableBufferCompression={\(enableBufferCompression)})")

    // If the user enabled HDR, we can only use the YUV 4:2:0 10-bit pixel format.
    if enableHdr == true {
      guard pixelFormat == .yuv else {
        throw CameraError.format(.incompatiblePixelFormatWithHDR)
      }

      var targetFormats = [kCVPixelFormatType_420YpCbCr10BiPlanarFullRange,
                           kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange]
      if enableBufferCompression {
        // If we enable buffer compression, try to use a lossy compressed YUV format first, otherwise fall back to the others.
        targetFormats.insert(kCVPixelFormatType_Lossy_420YpCbCr10PackedBiPlanarVideoRange, at: 0)
      }

      // Find the best matching format
      guard let format = videoOutput.findPixelFormat(firstOf: targetFormats) else {
        throw CameraError.format(.invalidVideoHdr)
      }
      // YUV 4:2:0 10-bit (compressed/uncompressed)
      return format
    }

    // If we don't use HDR, we can use any other custom pixel format.
    var targetFormats: [OSType] = []
    switch pixelFormat {
    case .yuv:
      // YUV 4:2:0 8-bit (full/limited video colors; uncompressed)
      targetFormats = [kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                       kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
      if enableBufferCompression {
        // YUV 4:2:0 8-bit (full/limited video colors; compressed)
        targetFormats.insert(kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarVideoRange, at: 0)
        targetFormats.insert(kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarFullRange, at: 0)
      }
    case .rgb:
      // RGBA 8-bit (uncompressed)
      targetFormats = [kCVPixelFormatType_32BGRA]
      if enableBufferCompression {
        // RGBA 8-bit (compressed)
        targetFormats.insert(kCVPixelFormatType_Lossy_32BGRA, at: 0)
      }
    case .unknown:
      throw CameraError.parameter(.invalid(unionName: "pixelFormat", receivedValue: "unknown"))
    }

    guard let format = videoOutput.findPixelFormat(firstOf: targetFormats) else {
      throw CameraError.device(.pixelFormatNotSupported(targetFormats: targetFormats,
                                                        availableFormats: videoOutput.availableVideoPixelFormatTypes))
    }
    VisionLogger.log(level: .info, message: "Using PixelFormat: \(format.toString())...")
    return format
  }
}
