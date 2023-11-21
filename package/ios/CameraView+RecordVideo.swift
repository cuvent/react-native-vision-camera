//
//  CameraView+RecordVideo.swift
//  mrousavy
//
//  Created by Marc Rousavy on 16.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation

// MARK: - CameraView + AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate

extension CameraView: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
  func startRecording(options jsOptions: NSDictionary,
                      onRecordingStarted: @escaping RCTResponseSenderBlock,
                      onRecordingEnded: @escaping RCTResponseSenderBlock) {
    // Type-safety
    let callback = Callback(onRecordingEnded)
    let promise = Promise(wrapCallback: onRecordingStarted)
    
    let options: RecordVideoOptions
    do {
      options = try RecordVideoOptions(fromJSValue: jsOptions)
    } catch {
      // Some error occured while initializing VideoSettings
      if let error = error as? CameraError {
        promise.reject(error: error)
      } else {
        promise.reject(error: .capture(.unknown(message: error.localizedDescription)), cause: error as NSError)
      }
      return
    }

    // Start Recording with promise for immediate resolving, and success and error callbacks for later.
    cameraSession.startRecording(
      options: options,
      promise: promise,
      onVideoRecorded: { video in
        callback.resolve(video.toJSValue())
      },
      onError: { error in
        callback.reject(error: error)
      }
    )
  }

  func stopRecording(promise: Promise) {
    cameraSession.stopRecording(promise: promise)
  }

  func pauseRecording(promise: Promise) {
    cameraSession.pauseRecording(promise: promise)
  }

  func resumeRecording(promise: Promise) {
    cameraSession.resumeRecording(promise: promise)
  }
}
