import React from 'react'
import { findNodeHandle, StyleSheet } from 'react-native'
import type { CameraDevice } from './types/CameraDevice'
import type { CameraCaptureError } from './CameraError'
import { CameraRuntimeError, tryParseNativeCameraError, isErrorWithCause } from './CameraError'
import type { CameraProps, DrawableFrameProcessor, OnShutterEvent, ReadonlyFrameProcessor } from './types/CameraProps'
import { CameraModule } from './NativeCameraModule'
import type { PhotoFile, TakePhotoOptions } from './types/PhotoFile'
import type { Point } from './types/Point'
import type { RecordVideoOptions, VideoFile } from './types/VideoFile'
import { VisionCameraProxy } from './frame-processors/VisionCameraProxy'
import { CameraDevices } from './CameraDevices'
import type { EmitterSubscription, NativeSyntheticEvent, NativeMethods } from 'react-native'
import type { TakeSnapshotOptions } from './types/Snapshot'
import { SkiaCameraCanvas } from './skia/SkiaCameraCanvas'
import type { Frame } from './types/Frame'
import { FpsGraph, MAX_BARS } from './FpsGraph'
import type {
  AverageFpsChangedEvent,
  NativeCameraViewProps,
  OnCodeScannedEvent,
  OnErrorEvent,
  OutputOrientationChangedEvent,
} from './NativeCameraView'
import { NativeCameraView } from './NativeCameraView'

//#region Types
export type CameraPermissionStatus = 'granted' | 'not-determined' | 'denied' | 'restricted'
export type CameraPermissionRequestResult = 'granted' | 'denied'

type NativeRecordVideoOptions = Omit<RecordVideoOptions, 'onRecordingError' | 'onRecordingFinished' | 'videoBitRate'> & {
  videoBitRateOverride?: number
  videoBitRateMultiplier?: number
}
type RefType = React.Component<NativeCameraViewProps> & Readonly<NativeMethods>
interface CameraState {
  isRecordingWithFlash: boolean
  averageFpsSamples: number[]
}
//#endregion

function isSkiaFrameProcessor(frameProcessor?: ReadonlyFrameProcessor | DrawableFrameProcessor): frameProcessor is DrawableFrameProcessor {
  return frameProcessor?.type === 'drawable-skia'
}

//#region Camera Component
/**
 * ### A powerful `<Camera>` component.
 *
 * Read the [VisionCamera documentation](https://react-native-vision-camera.com/) for more information.
 *
 * The `<Camera>` component's most important properties are:
 *
 * * {@linkcode CameraProps.device | device}: Specifies the {@linkcode CameraDevice} to use. Get a {@linkcode CameraDevice} by using the {@linkcode useCameraDevice | useCameraDevice(..)} hook, or manually by using the {@linkcode CameraDevices.getAvailableCameraDevices CameraDevices.getAvailableCameraDevices()} function.
 * * {@linkcode CameraProps.isActive | isActive}: A boolean value that specifies whether the Camera should actively stream video frames or not. This can be compared to a Video component, where `isActive` specifies whether the video is paused or not. If you fully unmount the `<Camera>` component instead of using `isActive={false}`, the Camera will take a bit longer to start again.
 *
 * @example
 * ```tsx
 * function App() {
 *   const device = useCameraDevice('back')
 *
 *   if (device == null) return <NoCameraErrorView />
 *   return (
 *     <Camera
 *       style={StyleSheet.absoluteFill}
 *       device={device}
 *       isActive={true}
 *     />
 *   )
 * }
 * ```
 *
 * @component
 */
export class Camera extends React.PureComponent<CameraProps, CameraState> {
  /** @internal */
  static displayName = 'Camera'
  /** @internal */
  displayName = Camera.displayName
  private lastFrameProcessor: ((frame: Frame) => void) | undefined
  private isNativeViewMounted = false

  private readonly ref: React.RefObject<RefType>

