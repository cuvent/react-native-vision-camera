import type { ViewProps } from 'react-native'
import type { CameraDevice, CameraDeviceFormat, VideoStabilizationMode } from './CameraDevice'
import type { CameraRuntimeError } from '../CameraError'
import type { CodeScanner } from './CodeScanner'
import type { Frame } from './Frame'
import type { ISharedValue } from 'react-native-worklets-core'
import type { SkImage } from '@shopify/react-native-skia'
import type { OutputOrientation } from './OutputOrientation'
import type { Orientation } from './Orientation'

export interface ReadonlyFrameProcessor {
  frameProcessor: (frame: Frame) => void
  type: 'readonly'
}
export interface DrawableFrameProcessor {
  frameProcessor: (frame: Frame) => void
  type: 'drawable-skia'
  offscreenTextures: ISharedValue<SkImage[]>
  previewOrientation: ISharedValue<Orientation>
}

export interface OnShutterEvent {
  /**
   * The type of the media that was captured in this `onShutter` event.
   */
  type: 'photo' | 'snapshot'
}

// TODO: Use RCT_ENUM_PARSER for stuff like torch, videoStabilizationMode, and orientation
// TODO: Use Photo HostObject for stuff like depthData, portraitEffects, etc.
// TODO: Add RAW capture support

export interface CameraProps extends ViewProps {
  /**
   * The Camera Device to use.
   *
   * See the [Camera Devices](https://react-native-vision-camera.com/docs/guides/devices) section in the documentation for more information about Camera Devices.
   *
   * @example
   * ```tsx
   * const device = useCameraDevice('back')
   *
   * if (device == null) return <NoCameraErrorView />
   * return (
   *   <Camera
   *     device={device}
   *     isActive={true}
   *     style={StyleSheet.absoluteFill}
   *   />
   * )
   * ```
   */
  device: CameraDevice
  /**
   * Whether the Camera should actively stream video frames, or not. See the [documentation about the `isActive` prop](https://react-native-vision-camera.com/docs/guides/lifecycle#the-isactive-prop) for more information.
   *
   * This can be compared to a Video component, where `isActive` specifies whether the video is paused or not.
   *
   * @note If you fully unmount the `<Camera>` component instead of using `isActive={false}`, the Camera will take a bit longer to start again. In return, it will use less resources since the Camera will be completely destroyed when unmounted.
   */
  isActive: boolean

  //#region Use-cases
  /**
   * Enables **preview** streaming.
   *
   * Preview is enabled by default, and disabled when using a Skia Frame Processor as
   * Skia will use the video stream as it's preview.
   * @default true
   */
  preview?: boolean
  /**
   * Enables **photo capture** with the `takePhoto` function (see ["Taking Photos"](https://react-native-vision-camera.com/docs/guides/taking-photos))
   */
  photo?: boolean
  /**
   * Enables **video capture** with the `startRecording` function (see ["Recording Videos"](https://react-native-vision-camera.com/docs/guides/recording-videos))
   */
  video?: boolean
  /**
   * Enables **audio capture** for video recordings (see ["Recording Videos"](https://react-native-vision-camera.com/docs/guides/recording-videos))
   *
   * Note: Requires audio permission.
   */
  audio?: boolean
  /**
   * Specifies the pixel format of Frames streamed from a [Frame Processor](https://react-native-vision-camera.com/docs/guides/frame-processors).
   *
   * While `'yuv'` is the most efficient format, some ML models (such as TensorFlow Face Detection Models) require input Frames to be in RGB colorspace, otherwise they just output nonsense.
   *
   * The following values are supported:
   *
   * - `yuv`: The YUV (Y'CbCr 4:2:0 or NV21, 8-bit) format, either video- or full-range, depending on hardware capabilities. This is the most efficient format.
   * - `rgb`: The RGB (RGBA or BGRA, 8-bit) format. This is less efficient format and sometimes requires explicit conversion.
   *
   * @default 'yuv'
   */
  pixelFormat?: 'yuv' | 'rgb'
  /**
   * Enables location streaming to add GPS EXIF tags to captured photos and videos.
   *
   * Note: Requires location permission.
   *
   * Note: This property will throw a `system/location-not-enabled` error if the Location APIs are not enabled at build-time.
   * See [the "GPS Location Tags" documentation](https://react-native-vision-camera.com/docs/guides/location) for more information.
   */
  enableLocation?: boolean
  //#endregion

