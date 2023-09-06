<a href="https://margelo.io">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="./docs/static/img/banner-dark.png" />
    <source media="(prefers-color-scheme: light)" srcset="./docs/static/img/banner-light.png" />
    <img alt="VisionCamera" src="./docs/static/img/banner-light.png" />
  </picture>
</a>
<div >
  <br />
<div align="center">

<div align="center"><strong>A powerful, high-performance React Native camera library. 📸</strong></div>
<br />
<div align="center">
<a href="https://www.react-native-vision-camera.com/">Website</a> 
<span> · </span>
<a href="https://www.react-native-vision-camera.com/docs/guides">Documentation</a> 
<span> · </span>
<a href="https://twitter.com/mrousavy">Twitter</a>
</div>

<br />

</div>



  <img align="right" width="35%" src="docs/static/img/example.png">


## Features

* 📸 Photo and Video capture
* 📱 Customizable devices and multi-cameras ("fish-eye" zoom)
* 🎞️ Customizable resolutions and aspect-ratios (4k/8k images)
* ⏱️ Customizable FPS (30..240 FPS)
* 🧩 [Frame Processors](https://react-native-vision-camera.com/docs/guides/frame-processors) (JS worklets to run QR-Code scanning, facial recognition, AI object detection, realtime video chats, ...)
* 🔍 Smooth zooming (Reanimated)
* ⏯️ Fast pause and resume
* 🌓 HDR & Night modes
* ⚡ Custom C++/GPU accelerated video pipeline (OpenGL)


## Example

```tsx

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

```

> See the [example](./example/) app


## Installation

#### With yarn

```sh
yarn add react-native-vision-camera
cd ios && pod install
```

#### With NPM

```sh
npm install react-native-vision-camera
cd ios && pod install
```

#### With Expo

```sh
expo install react-native-vision-camera
```


## Documentation

* [Guides](https://react-native-vision-camera.com/docs/guides)
* [API](https://react-native-vision-camera.com/docs/api)
* [Example](./example/)

> ### V3
>
> You're looking at the V3 version of VisionCamera, which features a full rewrite on the Android codebase and a huge refactor on the iOS codebase. If you encounter issues on V3, you can also > downgrade to V2, which is still partially supported.

## Adopting at scale

<a href="https://github.com/sponsors/mrousavy">
  <img align="right" width="160" alt="This library helped you? Consider sponsoring!" src=".github/funding-octocat.svg">
</a>

VisionCamera is provided _as is_, I work on it in my free time.

If you're integrating VisionCamera in a production app, consider [funding this project](https://github.com/sponsors/mrousavy) and <a href="mailto:me@mrousavy.com?subject=Adopting VisionCamera at scale">contact me</a> to receive premium enterprise support, help with issues, prioritize bugfixes, request features, help at integrating VisionCamera and/or Frame Processors, and more.


## Socials

* 🐦 [**Follow me on Twitter**](https://twitter.com/mrousavy) for updates
* 📝 [**Check out my blog**](https://mrousavy.com/blog) for examples and experiments
* 💬 [**Join the Margelo Community Discord**](https://discord.gg/6CSHz2qAvA) for chatting about VisionCamera
* 💖 [**Sponsor me on GitHub**](https://github.com/sponsors/mrousavy) to support my work
* 🍪 [**Buy me a Ko-Fi**](https://ko-fi.com/mrousavy) to support my work
