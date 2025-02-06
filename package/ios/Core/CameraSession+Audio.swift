//
//  CameraSession+Audio.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 11.10.23.
//  Copyright © 2023 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

extension CameraSession {
  /**
   Configures the Audio session and activates it. If the session was active it will shortly be deactivated before configuration.

   The Audio Session will be configured to allow background music, haptics (vibrations) and system sound playback while recording.
   Background audio is allowed to play on speakers or bluetooth speakers.
   */
  final func activateAudioSession() throws {
    VisionLogger.log(level: .info, message: "Activating Audio Session...")

    do {
      let audioSession = AVAudioSession.sharedInstance()

      try audioSession.updateCategory(AVAudioSession.Category.playAndRecord,
                                      mode: .videoRecording,
                                      options: [.mixWithOthers,
                                                .allowBluetoothA2DP,
                                                .defaultToSpeaker,
                                                .allowAirPlay])

      if #available(iOS 14.5, *) {
        // prevents the audio session from being interrupted by a phone call
        try audioSession.setPrefersNoInterruptionsFromSystemAlerts(true)
      }

      if #available(iOS 13.0, *) {
        // allow system sounds (notifications, calls, music) to play while recording
        try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
      }
      
      if #available(iOS 14.0, *) {
        // sets the orientation of the phone so stereo records accordingly
        try audioSession.setPreferredInputOrientation(.portrait)
        
        if let inputs = audioSession.availableInputs,
           let mic = inputs.first(where: { $0.portType == .builtInMic }) {
          // Configure mic to use stereo audio
          if let back = mic.dataSources?.first(where: { $0.orientation == .back && $0.supportedPolarPatterns?.contains(.stereo) == true }) {
            try back.setPreferredPolarPattern(.stereo)
            try mic.setPreferredDataSource(back)
          }
          
          // Use mic for Audio Session
          try audioSession.setPreferredInput(mic)
        }
      }
      
      audioCaptureSession.startRunning()
      VisionLogger.log(level: .info, message: "Audio Session activated!")
    } catch let error as NSError {
      VisionLogger.log(level: .error, message: "Failed to activate audio session! Error \(error.code): \(error.description)")
      switch error.code {
      case 561_017_449:
        throw CameraError.session(.audioInUseByOtherApp)
      default:
        throw CameraError.session(.audioSessionFailedToActivate)
      }
    }
  }

  final func deactivateAudioSession() {
    VisionLogger.log(level: .info, message: "Deactivating Audio Session...")

    audioCaptureSession.stopRunning()
    VisionLogger.log(level: .info, message: "Audio Session deactivated!")
  }

  @objc
  func audioSessionInterrupted(notification: Notification) {
    VisionLogger.log(level: .error, message: "Audio Session Interruption Notification!")
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
      return
    }

    // TODO: Add JS-Event for Audio Session interruptions?
    switch type {
    case .began:
      // Something interrupted our Audio Session, stop recording audio.
      VisionLogger.log(level: .error, message: "The Audio Session was interrupted!")
    case .ended:
      VisionLogger.log(level: .info, message: "The Audio Session interruption has ended.")
      guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
      let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
      if options.contains(.shouldResume) {
        // Try resuming if possible
        let isRecording = recordingSession != nil
        if isRecording {
          CameraQueues.audioQueue.async {
            VisionLogger.log(level: .info, message: "Resuming interrupted Audio Session...")
            // restart audio session because interruption is over
            try? self.activateAudioSession()
          }
        }
      } else {
        VisionLogger.log(level: .error, message: "Cannot resume interrupted Audio Session!")
      }
    @unknown default:
      ()
    }
  }
}
