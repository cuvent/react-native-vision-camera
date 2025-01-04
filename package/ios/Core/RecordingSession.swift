//
//  RecordingSession.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 01.05.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

import AVFoundation
import CoreLocation
import Foundation

// MARK: - RecordingSession

/**
 A [RecordingSession] class that can record video and audio [CMSampleBuffers] from [AVCaptureVideoDataOutput] and
 [AVCaptureAudioDataOutput] into a .mov/.mp4 file using [AVAssetWriter].

 It also synchronizes buffers to the CMTime by the CaptureSession so that late frames are removed from the beginning and added
 towards the end (useful e.g. for videoStabilization).
 */
final class RecordingSession {
  private let clock: CMClock
  private let assetWriter: AVAssetWriter
  private var videoTrack: Track?
  private var audioTrack: Track?
  private let completionHandler: (RecordingSession, AVAssetWriter.Status, Error?) -> Void
  private var isFinishing = false

  private let lock = DispatchSemaphore(value: 1)
  private var shouldStartSession = false
  private var shouldResumeSession = false

  /**
   Gets the file URL of the recorded video.
   */
  var url: URL {
    return assetWriter.outputURL
  }

  /**
   Gets the size of the recorded video, in pixels.
   */
  var size: CGSize {
    return videoTrack?.size ?? CGSize.zero
  }

  /**
   Get the duration (in seconds) of the recorded video.
   */
  var duration: Double {
    return videoTrack?.duration.seconds ?? 0.0
  }

  /**
   Returns whether all tracks are marked as finished, or not.
   */
  var isFinished: Bool {
    let isVideoTrackFinished = videoTrack?.isFinished ?? true
    let isAudioTrackFinished = audioTrack?.isFinished ?? true
    return isVideoTrackFinished && isAudioTrackFinished
  }

  /**
   Get the presentation orientation of the video.
   */
  let videoOrientation: Orientation

  init(url: URL,
       fileType: AVFileType,
       metadataProvider: MetadataProvider,
       clock: CMClock,
       orientation: Orientation,
       completion: @escaping (RecordingSession, AVAssetWriter.Status, Error?) -> Void) throws {
    completionHandler = completion
    self.clock = clock
    videoOrientation = orientation
    VisionLogger.log(level: .info, message: "Creating RecordingSession... (orientation: \(orientation))")

    do {
      assetWriter = try AVAssetWriter(outputURL: url, fileType: fileType)
      assetWriter.shouldOptimizeForNetworkUse = false
    } catch let error as NSError {
      throw CameraError.capture(.createRecorderError(message: error.description))
    }

    // Assign the metadata item to the asset writer
    let metadataItems = metadataProvider.createVideoMetadata()
    assetWriter.metadata.append(contentsOf: metadataItems)
  }

  deinit {
    if assetWriter.status == .writing {
      VisionLogger.log(level: .info, message: "Cancelling AssetWriter...")
      assetWriter.cancelWriting()
    }
  }

  /**
   Initializes the video track.
   */
  func initializeVideoTrack(withSettings settings: [String: Any]) throws {
    guard !settings.isEmpty else {
      throw CameraError.capture(.createRecorderError(message: "Tried to initialize Video Track with empty options!"))
    }
    guard videoTrack == nil else {
      throw CameraError.capture(.createRecorderError(message: "Tried to initialize Video Track twice!"))
    }
    guard assetWriter.canApply(outputSettings: settings, forMediaType: .video) else {
      throw CameraError.capture(.createRecorderError(message: "The given output settings are not supported!"))
    }

    VisionLogger.log(level: .info, message: "Initializing Video AssetWriter with settings: \(settings.description)")
    let videoWriter = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    videoWriter.expectsMediaDataInRealTime = true
    videoWriter.transform = videoOrientation.affineTransform
    assetWriter.add(videoWriter)
    videoTrack = Track(ofType: .video, withAssetWriterInput: videoWriter, andClock: clock)
    VisionLogger.log(level: .info, message: "Initialized Video AssetWriter.")
  }