  /** @internal */
  constructor(props: CameraProps) {
    super(props)
    this.onViewReady = this.onViewReady.bind(this)
    this.onAverageFpsChanged = this.onAverageFpsChanged.bind(this)
    this.onInitialized = this.onInitialized.bind(this)
    this.onStarted = this.onStarted.bind(this)
    this.onStopped = this.onStopped.bind(this)
    this.onShutter = this.onShutter.bind(this)
    this.onOutputOrientationChanged = this.onOutputOrientationChanged.bind(this)
    this.onError = this.onError.bind(this)
    this.onCodeScanned = this.onCodeScanned.bind(this)
    this.ref = React.createRef<RefType>()
    this.lastFrameProcessor = undefined
    this.state = {
      isRecordingWithFlash: false,
      averageFpsSamples: [],
    }
  }

  private get handle(): number {
    const nodeHandle = findNodeHandle(this.ref.current)
    if (nodeHandle == null || nodeHandle === -1) {
      throw new CameraRuntimeError(
        'system/view-not-found',
        "Could not get the Camera's native view tag! Does the Camera View exist in the native view-tree?",
      )
    }

    return nodeHandle
  }

  //#region View-specific functions (UIViewManager)
  /**
   * Take a single photo and write it's content to a temporary file.
   *
   * @throws {@linkcode CameraCaptureError} When any kind of error occured while capturing the photo.
   * Use the {@linkcode CameraCaptureError.code | code} property to get the actual error
   * @example
   * ```ts
   * const photo = await camera.current.takePhoto({
   *   flash: 'on',
   *   enableAutoRedEyeReduction: true
   * })
   * ```
   */
  public async takePhoto(options?: TakePhotoOptions): Promise<PhotoFile> {
    try {
      return await CameraModule.takePhoto(this.handle, options ?? {})
    } catch (e) {
      throw tryParseNativeCameraError(e)
    }
  }

  /**
   * Captures a snapshot of the Camera view and write it's content to a temporary file.
   *
   * - On iOS, `takeSnapshot` waits for a Frame from the video pipeline and therefore requires `video` to be enabled.
   * - On Android, `takeSnapshot` performs a GPU view screenshot from the preview view.
   *
   * @throws {@linkcode CameraCaptureError} When any kind of error occured while capturing the photo.
   * Use the {@linkcode CameraCaptureError.code | code} property to get the actual error
   * @example
   * ```ts
   * const snapshot = await camera.current.takeSnapshot({
   *   quality: 100
   * })
   * ```
   */
  public async takeSnapshot(options?: TakeSnapshotOptions): Promise<PhotoFile> {
    try {
      return await CameraModule.takeSnapshot(this.handle, options ?? {})
    } catch (e) {
      throw tryParseNativeCameraError(e)
    }
  }

  private getBitRateMultiplier(bitRate: RecordVideoOptions['videoBitRate']): number {
    if (typeof bitRate === 'number' || bitRate == null) return 1
    switch (bitRate) {
      case 'extra-low':
        return 0.6
      case 'low':
        return 0.8
      case 'normal':
        return 1
      case 'high':
        return 1.2
      case 'extra-high':
        return 1.4
    }
  }

  /**
   * Start a new video recording.
   *
   * @throws {@linkcode CameraCaptureError} When any kind of error occured while starting the video recording.
   * Use the {@linkcode CameraCaptureError.code | code} property to get the actual error
   *
   * @example
   * ```ts
   * camera.current.startRecording({
   *   onRecordingFinished: (video) => console.log(video),
   *   onRecordingError: (error) => console.error(error),
   * })
   * setTimeout(() => {
   *   camera.current.stopRecording()
   * }, 5000)
   * ```
   */
  public startRecording(options: RecordVideoOptions): void {
    const { onRecordingError, onRecordingFinished, videoBitRate, ...passThruOptions } = options
    if (typeof onRecordingError !== 'function' || typeof onRecordingFinished !== 'function')
      throw new CameraRuntimeError('parameter/invalid-parameter', 'The onRecordingError or onRecordingFinished functions were not set!')

    if (options.flash === 'on') {
      // Enable torch for video recording
      this.setState({
        isRecordingWithFlash: true,
      })
    }

    const nativeOptions: NativeRecordVideoOptions = passThruOptions
    if (typeof videoBitRate === 'number') {
      // If the user passed an absolute number as a bit-rate, we just use this as a full override.
      nativeOptions.videoBitRateOverride = videoBitRate
    } else if (typeof videoBitRate === 'string' && videoBitRate !== 'normal') {
      // If the user passed 'low'/'normal'/'high', we need to apply this as a multiplier to the native bitrate instead of absolutely setting it
      nativeOptions.videoBitRateMultiplier = this.getBitRateMultiplier(videoBitRate)
    }

    const onRecordCallback = (video?: VideoFile, error?: CameraCaptureError): void => {
      if (this.state.isRecordingWithFlash) {
        // disable torch again if it was enabled
        this.setState({
          isRecordingWithFlash: false,
        })
      }

      if (error != null) return onRecordingError(error)
      if (video != null) return onRecordingFinished(video)
    }
    try {
      // TODO: Use TurboModules to make this awaitable.
      CameraModule.startRecording(this.handle, nativeOptions, onRecordCallback)
    } catch (e) {
      throw tryParseNativeCameraError(e)
    }
  }

