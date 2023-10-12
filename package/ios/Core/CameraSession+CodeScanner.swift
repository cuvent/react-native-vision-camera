//
//  CameraSession+CodeScanner.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 11.10.23.
//  Copyright © 2023 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation

extension CameraSession: AVCaptureMetadataOutputObjectsDelegate {
  
  public func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {
    guard let onCodeScanned = delegate?.onCodeScanned else {
      // No delegate callback
      return
    }
    guard !metadataObjects.isEmpty else {
      // No codes detected
      return
    }
    guard let device = videoDeviceInput?.device else {
      // No cameraId set
      return
    }
    let size = device.activeFormat.videoDimensions

    // Map codes to JS values
    let codes = metadataObjects.map { object in
      var value: String?
      if let code = object as? AVMetadataMachineReadableCodeObject {
        value = code.stringValue
      }
      let x = object.bounds.origin.x * Double(size.width)
      let y = object.bounds.origin.y * Double(size.height)
      let w = object.bounds.width * Double(size.width)
      let h = object.bounds.height * Double(size.height)
      let frame = CGRect(x: x, y: y, width: w, height: h)

      return Code(type: object.type, value: value, frame: frame)
    }
    
    // Call delegate (JS) event
    onCodeScanned(codes)
  }
  
  /**
   A scanned QR/Barcode.
   */
  struct Code {
    /**
     Type of the scanned Code
     */
    let type: AVMetadataObject.ObjectType
    /**
     Decoded value of the code
     */
    let value: String?
    /**
     Location of the code on-screen, relative to the video output layer
     */
    let frame: CGRect
    
    /**
     Converts this Code to a JS Object (Dictionary)
     */
    func toJSValue() -> [String: AnyHashable] {
      return [
        "type": type.descriptor,
        "value": value,
        "frame": [
          "x": frame.origin.x,
          "y": frame.origin.y,
          "width": frame.size.width,
          "height": frame.size.height,
        ],
      ]
    }
  }
}