  /**
   Initializes the audio track.
   */
  func initializeAudioTrack(withSettings settings: [String: Any]?, format: CMFormatDescription) throws {
    guard audioTrack == nil else {
      throw CameraError.capture(.createRecorderError(message: "Tried to initialize Audio Track twice!"))
    }

    if let settings = settings {
      VisionLogger.log(level: .info, message: "Initializing Audio AssetWriter with settings: \(settings.description)")
    } else {
      VisionLogger.log(level: .info, message: "Initializing Audio AssetWriter default settings...")
    }
    let audioWriter = AVAssetWriterInput(mediaType: .audio, outputSettings: settings, sourceFormatHint: format)
    audioWriter.expectsMediaDataInRealTime = true
    assetWriter.add(audioWriter)
    audioTrack = Track(ofType: .audio, withAssetWriterInput: audioWriter, andClock: clock)
    VisionLogger.log(level: .info, message: "Initialized Audio AssetWriter.")
  }

  /**
   Start the RecordingSession using the current time of the provided synchronization clock.
   All buffers passed to [append] must be synchronized to this Clock.
   */
  func start() throws {
    lock.wait()
    defer {
      lock.signal()
    }

    VisionLogger.log(level: .info, message: "Starting Asset Writer...")

    // Prepare the AssetWriter for writing to the video file
    let success = assetWriter.startWriting()
    guard success else {
      throw CameraError.capture(.createRecorderError(message: "Failed to start Asset Writer!"))
    }
    VisionLogger.log(level: .info, message: "Asset Writer started!")
      
    shouldStartSession = true
    shouldResumeSession = false
  }

  /**
   Requests the RecordingSession to stop writing frames at the current time of the provided synchronization clock.
   The RecordingSession will continue to write video frames and audio frames that have been produced (but not yet consumed)
   before the requested timestamp.
   This may happen if the Camera pipeline has an additional processing overhead, e.g. when video stabilization is enabled.
   Once all late frames have been captured (or an artificial abort timeout has been triggered), the [completionHandler] will be called.
   */
  func stop() {
    lock.wait()
    defer {
      lock.signal()
    }

    VisionLogger.log(level: .info, message: "Stopping Asset Writer with status \"\(assetWriter.status.descriptor)\"...")

    // Stop both tracks
    videoTrack?.stop()
    audioTrack?.stop()

    // Start a timeout that will force-stop the session if it still hasn't been stopped (maybe no more frames came in?)
    let latency = max(videoTrack?.latency.seconds ?? 0.0, audioTrack?.latency.seconds ?? 0.0)
    let timeout = max(latency * 2, 0.1)
    CameraQueues.cameraQueue.asyncAfter(deadline: .now() + timeout) {
      if !self.isFinishing {
        VisionLogger.log(level: .error, message: "Waited \(timeout) seconds but session is still not finished - force-stopping session...")
        self.finish()
      }
    }
  }

  /**
   Requests the RecordingSession to temporarily pause writing frames at the current time of the provided synchronization clock.
   The RecordingSession will continue to write video frames and audio frames that have been produced (but not yet consumed)
   before the requested timestamp.
   This may happen if the Camera pipeline has an additional processing overhead, e.g. when video stabilization is enabled.
   */
  func pause() {
    lock.wait()
    defer {
      lock.signal()
    }

    // Stop both tracks
    videoTrack?.pause()
    audioTrack?.pause()
  }

  /**
   Resumes the RecordingSession and starts writing frames starting with the time of the provided synchronization clock.
   */
  func resume() {
    lock.wait()
    defer {
      lock.signal()
    }

    shouldResumeSession = true
  }