  //#region Common Props (torch, zoom)
  /**
   * Set the current torch mode.
   *
   * Make sure the given {@linkcode device} has a torch (see {@linkcode CameraDevice.hasTorch device.hasTorch}).
   *
   * @default "off"
   */
  torch?: 'off' | 'on'
  /**
   * Specifies the zoom factor of the current camera, in "factor"/scale.
   *
   * This value ranges from `minZoom` (e.g. `1`) to `maxZoom` (e.g. `128`). It is recommended to set this value
   * to the CameraDevice's `neutralZoom` per default and let the user zoom out to the fish-eye (ultra-wide) camera
   * on demand (if available)
   *
   * **Note:** Linearly increasing this value always appears logarithmic to the user.
   *
   * @default 1.0
   */
  zoom?: number
  /**
   * Enables or disables the native pinch to zoom gesture.
   *
   * If you want to implement a custom zoom gesture, see [the Zooming with Reanimated documentation](https://react-native-vision-camera.com/docs/guides/zooming).
   *
   * @default false
   */
  enableZoomGesture?: boolean
  //#endregion

  //#region Camera Controls
  /**
   * Specifies the Exposure bias of the current camera. A lower value means darker images, a higher value means brighter images.
   *
   * The Camera will still continue to auto-adjust exposure and focus, but will premultiply the exposure setting with the provided value here.
   *
   * This values ranges from {@linkcode CameraDevice.minExposure device.minExposure} to {@linkcode CameraDevice.maxExposure device.maxExposure}.
   *
   * The value between min- and max supported exposure is considered the default, neutral value.
   */
  exposure?: number
  //#endregion

