<div>
  <img align="right" width="35%" src="../docs/static/img/example.png">

  <h1>Vison Camera playground</h1>

  <h2>Overview</h2>

  <p align="left">
  This is a demo application featuring some of the many features of the Vision Camera:

  * Photo capture
  * Video capture
  * Flipping device (back camera <-> front camera)
  * Device filtering (ultra-wide-angle, wide-angle, telephoto, or even combined virtual multi-cameras)
  * Format filtering (targeting 60 FPS, best capture size, best matching aspect ratio, etc.)
  * Zooming using [react-native-gesture-handler](https://github.com/software-mansion/react-native-gesture-handler) and [react-native-reanimated](https://github.com/software-mansion/react-native-reanimated)
  * Smoothly switching between constituent camera devices (see [demo on my Twitter](https://twitter.com/mrousavy/status/1365267563375116292))
  * HDR mode
  * Night mode
  * Flash for photo capture
  * Flash for video capture
  * Activating/Pausing the Camera but keeping it "warm"
  </p>
</div>

## Get started

To try the playground out for yourself, run the following commands:

```sh
git clone https://github.com/cuvent/react-native-vision-camera
cd react-native-vision-camera
yarn bootstrap
```

### iOS

1. Open the `example/ios/VisionCameraExample.xcworkspace` file with Xcode
2. Change signing configuration to your developer account
3. Select your device in the devices drop-down
4. Hit run

### Android

1. Open the `example/android/` folder with Android Studio
2. Select your device in the devices drop-down
3. Hit run