  /**
   * Pauses the current video recording.
   *
   * @throws {@linkcode CameraCaptureError} When any kind of error occured while pausing the video recording.
   * Use the {@linkcode CameraCaptureError.code | code} property to get the actual error
   *
   * @example
   * ```ts
   * // Start
   * await camera.current.startRecording({
   *   onRecordingFinished: (video) => console.log(video),
   *   onRecordingError: (error) => console.error(error),
   * })
   * await timeout(1000)
   * // Pause
   * await camera.current.pauseRecording()
   * await timeout(500)
   * // Resume
   * await camera.current.resumeRecording()
   * await timeout(2000)
   * // Stop
   * await camera.current.stopRecording()
   * ```
   */
  public async pauseRecording(): Promise<void> {
    try {
      return await CameraModule.pauseRecording(this.handle)
    } catch (e) {
      throw tryParseNativeCameraError(e)
    }
  }

  /**
   * Resumes a currently paused video recording.
   *
   * @throws {@linkcode CameraCaptureError} When any kind of error occured while resuming the video recording.
   * Use the {@linkcode CameraCaptureError.code | code} property to get the actual error
   *
   * @example
   * ```ts
   * // Start
   * await camera.current.startRecording({
   *   onRecordingFinished: (video) => console.log(video),
   *   onRecordingError: (error) => console.error(error),
   * })
   * await timeout(1000)
   * // Pause
   * await camera.current.pauseRecording()
   * await timeout(500)
   * // Resume
   * await camera.current.resumeRecording()
   * await timeout(2000)
   * // Stop
   * await camera.current.stopRecording()
   * ```
   */
  public async resumeRecording(): Promise<void> {
    try {
      return await CameraModule.resumeRecording(this.handle)
    } catch (e) {
      throw tryParseNativeCameraError(e)
    }
  }

  /**
   * Stop the current video recording.
   *
   * @throws {@linkcode CameraCaptureError} When any kind of error occured while stopping the video recording.
   * Use the {@linkcode CameraCaptureError.code | code} property to get the actual error
   *
   * @example
   * ```ts
   * await camera.current.startRecording({
   *   onRecordingFinished: (video) => console.log(video),
   *   onRecordingError: (error) => console.error(error),
   * })
   * setTimeout(async () => {
   *   await camera.current.stopRecording()
   * }, 5000)
   * ```
   */
  public async stopRecording(): Promise<void> {
    try {
      return await CameraModule.stopRecording(this.handle)
    } catch (e) {
      throw tryParseNativeCameraError(e)
    }
  }

  /**
   * Cancel the current video recording. The temporary video file will be deleted,
   * and the `startRecording`'s `onRecordingError` callback will be invoked with a `capture/recording-canceled` error.
   *
   * @throws {@linkcode CameraCaptureError} When any kind of error occured while canceling the video recording.
   * Use the {@linkcode CameraCaptureError.code | code} property to get the actual error
   *
   * @example
   * ```ts
   * await camera.current.startRecording({
   *   onRecordingFinished: (video) => console.log(video),
   *   onRecordingError: (error) => {
   *     if (error.code === 'capture/recording-canceled') {
   *       // recording was canceled.
   *     } else {
   *       console.error(error)
   *     }
   *   },
   * })
   * setTimeout(async () => {
   *   await camera.current.cancelRecording()
   * }, 5000)
   * ```
   */
  public async cancelRecording(): Promise<void> {
    try {
      return await CameraModule.cancelRecording(this.handle)
    } catch (e) {
      throw tryParseNativeCameraError(e)
    }
  }

