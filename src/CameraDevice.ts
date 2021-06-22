import type { CameraPosition } from './CameraPosition';

/**
 * Indentifiers for a physical camera (one that actually exists on the back/front of the device)
 *
 * * `"ultra-wide-angle-camera"`: A built-in camera with a shorter focal length than that of a wide-angle camera. (focal length between below 24mm)
 * * `"wide-angle-camera"`: A built-in wide-angle camera. (focal length between 24mm and 35mm)
 * * `"telephoto-camera"`: A built-in camera device with a longer focal length than a wide-angle camera. (focal length between above 85mm)
 */
export type PhysicalCameraDeviceType = 'ultra-wide-angle-camera' | 'wide-angle-camera' | 'telephoto-camera';

/**
 * Indentifiers for a logical camera (Combinations of multiple physical cameras to create a single logical camera).
 *
 * * `"dual-camera"`: A combination of wide-angle and telephoto cameras that creates a capture device.
 * * `"dual-wide-camera"`: A device that consists of two cameras of fixed focal length, one ultrawide angle and one wide angle.
 * * `"triple-camera"`: A device that consists of three cameras of fixed focal length, one ultrawide angle, one wide angle, and one telephoto.
 */
export type LogicalCameraDeviceType = 'dual-camera' | 'dual-wide-camera' | 'triple-camera';

/**
 * Parses an array of physical device types into a single {@linkcode PhysicalCameraDeviceType} or {@linkcode LogicalCameraDeviceType}, depending what matches.
 * @method
 */
export const parsePhysicalDeviceTypes = (
  physicalDeviceTypes: PhysicalCameraDeviceType[],
): PhysicalCameraDeviceType | LogicalCameraDeviceType => {
  if (physicalDeviceTypes.length === 1) {
    // @ts-expect-error for very obvious reasons
    return physicalDeviceTypes[0];
  }

  const hasWide = physicalDeviceTypes.includes('wide-angle-camera');
  const hasUltra = physicalDeviceTypes.includes('ultra-wide-angle-camera');
  const hasTele = physicalDeviceTypes.includes('telephoto-camera');
  if (hasTele && hasWide && hasUltra) return 'triple-camera';

  if (hasWide && hasUltra) return 'dual-wide-camera';

  if (hasWide && hasTele) return 'dual-camera';

  throw new Error(`Invalid physical device type combination! ${physicalDeviceTypes.join(' + ')}`);
};

/**
 * Indicates a format's color space.
 *
 * #### The following colorspaces are available on iOS:
 * * `"srgb"`: The sGRB color space.
 * * `"p3-d65"`: The P3 D65 wide color space which uses Illuminant D65 as the white point
 * * `"hlg-bt2020"`: The BT2020 wide color space which uses Illuminant D65 as the white point and Hybrid Log-Gamma as the transfer function
 *
 * > See ["AVCaptureColorSpace"](https://developer.apple.com/documentation/avfoundation/avcapturecolorspace) for more information.
 *
 * #### The following colorspaces are available on Android:
 * * `"yuv"`: The Multi-plane Android YCbCr color space. (YUV 420_888, 422_888 or 444_888)
 * * `"jpeg"`: The compressed JPEG color space.
 * * `"jpeg-depth"`: The compressed JPEG color space including depth data.
 * * `"raw"`: The Camera's RAW sensor color space. (Single-channel Bayer-mosaic image, usually 16 bit)
 * * `"heic"`: The compressed HEIC color space.
 * * `"private"`: The Android private opaque image format. (The choices of the actual format and pixel data layout are entirely up to the device-specific and framework internal implementations, and may vary depending on use cases even for the same device. These buffers are not directly accessible to the application)
 * * `"depth-16"`: The Android dense depth image format (16 bit)
 * * `"unknown"`: Placeholder for an unknown image/pixel format. [Edit this file](https://github.com/cuvent/react-native-vision-camera/edit/main/android/src/main/java/com/mrousavy/camera/parsers/ImageFormat+String.kt) to add a name for the unknown format.
 *
 * > See ["Android Color Formats"](https://jbit.net/Android_Colors/) for more information.
 */
export type ColorSpace =
  // ios
  | 'hlg-bt2020'
  | 'p3-d65'
  | 'srgb'
  // android
  | 'yuv'
  | 'jpeg'
  | 'jpeg-depth'
  | 'raw'
  | 'heic'
  | 'private'
  | 'depth-16'
  | 'unknown';

