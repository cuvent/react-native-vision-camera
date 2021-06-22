<h1 align="center">Vision Camera</h1>

<div align="center">
  <img src="docs/static/img/11.png" width="50%">
  <br />
  <br />
  <blockquote><b>📸 The Camera library that sees the vision.</b></blockquote>
  <pre align="center">npm i <a href="https://www.npmjs.com/package/react-native-vision-camera">react-native-vision-camera</a><br/>npx pod-install                 </pre>
  <a href="https://cuvent.com">
    <img height="40" src="docs/static/img/cuvent-logo-text.svg" />
  </a>
  <br/>
  <span>
    <a align="center" href="https://github.com/mrousavy?tab=followers">
      <img src="https://img.shields.io/github/followers/mrousavy?label=Follow%20%40mrousavy&style=social" />
    </a>
  </span>
  <br />
  <span>
    <a align="center" href="https://twitter.com/mrousavy">
      <img src="https://img.shields.io/twitter/follow/mrousavy?label=Follow%20%40mrousavy&style=social" />
    </a>
  </span>
</div>

<br/>
<br/>

<div>
  <img align="right" width="35%" src="docs/static/img/example.png">
</div>

### Documentation

* [Guides](https://cuvent.github.io/react-native-vision-camera/docs/guides)
* [API](https://cuvent.github.io/react-native-vision-camera/docs/api)
* [Example](./example/)

### Features

* Photo, Video and Snapshot capture
* Customizable devices and multi-cameras (smoothly zoom out to "fish-eye" camera)
* Customizable FPS
* Frame Processors (JS worklets to run QR-Code scanning, facial recognition, AI object detection, realtime video chats, ...)
* Smooth zooming (Reanimated)
* Fast pause and resume
* HDR & Night modes

> See the [example](./example/) app

### Example


```tsx
function App() {
  const devices = useCameraDevices('wide-angle-camera')
  const device = devices.back

  if (device == null) return <LoadingView />
  return (
    <Camera
      style={StyleSheet.absoluteFill}
      device={device}
      isActive={true}
    />
  )
}
```

<br />

#### 🚀 Get started by [setting up permissions](https://cuvent.github.io/react-native-vision-camera/docs/guides/)!
