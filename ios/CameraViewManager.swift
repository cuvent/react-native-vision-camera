//
//  CameraViewManager.swift
//  Cuvent
//
//  Created by Marc Rousavy on 09.11.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

@objc(CameraViewManager)
final class CameraViewManager: RCTViewManager {
  // pragma MARK: Properties

  private var runtimeManager: FrameProcessorRuntimeManager?

  override var bridge: RCTBridge! {
    didSet {
      #if DEBUG
        // Install console.log bindings
        ReactLogger.ConsoleLogFunction = JSConsoleHelper.getLogFunction(for: bridge)
      #endif

      // Install Frame Processor bindings and setup Runtime
      if enableFrameProcessors {
        CameraQueues.frameProcessorQueue.async {
          self.runtimeManager = FrameProcessorRuntimeManager(bridge: self.bridge)
          self.bridge.runOnJS {
            self.runtimeManager!.installFrameProcessorBindings()
          }
        }
      }
    }
  }

  override var methodQueue: DispatchQueue! {
    return DispatchQueue.main
  }

  override static func requiresMainQueueSetup() -> Bool {
    return true
  }

  override final func view() -> UIView! {
    return CameraView()
  }

  // pragma MARK: React Functions

  @objc
  final func startRecording(_ node: NSNumber, options: NSDictionary, onRecordCallback: @escaping RCTResponseSenderBlock) {
    let component = getCameraView(withTag: node)
    component.startRecording(options: options, callback: onRecordCallback)
  }

  @objc
  final func stopRecording(_ node: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let component = getCameraView(withTag: node)
    component.stopRecording(promise: Promise(resolver: resolve, rejecter: reject))
  }

  @objc
  final func takePhoto(_ node: NSNumber, options: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let component = getCameraView(withTag: node)
    component.takePhoto(options: options, promise: Promise(resolver: resolve, rejecter: reject))
  }

  @objc
  final func focus(_ node: NSNumber, point: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let promise = Promise(resolver: resolve, rejecter: reject)
    guard let x = point["x"] as? NSNumber, let y = point["y"] as? NSNumber else {
      promise.reject(error: .parameter(.invalid(unionName: "point", receivedValue: point.description)))
      return
    }
    let component = getCameraView(withTag: node)
    component.focus(point: CGPoint(x: x.doubleValue, y: y.doubleValue), promise: promise)
  }

  @objc
  final func getAvailableCameraDevices(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    withPromise(resolve: resolve, reject: reject) {
      let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: getAllDeviceTypes(), mediaType: .video, position: .unspecified)
      let devices = discoverySession.devices.filter {
        if #available(iOS 11.1, *) {
          // exclude the true-depth camera. The True-Depth camera has YUV and Infrared, can't take photos!
          return $0.deviceType != .builtInTrueDepthCamera
        }
        return true
      }
      return devices.map {
        return [
          "id": $0.uniqueID,
          "devices": $0.physicalDevices.map(\.deviceType.descriptor),
          "position": $0.position.descriptor,
          "name": $0.localizedName,
          "hasFlash": $0.hasFlash,
          "hasTorch": $0.hasTorch,
          "minZoom": $0.minAvailableVideoZoomFactor,
          "neutralZoom": $0.neutralZoomFactor,
          "maxZoom": $0.maxAvailableVideoZoomFactor,
          "isMultiCam": $0.isMultiCam,
          "supportsPhotoAndVideoCapture": true,
          "supportsDepthCapture": false, // TODO: supportsDepthCapture
          "supportsRawCapture": false, // TODO: supportsRawCapture
          "supportsLowLightBoost": $0.isLowLightBoostSupported,
          "supportsFocus": $0.isFocusPointOfInterestSupported,
          "formats": $0.formats.map { format -> [String: Any] in
            format.toDictionary()
          },
        ]
      }
    }
  }

  @objc
  final func getCameraPermissionStatus(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    withPromise(resolve: resolve, reject: reject) {
      let status = AVCaptureDevice.authorizationStatus(for: .video)
      return status.descriptor
    }
  }

  @objc
  final func getMicrophonePermissionStatus(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    withPromise(resolve: resolve, reject: reject) {
      let status = AVCaptureDevice.authorizationStatus(for: .audio)
      return status.descriptor
    }
  }

  @objc
  final func requestCameraPermission(_ resolve: @escaping RCTPromiseResolveBlock, reject _: @escaping RCTPromiseRejectBlock) {
    AVCaptureDevice.requestAccess(for: .video) { granted in
      let result: AVAuthorizationStatus = granted ? .authorized : .denied
      resolve(result.descriptor)
    }
  }

  @objc
  final func requestMicrophonePermission(_ resolve: @escaping RCTPromiseResolveBlock, reject _: @escaping RCTPromiseRejectBlock) {
    AVCaptureDevice.requestAccess(for: .audio) { granted in
      let result: AVAuthorizationStatus = granted ? .authorized : .denied
      resolve(result.descriptor)
    }
  }

  // MARK: Private

  private func getCameraView(withTag tag: NSNumber) -> CameraView {
    // swiftlint:disable force_cast
    return bridge.uiManager.view(forReactTag: tag) as! CameraView
  }

  private final func getAllDeviceTypes() -> [AVCaptureDevice.DeviceType] {
    var deviceTypes: [AVCaptureDevice.DeviceType] = []
    if #available(iOS 13.0, *) {
      deviceTypes.append(.builtInTripleCamera)
      deviceTypes.append(.builtInDualWideCamera)
      deviceTypes.append(.builtInUltraWideCamera)
    }
    if #available(iOS 11.1, *) {
      deviceTypes.append(.builtInTrueDepthCamera)
    }
    deviceTypes.append(.builtInDualCamera)
    deviceTypes.append(.builtInWideAngleCamera)
    deviceTypes.append(.builtInTelephotoCamera)
    return deviceTypes
  }
}
