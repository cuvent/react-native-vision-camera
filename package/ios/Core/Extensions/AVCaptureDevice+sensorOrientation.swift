//
//  AVCaptureDevice+sensorOrientation.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 04.06.24.
//

import AVFoundation
import Foundation

// On iOS, all built-in Cameras are landscape-left (90deg rotated)
let DEFAULT_SENSOR_ORIENTATION = Orientation.landscapeLeft

extension AVCaptureDevice {
  /**
   Get the natural orientation of the camera sensor of this specific device.
   */
  var sensorOrientation: Orientation {
    // TODO: There is no iOS API to get native sensor orientation.
    //       - The new `RotationCoordinator` API is a blackbox, and cannot be used statically.
    //       - The current approach (dynamically creating an AVCaptureSession) is very hacky and has a runtime overhead.
    //       Hopefully iOS adds an API to get sensor orientation soon so we can use that!

    let start = DispatchTime.now()

    // 1. Create a capture session
    let session = AVCaptureSession()

    // 2. Add this device as an input
    guard let input = try? AVCaptureDeviceInput(device: self) else {
      VisionLogger.log(level: .error, message: "Cannot dynamically determine \(uniqueID)'s sensorOrientation, " +
        "falling back to \(DEFAULT_SENSOR_ORIENTATION)...")
      return DEFAULT_SENSOR_ORIENTATION
    }
    session.addInput(input)

    // 3. Add an output (e.g. video data output)
    let output = AVCaptureVideoDataOutput()
    output.automaticallyConfiguresOutputBufferDimensions = false
    output.deliversPreviewSizedOutputBuffers = true
    session.addOutput(output)

    // 4. Inspect the default orientation of the output
    let defaultOrientation = output.orientation

    let end = DispatchTime.now()
    let ms = (end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
    print("Getting orientation took \(ms)ms.")

    // 5. Rotate the default orientation by the default sensor orientation we know of
    let sensorOrientation = defaultOrientation.rotatedBy(orientation: DEFAULT_SENSOR_ORIENTATION)
    return sensorOrientation
  }
}