  //#region Format/Preset selection
  /**
   * Selects a given format. By default, the best matching format is chosen. See {@linkcode CameraDeviceFormat}
   *
   * The format defines the possible values for properties like:
   * - {@linkcode fps}: `format.minFps`...`format.maxFps`
   * - {@linkcode videoHdr}: `format.supportsVideoHdr`
   * - {@linkcode photoHdr}: `format.supportsPhotoHdr`
   * - {@linkcode enableDepthData}: `format.supportsDepthCapture`
   * - {@linkcode videoStabilizationMode}: `format.videoStabilizationModes`
   *
   * In other words; {@linkcode enableDepthData} can only be set to true if {@linkcode CameraDeviceFormat.supportsDepthCapture format.supportsDepthCapture} is true.
   */
  format?: CameraDeviceFormat
  /**
   * Specifies the Preview's resize mode.
   * - `"cover"`: Keep aspect ratio and fill entire parent view (centered).
   * - `"contain"`: Keep aspect ratio and make sure the entire content is visible inside the parent view, even if it introduces additional blank areas (centered).
   *
   * @default "cover"
   */
  resizeMode?: 'cover' | 'contain'
  /**
   * Specifies the implementation mode for the Preview View on Android.
   * - `"surface-view"`: Uses a [`SurfaceView`](https://developer.android.com/reference/android/view/SurfaceView) for rendering.
   * This is more efficient and supports HDR rendering, but doesn't support masks, transparency, rotations or clipping.
   * - `"texture-view"`: Uses a [`TextureView`](https://developer.android.com/reference/android/view/TextureView) for rendering.
   * This is less efficient and doesn't support HDR rendering, but supports masks, transparency, rotations and clipping.
   *
   * @default 'surface-view'
   */
  androidPreviewViewType?: 'surface-view' | 'texture-view'
  /**
   * Specify a the number of frames per second this camera should stream frames at.
   *
   * - If `fps` is a single number, the Camera will be streaming at a fixed FPS value.
   * - If `fps` is a tuple/array, the Camera will be free to choose a FPS value between `minFps` and `maxFps`,
   * depending on current lighting conditions. Allowing a lower `minFps` value can result in better photos
   * and videos, as the Camera can take more time to properly receive light for frames.
   *
   * Make sure the given {@linkcode format} can stream at the target {@linkcode fps} value (see {@linkcode CameraDeviceFormat.minFps format.minFps} and {@linkcode CameraDeviceFormat.maxFps format.maxFps}).
   */
  fps?: number | [minFps: number, maxFps: number]
  /**
   * Enables or disables HDR Video Streaming for Preview, Video and Frame Processor via a 10-bit wide-color pixel format.
   *
   * Make sure the given {@linkcode format} supports HDR (see {@linkcode CameraDeviceFormat.supportsVideoHdr format.supportsVideoHdr}).
   */
  videoHdr?: boolean
  /**
   * The bit-rate for encoding the video into a file, in Mbps (Megabits per second).
   *
   * Bit-rate is dependant on various factors such as resolution, FPS, pixel format (whether it's 10 bit HDR or not), and video codec.
   *
   * By default, it will be calculated by the hardware encoder, which takes all those factors into account.
   *
   * * `extra-low`: 40% lower than whatever the hardware encoder recommends.
   * * `low`: 20% lower than whatever the hardware encoder recommends.
   * * `normal`: The recommended value by the hardware encoder.
   * * `high`: 20% higher than whatever the hardware encoder recommends.
   * * `extra-high`: 40% higher than whatever the hardware encoder recommends.
   * * `number`: Any custom number for the bit-rate, in Mbps.
   *
   * @default 'normal'
   */
  videoBitRate?: 'extra-low' | 'low' | 'normal' | 'high' | 'extra-high' | number
  /**
   * Enables or disables HDR Photo Capture via a double capture routine that combines low- and high exposure photos.
   *
   * On Android, {@linkcode photoHdr} uses a vendor-specific "HDR" extension which is not compatible with {@linkcode videoHdr},
   * so only one of video- or photo-HDR can be enabled at a time.
   *
   * Make sure the given {@linkcode format} supports HDR (see {@linkcode CameraDeviceFormat.supportsPhotoHdr format.supportsPhotoHdr}).
   */
  photoHdr?: boolean
  /**
   * Configures the photo pipeline for a specific quality balance prioritization.
   * - `'speed'`: Prioritizes fast capture speed over quality (faster edge-detection, distortion correction, AF/AE/AWB times, etc.)
   * - `'balanced'`: A balanced set of prioritization configurations
   * - `'quality'`: Prioritizes high quality capture over speed (higher accuracy edge-detection, distortion correction, AF/AE/AWB times, etc.)
   *
   * @default 'balanced'
   */
  photoQualityBalance?: 'speed' | 'balanced' | 'quality'
  /**
   * Enables or disables lossy buffer compression for the video stream.
   * If you only use {@linkcode video} or a {@linkcode frameProcessor}, this
   * can increase the efficiency and lower memory usage of the Camera.
   *
   * If buffer compression is enabled, the video pipeline will try to use a
   * lossy-compressed pixel format instead of the normal one.
   *
   * If you use a {@linkcode frameProcessor}, you might need to change how pixels
   * are read inside your native frame processor function as this is different
   * from the usual `yuv` or `rgb` layout.
   *
   * If buffer compression is not available but this property is enabled, the normal
   * pixel formats will be used and no error will be thrown.
   *
   * @platform iOS
   * @default
   * - true // if frameProcessor={undefined}
   * - false // otherwise
   */
  enableBufferCompression?: boolean
  /**
   * Enables or disables low-light boost on this camera device.
   *
   * Enabling low light boost allows the FPS rate to be throttled to up to half of what it is set to to allow for more
   * exposure in low light conditions.
   *
   * On Android, {@linkcode lowLightBoost} might even use a vendor-specific "night-mode" extension to allow for even more visibility in low-light conditions.
   *
   * Make sure the given {@linkcode device} supports low-light-boost (see {@linkcode CameraDevice.supportsLowLightBoost device.supportsLowLightBoost}).
   */
  lowLightBoost?: boolean
  /**
   * Specifies the video stabilization mode to use.
   *
   * Make sure the given {@linkcode format} supports the given {@linkcode videoStabilizationMode}.
   */
  videoStabilizationMode?: VideoStabilizationMode
  //#endregion

  /**
   * Enables or disables the idle timer, allowing the phone to go to sleep according to the system settings.
   *
   * @platform iOS
   *
   * @default false
   */
  enableIdleTimer?: boolean

