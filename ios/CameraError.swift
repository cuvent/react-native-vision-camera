//
//  CameraError.swift
//  Cuvent
//
//  Created by Marc Rousavy on 14.01.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import Foundation

// MARK: - PermissionError

enum PermissionError: String {
  case microphone = "microphone-permission-denied"
  case camera = "camera-permission-denied"

  var code: String {
    return rawValue
  }

  var message: String {
    switch self {
    case .microphone:
      return "The Microphone permission was denied! If you want to record Videos without sound, pass `audio={false}`."
    case .camera:
      return "The Camera permission was denied!"
    }
  }
}

// MARK: - ParameterError

enum ParameterError {
  case invalid(unionName: String, receivedValue: String)
  case unsupportedOS(unionName: String, receivedValue: String, supportedOnOs: String)
  case unsupportedOutput(outputDescriptor: String)
  case unsupportedInput(inputDescriptor: String)
  case invalidCombination(provided: String, missing: String)

  var code: String {
    switch self {
    case .invalid:
      return "invalid-parameter"
    case .unsupportedOS:
      return "unsupported-os"
    case .unsupportedOutput:
      return "unsupported-output"
    case .unsupportedInput:
      return "unsupported-input"
    case .invalidCombination:
      return "invalid-combination"
    }
  }

  var message: String {
    switch self {
    case let .invalid(unionName: unionName, receivedValue: receivedValue):
      return "The value \"\(receivedValue)\" could not be parsed to type \(unionName)!"
    case let .unsupportedOS(unionName: unionName, receivedValue: receivedValue, supportedOnOs: os):
      return "The value \"\(receivedValue)\" for type \(unionName) is not supported on the current iOS version! Required OS: \(os) or higher"
    case let .unsupportedOutput(outputDescriptor: output):
      return "The output \"\(output)\" is not supported!"
    case let .unsupportedInput(inputDescriptor: input):
      return "The input \"\(input)\" is not supported!"
    case let .invalidCombination(provided: provided, missing: missing):
      return "Invalid combination! If \"\(provided)\" is provided, \"\(missing)\" also has to be set!"
    }
  }
}

// MARK: - DeviceError

enum DeviceError: String {
  case configureError = "configuration-error"
  case noDevice = "no-device"
  case invalid = "invalid-device"
  case torchUnavailable = "torch-unavailable"
  case microphoneUnavailable = "microphone-unavailable"
  case lowLightBoostNotSupported = "low-light-boost-not-supported"
  case focusNotSupported = "focus-not-supported"
  case notAvailableOnSimulator = "camera-not-available-on-simulator"

  var code: String {
    return rawValue
  }

  var message: String {
    switch self {
    case .configureError:
      return "Failed to lock the device for configuration."
    case .noDevice:
      return "No device was set! Use `getAvailableCameraDevices()` to select a suitable Camera device."
    case .invalid:
      return "The given Camera device was invalid. Use `getAvailableCameraDevices()` to select a suitable Camera device."
    case .torchUnavailable:
      return "The current camera device does not have a torch."
    case .lowLightBoostNotSupported:
      return "The currently selected camera device does not support low-light boost! Make sure you select a device where `supportsLowLightBoost` is true!"
    case .focusNotSupported:
      return "The currently selected camera device does not support focussing!"
    case .microphoneUnavailable:
      return "The microphone was unavailable."
    case .notAvailableOnSimulator:
      return "The Camera is not available on the iOS Simulator!"
    }
  }
}

// MARK: - FormatError

enum FormatError {
  case invalidFps(fps: Int)
  case invalidHdr
  case invalidFormat
  case invalidColorSpace(colorSpace: String)
  case invalidPreset(preset: String)

  var code: String {
    switch self {
    case .invalidFormat:
      return "invalid-format"
    case .invalidFps:
      return "invalid-fps"
    case .invalidHdr:
      return "invalid-hdr"
    case .invalidPreset:
      return "invalid-preset"
    case .invalidColorSpace:
      return "invalid-color-space"
    }
  }

  var message: String {
    switch self {
    case .invalidFormat:
      return "The given format was invalid. Did you check if the current device supports the given format by using `getAvailableCameraDevices(...)`?"
    case let .invalidFps(fps):
      return "The given FPS were not valid for the currently selected format. Make sure you select a format which `frameRateRanges` includes \(fps) FPS!"
    case .invalidHdr:
      return "The currently selected format does not support HDR capture! Make sure you select a format which `frameRateRanges` includes `supportsPhotoHDR`!"
    case let .invalidColorSpace(colorSpace):
      return "The currently selected format does not support the colorSpace \"\(colorSpace)\"! Make sure you select a format which `colorSpaces` includes \"\(colorSpace)\"!"
    case let .invalidPreset(preset):
      return "The preset \"\(preset)\" is not available for the current camera device."
    }
  }
}

