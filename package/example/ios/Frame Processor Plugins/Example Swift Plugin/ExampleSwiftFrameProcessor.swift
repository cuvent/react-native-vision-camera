//
//  ExampleSwiftFrameProcessor.swift
//  VisionCameraExample
//
//  Created by Mateusz Medrek on 02/10/2023.
//

#if VISION_CAMERA_ENABLE_FRAME_PROCESSORS
import VisionCamera
import MediaPipeTasksVision

// Example for a Swift Frame Processor plugin
@objc(ExampleSwiftFrameProcessorPlugin)
public class ExampleSwiftFrameProcessorPlugin: FrameProcessorPlugin {
  private let handLandmarker: HandLandmarker
  
  public override init(proxy: VisionCameraProxyHolder, options: [AnyHashable: Any]! = [:]) {

    guard let modelPath = Bundle.main.path(forResource: "hand_landmarker",
                                           ofType: "task") else {
      fatalError("Model not found!")
    }

    let landmarkerOptions = HandLandmarkerOptions()
    landmarkerOptions.baseOptions.modelAssetPath = modelPath
    landmarkerOptions.runningMode = .video
    landmarkerOptions.minHandDetectionConfidence = 0.6
    landmarkerOptions.minHandPresenceConfidence = 0.6
    landmarkerOptions.minTrackingConfidence = 0.6
    landmarkerOptions.numHands = 2

    guard let handLandmarker = try? HandLandmarker(options: landmarkerOptions) else {
      fatalError("Failed to init Hand Landmarker!")
    }
    self.handLandmarker = handLandmarker
    super.init(proxy: proxy, options: options)
  }

  public override func callback(_ frame: Frame, withArguments arguments: [AnyHashable: Any]?) -> Any? {
    do {
      let image = try MPImage(sampleBuffer: frame.buffer)
      let results = try handLandmarker.detect(videoFrame: image, timestampInMilliseconds: Int(frame.timestamp))
      
      var hands: [[String: Any]] = []
      for i in 0..<results.handedness.count {
        hands.append([
          "landmarks": results.landmarks[i].map({ landmark in
            return [
              "x": NSNumber(value: landmark.x),
              "y": NSNumber(value: landmark.y),
              "z": NSNumber(value: landmark.z),
              "visibility": landmark.visibility
            ]
          }),
        ])
      }
      return hands
    } catch (let error) {
      print("Error: \(error.localizedDescription)")
      return []
    }
  }
}
#endif