  /**
   * Enables or disables depth data delivery for photo capture.
   *
   * Make sure the given {@linkcode format} supports depth data (see {@linkcode CameraDeviceFormat.supportsDepthCapture format.supportsDepthCapture}).
   *
   * @default false
   */
  enableDepthData?: boolean
  /**
   * A boolean specifying whether the photo render pipeline is prepared for portrait effects matte delivery.
   *
   * When enabling this, you must also set `enableDepthData` to `true`.
   *
   * @platform iOS 12.0+
   * @default false
   */
  enablePortraitEffectsMatteDelivery?: boolean
  /**
   * If `true`, show a debug view to display the FPS of the Video Pipeline (Frame Processor).
   * This is useful for debugging your Frame Processor's speed.
   *
   * @default false
   */
  enableFpsGraph?: boolean
  /**
   * Sets the orientation of all Camera Outputs (Photo, Snapshot and Video).
   *
   * - `'preview'`: Use the same orientation as the preview view. If the device rotation is locked, the user cannot take photos or videos in different orientations.
   * - `'device'`: Use whatever orientation the device is held in, even if the preview view is not rotated to that orientation. If the device rotation is locked, the user can still rotate his phone to take photos or videos in different orientations than the preview view.
   *
   * @note Preview orientation will not be affected by this property, as it is always dependant on screen orientation
   * @note Frame Processors will not be affected by this property, as their buffer size (respective to {@linkcode Frame.orientation}) is always the same
   * @see See [the Orientation documentation](https://react-native-vision-camera.com/docs/guides/orientation) for more information
   * @default 'device'
   */
  outputOrientation?: OutputOrientation
  /**
   * Enables or disables mirroring of outputs alongside the vertical axis.
   *
   * Mirroring only affects the photo-, video-, or snapshot-output, but not preview.
   * The Preview is always mirrored for front cameras, and not mirrored for back cameras.
   *
   * @default false (back camera), true (front camera)
   */
  isMirrored?: boolean

  //#region Events
  /**
   * Called when any kind of runtime error occured.
   */
  onError?: (error: CameraRuntimeError) => void
  /**
   * Called when the camera session was successfully initialized and is ready for capture.
   *
   * At this point, the Camera `ref` can be used and methods like `takePhoto(..)` can be called.
   *
   * This is called everytime the {@linkcode device} or one of the outputs changes.
   */
  onInitialized?: () => void
  /**
   * Called when the camera started the session. (`isActive={true}`)
   *
   * At this point, outputs can start receiving frames from the Camera, but might not have received any yet.
   */
  onStarted?: () => void
  /**
   * Called when the camera stopped the session. (`isActive={false}`)
   *
   * At this point, outputs will stop receiving frames from the Camera.
   */
  onStopped?: () => void
  /**
   * Called when the Preview View has received it's first frame and is now started.
   *
   * @note This will only be called if {@linkcode preview} is true, and no Skia Frame Processor is used
   */
  onPreviewStarted?: () => void
  /**
   * Called when the Preview View has stoppped streaming frames and is now stopped.
   *
   * @note This will only be called if {@linkcode preview} is true, and no Skia Frame Processor is used
   */
  onPreviewStopped?: () => void
  /**
   * Called just before a photo or snapshot is captured.
   *
   * Inside this callback you can play a custom shutter sound or show visual feedback to the user.
   */
  onShutter?: (event: OnShutterEvent) => void
  /**
   * Called whenever the output orientation changed.
   * This might happen even if the screen/interface rotation is locked.
   *
   * @see See ["Orientation"](https://react-native-vision-camera.com/docs/guides/orientation)
   */
  onOutputOrientationChanged?: (outputOrientation: Orientation) => void
  /**
   * Called whenever the preview orientation changed.
   * This will happen whenever the screen/interface rotates.
   *
   * @see See ["Orientation"](https://react-native-vision-camera.com/docs/guides/orientation)
   */
  onPreviewOrientationChanged?: (previewOrientation: Orientation) => void
  /**
   * Called whenever the target UI rotation/orientation changes.
   * @param uiRotation The degrees that UI elements need to be rotated by to appear up-right.
   */
  onUIRotationChanged?: (uiRotation: number) => void
  /**
   * A worklet which will be called for every frame the Camera "sees".
   *
   * @see See [the Frame Processors documentation](https://react-native-vision-camera.com/docs/guides/frame-processors) for more information
   * @example
   * ```tsx
   * const frameProcessor = useFrameProcessor((frame) => {
   *   'worklet'
   *   const faces = scanFaces(frame)
   *   console.log(`Faces: ${faces}`)
   * }, [])
   *
   * return <Camera {...cameraProps} frameProcessor={frameProcessor} />
   * ```
   */
  frameProcessor?: ReadonlyFrameProcessor | DrawableFrameProcessor
  /**
   * A CodeScanner that can detect QR-Codes or Barcodes using platform-native APIs.
   *
   * @see See [the Code Scanner documentation](https://react-native-vision-camera.com/docs/guides/code-scanning) for more information
   * @example
   * ```tsx
   * const codeScanner = useCodeScanner({
   *   codeTypes: ['qr', 'ean-13'],
   *   onCodeScanned: (codes) => {
   *     console.log(`Scanned ${codes.length} codes!`)
   *   }
   * })
   *
   * return <Camera {...props} codeScanner={codeScanner} />
   * ```
   */
  codeScanner?: CodeScanner
  //#endregion
}