// MARK: - SessionError

enum SessionError {
  case cameraNotReady
  case audioSessionSetupFailed(reason: String)
  case audioSessionFailedToActivate
  case audioInUseByOtherApp

  var code: String {
    switch self {
    case .cameraNotReady:
      return "camera-not-ready"
    case .audioSessionSetupFailed:
      return "audio-session-setup-failed"
    case .audioInUseByOtherApp:
      return "audio-in-use-by-other-app"
    case .audioSessionFailedToActivate:
      return "audio-session-failed-to-activate"
    }
  }

  var message: String {
    switch self {
    case .cameraNotReady:
      return "The Camera is not ready yet! Wait for the onInitialized() callback!"
    case let .audioSessionSetupFailed(reason):
      return "The audio session failed to setup! \(reason)"
    case .audioInUseByOtherApp:
      return "The audio session is already in use by another app with higher priority!"
    case .audioSessionFailedToActivate:
      return "Failed to activate Audio Session!"
    }
  }
}

// MARK: - CaptureError

enum CaptureError {
  case invalidPhotoFormat
  case recordingInProgress
  case noRecordingInProgress
  case fileError
  case createTempFileError
  case createRecorderError(message: String? = nil)
  case invalidPhotoCodec
  case videoNotEnabled
  case photoNotEnabled
  case aborted
  case unknown(message: String? = nil)

  var code: String {
    switch self {
    case .invalidPhotoFormat:
      return "invalid-photo-format"
    case .recordingInProgress:
      return "recording-in-progress"
    case .noRecordingInProgress:
      return "no-recording-in-progress"
    case .fileError:
      return "file-io-error"
    case .createTempFileError:
      return "create-temp-file-error"
    case .createRecorderError:
      return "create-recorder-error"
    case .invalidPhotoCodec:
      return "invalid-photo-codec"
    case .videoNotEnabled:
      return "video-not-enabled"
    case .photoNotEnabled:
      return "photo-not-enabled"
    case .aborted:
      return "aborted"
    case .unknown:
      return "unknown"
    }
  }

  var message: String {
    switch self {
    case .invalidPhotoFormat:
      return "The given photo format was invalid!"
    case .invalidPhotoCodec:
      return "The given photo codec was invalid!"
    case .recordingInProgress:
      return "There is already an active video recording in progress! Did you call startRecording() twice?"
    case .noRecordingInProgress:
      return "There was no active video recording in progress! Did you call stopRecording() twice?"
    case .fileError:
      return "An unexpected File IO error occured!"
    case .createTempFileError:
      return "Failed to create a temporary file!"
    case let .createRecorderError(message: message):
      return "Failed to create the AVAssetWriter (Recorder)! \(message ?? "(no additional message)")"
    case .videoNotEnabled:
      return "Video capture is disabled! Pass `video={true}` to enable video recordings."
    case .photoNotEnabled:
      return "Photo capture is disabled! Pass `photo={true}` to enable photo capture."
    case .aborted:
      return "The capture has been stopped before any input data arrived."
    case let .unknown(message: message):
      return message ?? "An unknown error occured while capturing a video/photo."
    }
  }
}

// MARK: - SystemError

enum SystemError: String {
  case noManager = "no-camera-manager"

  var code: String {
    return rawValue
  }

  var message: String {
    switch self {
    case .noManager:
      return "No Camera Manager was found."
    }
  }
}

// MARK: - CameraError

enum CameraError: Error {
  case permission(_ id: PermissionError)
  case parameter(_ id: ParameterError)
  case device(_ id: DeviceError)
  case format(_ id: FormatError)
  case session(_ id: SessionError)
  case capture(_ id: CaptureError)
  case system(_ id: SystemError)
  case unknown(message: String? = nil)

  var code: String {
    switch self {
    case let .permission(id: id):
      return "permission/\(id.code)"
    case let .parameter(id: id):
      return "parameter/\(id.code)"
    case let .device(id: id):
      return "device/\(id.code)"
    case let .format(id: id):
      return "format/\(id.code)"
    case let .session(id: id):
      return "session/\(id.code)"
    case let .capture(id: id):
      return "capture/\(id.code)"
    case let .system(id: id):
      return "system/\(id.code)"
    case .unknown:
      return "unknown/unknown"
    }
  }

  var message: String {
    switch self {
    case let .permission(id: id):
      return id.message
    case let .parameter(id: id):
      return id.message
    case let .device(id: id):
      return id.message
    case let .format(id: id):
      return id.message
    case let .session(id: id):
      return id.message
    case let .capture(id: id):
      return id.message
    case let .system(id: id):
      return id.message
    case let .unknown(message: message):
      return message ?? "An unexpected error occured."
    }
  }
}