/**
 * Indicates a format's autofocus system.
 *
 * * `"none"`: Indicates that autofocus is not available
 * * `"contrast-detection"`: Indicates that autofocus is achieved by contrast detection. Contrast detection performs a focus scan to find the optimal position
 * * `"phase-detection"`: Indicates that autofocus is achieved by phase detection. Phase detection has the ability to achieve focus in many cases without a focus scan. Phase detection autofocus is typically less visually intrusive than contrast detection autofocus
 */
export type AutoFocusSystem = 'contrast-detection' | 'phase-detection' | 'none';

/**
 * Indicates a format's supported video stabilization mode
 *
 * * `"off"`: Indicates that video should not be stabilized
 * * `"standard"`: Indicates that video should be stabilized using the standard video stabilization algorithm introduced with iOS 5.0. Standard video stabilization has a reduced field of view. Enabling video stabilization may introduce additional latency into the video capture pipeline
 * * `"cinematic"`: Indicates that video should be stabilized using the cinematic stabilization algorithm for more dramatic results. Cinematic video stabilization has a reduced field of view compared to standard video stabilization. Enabling cinematic video stabilization introduces much more latency into the video capture pipeline than standard video stabilization and consumes significantly more system memory. Use narrow or identical min and max frame durations in conjunction with this mode
 * * `"cinematic-extended"`: Indicates that the video should be stabilized using the extended cinematic stabilization algorithm. Enabling extended cinematic stabilization introduces longer latency into the video capture pipeline compared to the AVCaptureVideoStabilizationModeCinematic and consumes more memory, but yields improved stability. It is recommended to use identical or similar min and max frame durations in conjunction with this mode (iOS 13.0+)
 * * `"auto"`: Indicates that the most appropriate video stabilization mode for the device and format should be chosen automatically
 */
export type VideoStabilizationMode = 'off' | 'standard' | 'cinematic' | 'cinematic-extended' | 'auto';

export interface FrameRateRange {
  minFrameRate: number;
  maxFrameRate: number;
}

/**
 * A Camera Device's video format. Do not create instances of this type yourself, only use {@linkcode Camera.getAvailableCameraDevices | Camera.getAvailableCameraDevices()}.
 */
export interface CameraDeviceFormat {
  /**
   * The height of the highest resolution a still image (photo) can be produced in
   */
  photoHeight: number;
  /**
   * The width of the highest resolution a still image (photo) can be produced in
   */
  photoWidth: number;
  /**
   * The video resolutions's height
   *
   * @platform iOS 13.0
   */
  videoHeight?: number;
  /**
   * The video resolution's width
   *
   * @platform iOS 13.0
   */
  videoWidth?: number;
  /**
   * A boolean value specifying whether this format supports the highest possible photo quality that can be delivered on the current platform.
   *
   * @platform iOS 13.0+
   */
  isHighestPhotoQualitySupported?: boolean;
  /**
   * Maximum supported ISO value
   */
  maxISO: number;
  /**
   * Minimum supported ISO value
   */
  minISO: number;
  /**
   * The video field of view in degrees
   */
  fieldOfView: number;
  /**
   * The maximum zoom factor
   */
  maxZoom: number;
  /**
   * The available color spaces.
   *
   * Note: On Android, this will always be only `["yuv"]`
   */
  colorSpaces: ColorSpace[];
  /**
   * Specifies whether this format supports HDR mode for video capture
   */
  supportsVideoHDR: boolean;
  /**
   * Specifies whether this format supports HDR mode for photo capture
   */
  supportsPhotoHDR: boolean;
  /**
   * All available frame rate ranges. You can query this to find the highest frame rate available
   */
  frameRateRanges: FrameRateRange[];
  /**
   * Specifies this format's auto focus system.
   */
  autoFocusSystem: AutoFocusSystem;
  /**
   * All supported video stabilization modes
   */
  videoStabilizationModes: VideoStabilizationMode[];
}

/**
 * Represents a camera device discovered by the {@linkcode Camera.getAvailableCameraDevices | Camera.getAvailableCameraDevices()} function
 */