  /**
   * Focus the camera to a specific point in the coordinate system.
   * @param {Point} point The point to focus to. This should be relative
   * to the Camera view's coordinate system and is expressed in points.
   *  * `(0, 0)` means **top left**.
   *  * `(CameraView.width, CameraView.height)` means **bottom right**.
   *
   * Make sure the value doesn't exceed the CameraView's dimensions.
   *
   * @throws {@linkcode CameraRuntimeError} When any kind of error occured while focussing.
   * Use the {@linkcode CameraRuntimeError.code | code} property to get the actual error
   * @example
   * ```ts
   * await camera.current.focus({
   *   x: tapEvent.x,
   *   y: tapEvent.y
   * })
   * ```
   */
  public async focus(point: Point): Promise<void> {
    try {
      return await CameraModule.focus(this.handle, point)
    } catch (e) {
      throw tryParseNativeCameraError(e)
    }
  }

  /**
   * Focus the camera to a specific distance.
   * @param {number} distance The distance to focus to. It should be lower than the minFocusDistance. Lower the value (closer to 0.001f), further the distance, higher the value (closer to the minFocusDistance), more macro the focus will be.
   *
   * Make sure the value doesn't exceed the device.minFocusDistance.
   *
   * @throws {@linkcode CameraRuntimeError} When any kind of error occured while focussing.
   * Use the {@linkcode CameraRuntimeError.code | code} property to get the actual error
   * @example
   * ```ts
   * await camera.current.focusDepth(5)
   * ```
   */
  public async focusDepth(distance: number): Promise<void> {
    try {
      return await CameraModule.focusDepth(this.handle, distance)
    } catch (e) {
      throw tryParseNativeCameraError(e)
    }
  }
  //#endregion