  func append(buffer: CMSampleBuffer, ofType type: TrackType) throws {
    guard !isFinishing else {
      // Session is already finishing, can't write anything more
      return
    }
    guard assetWriter.status == .writing else {
      throw CameraError.capture(.unknown(message: "Frame arrived, but AssetWriter status is \(assetWriter.status.descriptor)!"))
    }
      
    if shouldStartSession || shouldResumeSession {
      if type == .audio {
        // Ignore early audio buffer
        return
      }
      if shouldStartSession {
        // Start the writer sessions with the first video buffer
        startSession(at: CMSampleBufferGetPresentationTimeStamp(buffer))
      } else {
        // Resume the writer session with the first video buffer
        resumeSession()
      }
    }
      
    // Write buffer to video/audio track
    let track = try getTrack(ofType: type)
    try track.append(buffer: buffer)

    // If we failed to write the frames, stop the Recording
    if assetWriter.status == .failed {
      let error = assetWriter.error?.localizedDescription ?? "(unknown error)"
      VisionLogger.log(level: .error, message: "AssetWriter failed to write buffer! Error: \(error)")
      finish()
      return
    }

    // When all tracks (video + audio) are finished, finish the Recording.
    if isFinished {
      finish()
    }
  }

  @inline(__always)
  private func getTrack(ofType type: TrackType) throws -> Track {
    switch type {
    case .audio:
      guard let audioTrack else {
        throw CameraError.capture(.unknown(message: "Tried to write an audio buffer, but no audio track was initialized!"))
      }
      return audioTrack
    case .video:
      guard let videoTrack else {
        throw CameraError.capture(.unknown(message: "Tried to write a video buffer, but no video track was initialized!"))
      }
      return videoTrack
    }
  }
    

  /**
   Starts the asset writer session at the specified time.
   */
  private func startSession(at time: CMTime) {
    // Start the session - any timestamp before this point will be cut off.
    assetWriter.startSession(atSourceTime: time)
    VisionLogger.log(level: .info, message: "Asset Writer session started at \(time.seconds).")

    // Start both tracks
    videoTrack?.start()
    audioTrack?.start()
      
    shouldStartSession = false
    shouldResumeSession = false
  }
    
  /**
   Resumes the asset writer session.
   */
  func resumeSession() {
    // Resume both tracks
    videoTrack?.resume()
    audioTrack?.resume()
    shouldResumeSession = false
  }

  /**
   Stops the AssetWriters and calls the completion callback.
   */
  private func finish() {
    lock.wait()
    defer {
      shouldStartSession = false
      shouldResumeSession = false
      lock.signal()
    }

    VisionLogger.log(level: .info, message: "Stopping AssetWriter with status \"\(assetWriter.status.descriptor)\"...")

    guard let videoTrack,
          let lastVideoTimestamp = videoTrack.lastTimestamp else {
      VisionLogger.log(level: .error, message: "Failed to finish() - No video track was ever initialized/started!")
      completionHandler(self, assetWriter.status, assetWriter.error)
      assetWriter.cancelWriting()
      return
    }
    guard assetWriter.status == .writing else {
      // The asset writer has an error - cancel everything.
      VisionLogger.log(level: .error, message: "Failed to finish() - AssetWriter status was \(assetWriter.status.descriptor)!")
      completionHandler(self, assetWriter.status, assetWriter.error)
      assetWriter.cancelWriting()
      return
    }

    guard !isFinishing else {
      // We're already finishing - there was a second call to this method.
      VisionLogger.log(level: .warning, message: "Tried calling finish() twice!")
      return
    }

    isFinishing = true

    // End the session at the last video frame's timestamp.
    // If there are audio frames after this timestamp, they will be cut off.
    assetWriter.endSession(atSourceTime: lastVideoTimestamp)
    VisionLogger.log(level: .info, message: "Asset Writer session stopped at \(lastVideoTimestamp.seconds).")
    assetWriter.finishWriting {
      VisionLogger.log(level: .info, message: "Asset Writer finished writing!")
      self.completionHandler(self, self.assetWriter.status, self.assetWriter.error)
    }
  }
}