export interface CameraDevice {
  /**
   * The native ID of the camera device instance.
   */
  id: string;
  /**
   * The physical devices this `CameraDevice` contains.
   *
   * * If this camera device is a **logical camera** (combination of multiple physical cameras), there are multiple cameras in this array.
   * * If this camera device is a **physical camera**, there is only a single element in this array.
   *
   * You can check if the camera is a logical multi-camera by using the `isMultiCam` property.
   */
  devices: PhysicalCameraDeviceType[];
  /**
   * Specifies the physical position of this camera. (back or front)
   */
  position: CameraPosition;
  /**
   * A friendly localized name describing the camera.
   */
  name: string;
  /**
   * Specifies whether this camera supports enabling flash for photo capture.
   */
  hasFlash: boolean;
  /**
   * Specifies whether this camera supports continuously enabling the flash to act like a torch (flash with video capture)
   */
  hasTorch: boolean;
  /**
   * A property indicating whether the receiver is a logical camera consisting of multiple physical cameras.
   *
   * Examples:
   * * The Dual Camera, which supports seamlessly switching between a wide and telephoto camera while zooming and generating depth data from the disparities between the different points of view of the physical cameras.
   * * The TrueDepth Camera, which generates depth data from disparities between a YUV camera and an Infrared camera pointed in the same direction.
   */
  isMultiCam: boolean;
  /**
   * Minimum available zoom factor
   */
  minZoom: number;
  /**
   * Maximum available zoom factor
   */
  maxZoom: number;
  /**
   * The zoom factor where the camera is "neutral".
   *
   * * For single-physical cameras this property is always `1.0`.
   * * For multi cameras this property is a value between `minZoom` and `maxZoom`, where the camera is in _wide-angle_ mode and hasn't switched to the _ultra-wide-angle_ (`0.5`x zoom) or telephoto camera yet.
   *
   * Use this value as an initial value for the zoom property if you implement custom zoom. (e.g. reanimated shared value should be initially set to this value)
   * @example
   * const device = ...
   *
   * const neutralZoomPercent = (device.neutralZoom - device.minZoom) / (device.maxZoom - device.minZoom)
   * const zoomFactor = useSharedValue(neutralZoomPercent) // <-- initial value so it doesn't start at ultra-wide
   * const cameraProps = useAnimatedProps(() => ({
   *   zoom: zoomFactor.value
   * }))
   */
  neutralZoom: number;
  /**
   * All available formats for this camera device. Use this to find the best format for your use case and set it to the Camera's {@linkcode CameraProps.format | Camera's .format} property.
   *
   * See [the Camera Formats documentation](https://cuvent.github.io/react-native-vision-camera/docs/guides/formats) for more information about Camera Formats.
   */
  formats: CameraDeviceFormat[];
  /**
   * Whether this camera device supports enabling photo and video capture at the same time.
   *
   * * On **iOS** devices this value is always `true`.
   * * On newer **Android** devices this value is always `true`.
   * * On older **Android** devices this value is `true` if the device's hardware level is `LIMITED` or above, `false` otherwise. (`LEGACY`) (See [this table](https://developer.android.com/reference/android/hardware/camera2/CameraDevice#regular-capture))
   *
   * If the device does not allow enabling `photo` and `video` capture at the same time, you might want to fall back to **snapshot capture** (See [**"Taking Snapshots"**](https://cuvent.github.io/react-native-vision-camera/docs/guides/capturing#taking-snapshots)) instead:
   *
   * @example
   * ```tsx
   * const captureMode = device.supportsPhotoAndVideoCapture ? "photo" : "snapshot"
   * return (
   *   <Camera
   *     photo={captureMode === "photo"}
   *     video={true}
   *     audio={true}
   *   />
   * )
   * ```
   */
  supportsPhotoAndVideoCapture: boolean;
  /**
   * Whether this camera device supports low light boost.
   */
  supportsLowLightBoost: boolean;
  /**
   * Whether this camera supports taking photos with depth data.
   *
   * **! Work in Progress !**
   */
  supportsDepthCapture: boolean;
  /**
   * Whether this camera supports taking photos in RAW format
   *
   * **! Work in Progress !**
   */
  supportsRawCapture: boolean;
  /**
   * Specifies whether this device supports focusing ({@linkcode Camera.focus | Camera.focus(...)})
   */
  supportsFocus: boolean;
}