  //#region Static Functions (NativeModule)
  /**
   * Get a list of all available camera devices on the current phone.
   *
   * If you use Hooks, use the `useCameraDevices(..)` hook instead.
   *
   * * For Camera Devices attached to the phone, it is safe to assume that this will never change.
   * * For external Camera Devices (USB cameras, Mac continuity cameras, etc.) the available Camera Devices
   * could change over time when the external Camera device gets plugged in or plugged out, so
   * use {@link addCameraDevicesChangedListener | addCameraDevicesChangedListener(...)} to listen for such changes.
   *
   * @example
   * ```ts
   * const devices = Camera.getAvailableCameraDevices()
   * const backCameras = devices.filter((d) => d.position === "back")
   * const frontCameras = devices.filter((d) => d.position === "front")
   * ```
   */
  public static getAvailableCameraDevices(): CameraDevice[] {
    return CameraDevices.getAvailableCameraDevices()
  }
  /**
   * Adds a listener that gets called everytime the Camera Devices change, for example
   * when an external Camera Device (USB or continuity Camera) gets plugged in or plugged out.
   *
   * If you use Hooks, use the `useCameraDevices()` hook instead.
   */
  public static addCameraDevicesChangedListener(listener: (newDevices: CameraDevice[]) => void): EmitterSubscription {
    return CameraDevices.addCameraDevicesChangedListener(listener)
  }
  /**
   * Gets the current Camera Permission Status. Check this before mounting the Camera to ensure
   * the user has permitted the app to use the camera.
   *
   * To actually prompt the user for camera permission, use {@linkcode Camera.requestCameraPermission | requestCameraPermission()}.
   */
  public static getCameraPermissionStatus(): CameraPermissionStatus {
    return CameraModule.getCameraPermissionStatus()
  }
  /**
   * Gets the current Microphone-Recording Permission Status.
   * Check this before enabling the `audio={...}` property to make sure the
   * user has permitted the app to use the microphone.
   *
   * To actually prompt the user for microphone permission, use {@linkcode Camera.requestMicrophonePermission | requestMicrophonePermission()}.
   */
  public static getMicrophonePermissionStatus(): CameraPermissionStatus {
    return CameraModule.getMicrophonePermissionStatus()
  }
  /**
   * Gets the current Location Permission Status.
   * Check this before enabling the `location={...}` property to make sure the
   * the user has permitted the app to use the location.
   *
   * To actually prompt the user for location permission, use {@linkcode Camera.requestLocationPermission | requestLocationPermission()}.
   *
   * Note: This method will throw a `system/location-not-enabled` error if the Location APIs are not enabled at build-time.
   * See [the "GPS Location Tags" documentation](https://react-native-vision-camera.com/docs/guides/location) for more information.
   */
  public static getLocationPermissionStatus(): CameraPermissionStatus {
    return CameraModule.getLocationPermissionStatus()
  }
  /**
   * Shows a "request permission" alert to the user, and resolves with the new camera permission status.
   *
   * If the user has previously blocked the app from using the camera, the alert will not be shown
   * and `"denied"` will be returned.
   *
   * @throws {@linkcode CameraRuntimeError} When any kind of error occured while requesting permission.
   * Use the {@linkcode CameraRuntimeError.code | code} property to get the actual error
   */
  public static async requestCameraPermission(): Promise<CameraPermissionRequestResult> {
    try {
      return await CameraModule.requestCameraPermission()
    } catch (e) {
      throw tryParseNativeCameraError(e)
    }
  }
  /**
   * Shows a "request permission" alert to the user, and resolves with the new microphone permission status.
   *
   * If the user has previously blocked the app from using the microphone, the alert will not be shown
   * and `"denied"` will be returned.
   *
   * @throws {@linkcode CameraRuntimeError} When any kind of error occured while requesting permission.
   * Use the {@linkcode CameraRuntimeError.code | code} property to get the actual error
   */
  public static async requestMicrophonePermission(): Promise<CameraPermissionRequestResult> {
    try {
      return await CameraModule.requestMicrophonePermission()
    } catch (e) {
      throw tryParseNativeCameraError(e)
    }
  }
  /**
   * Shows a "request permission" alert to the user, and resolves with the new location permission status.
   *
   * If the user has previously blocked the app from using the location, the alert will not be shown
   * and `"denied"` will be returned.
   *
   * @throws {@linkcode CameraRuntimeError} When any kind of error occured while requesting permission.
   * Use the {@linkcode CameraRuntimeError.code | code} property to get the actual error
   */
  public static async requestLocationPermission(): Promise<CameraPermissionRequestResult> {
    try {
      return await CameraModule.requestLocationPermission()
    } catch (e) {
      throw tryParseNativeCameraError(e)
    }
  }
  //#endregion

  //#region Events (Wrapped to maintain reference equality)
  private onError(event: NativeSyntheticEvent<OnErrorEvent>): void {
    const error = event.nativeEvent
    const cause = isErrorWithCause(error.cause) ? error.cause : undefined
    // @ts-expect-error We're casting from unknown bridge types to TS unions, I expect it to hopefully work
    const cameraError = new CameraRuntimeError(error.code, error.message, cause)

    if (this.props.onError != null) {
      this.props.onError(cameraError)
    } else {
      // User didn't pass an `onError` handler, so just log it to console
      console.error(cameraError)
    }
  }

  private onInitialized(): void {
    this.props.onInitialized?.()
  }

  private onStarted(): void {
    this.props.onStarted?.()
  }

  private onStopped(): void {
    this.props.onStopped?.()
  }

  private onShutter(event: NativeSyntheticEvent<OnShutterEvent>): void {
    this.props.onShutter?.(event.nativeEvent)
  }

  private onOutputOrientationChanged(event: NativeSyntheticEvent<OutputOrientationChangedEvent>): void {
    this.props.onOutputOrientationChanged?.(event.nativeEvent.outputOrientation)
  }
  //#endregion

  private onCodeScanned(event: NativeSyntheticEvent<OnCodeScannedEvent>): void {
    const codeScanner = this.props.codeScanner
    if (codeScanner == null) return

    codeScanner.onCodeScanned(event.nativeEvent.codes, event.nativeEvent.frame)
  }

  //#region Lifecycle
  private setFrameProcessor(frameProcessor: (frame: Frame) => void): void {
    VisionCameraProxy.setFrameProcessor(this.handle, frameProcessor)
  }

  private unsetFrameProcessor(): void {
    VisionCameraProxy.removeFrameProcessor(this.handle)
  }

  private onViewReady(): void {
    this.isNativeViewMounted = true
    if (this.props.frameProcessor != null) {
      // user passed a `frameProcessor` but we didn't set it yet because the native view was not mounted yet. set it now.
      this.setFrameProcessor(this.props.frameProcessor.frameProcessor)
      this.lastFrameProcessor = this.props.frameProcessor.frameProcessor
    }
  }

  private onAverageFpsChanged({ nativeEvent: { averageFps } }: NativeSyntheticEvent<AverageFpsChangedEvent>): void {
    this.setState((state) => {
      const averageFpsSamples = [...state.averageFpsSamples, averageFps]
      while (averageFpsSamples.length >= MAX_BARS + 1) {
        // we keep a maximum of 30 FPS samples in our history
        averageFpsSamples.shift()
      }

      return {
        ...state,
        averageFpsSamples: averageFpsSamples,
      }
    })
  }

  /** @internal */
  componentDidUpdate(): void {
    if (!this.isNativeViewMounted) return
    const frameProcessor = this.props.frameProcessor
    if (frameProcessor?.frameProcessor !== this.lastFrameProcessor) {
      // frameProcessor argument identity changed. Update native to reflect the change.
      if (frameProcessor != null) this.setFrameProcessor(frameProcessor.frameProcessor)
      else this.unsetFrameProcessor()

      this.lastFrameProcessor = frameProcessor?.frameProcessor
    }
  }
  //#endregion

  /** @internal */
  public render(): React.ReactNode {
    // We remove the big `device` object from the props because we only need to pass `cameraId` to native.
    const { device, frameProcessor, codeScanner, enableFpsGraph, ...props } = this.props

    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
    if (device == null) {
      throw new CameraRuntimeError(
        'device/no-device',
        'Camera: `device` is null! Select a valid Camera device. See: https://mrousavy.com/react-native-vision-camera/docs/guides/devices',
      )
    }

    const shouldEnableBufferCompression = props.video === true && frameProcessor == null
    const torch = this.state.isRecordingWithFlash ? 'on' : props.torch
    const isRenderingWithSkia = isSkiaFrameProcessor(frameProcessor)

    return (
      <NativeCameraView
        {...props}
        cameraId={device.id}
        ref={this.ref}
        torch={torch}
        onViewReady={this.onViewReady}
        onAverageFpsChanged={enableFpsGraph ? this.onAverageFpsChanged : undefined}
        onInitialized={this.onInitialized}
        onCodeScanned={this.onCodeScanned}
        onStarted={this.onStarted}
        onStopped={this.onStopped}
        onShutter={this.onShutter}
        onOutputOrientationChanged={this.onOutputOrientationChanged}
        onError={this.onError}
        codeScannerOptions={codeScanner}
        enableFrameProcessor={frameProcessor != null}
        enableBufferCompression={props.enableBufferCompression ?? shouldEnableBufferCompression}
        preview={isRenderingWithSkia ? false : props.preview ?? true}>
        {isRenderingWithSkia && (
          <SkiaCameraCanvas
            style={styles.customPreviewView}
            offscreenTextures={frameProcessor.offscreenTextures}
            resizeMode={props.resizeMode}
          />
        )}
        {enableFpsGraph && (
          <FpsGraph style={styles.fpsGraph} averageFpsSamples={this.state.averageFpsSamples} targetMaxFps={props.format?.maxFps ?? 60} />
        )}
      </NativeCameraView>
    )
  }
}
//#endregion

const styles = StyleSheet.create({
  customPreviewView: {
    flex: 1,
  },
  fpsGraph: {
    elevation: 1,
    position: 'absolute',
    left: 15,
    top: 30,
  },
})
