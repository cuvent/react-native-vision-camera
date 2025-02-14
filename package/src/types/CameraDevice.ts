import type { Orientation } from './Orientation'

/**
 * Represents the camera device position.
 *
 * * `"back"`: Indicates that the device is physically located on the back of the phone
 * * `"front"`: Indicates that the device is physically located on the front of the phone
 * * `"external"`: The camera device is an external camera, and has no fixed facing relative to the phone. (e.g. USB or Continuity Cameras)
 */
export type CameraPosition = 'front' | 'back' | 'external'

/**
 * Indentifiers for a physical camera (one that actually exists on the back/front of the device)
 *
 * * `"ultra-wide-angle-camera"`: A built-in camera with a shorter focal length than that of a wide-angle camera. (FOV of 94° or higher)
 * * `"wide-angle-camera"`: A built-in wide-angle camera. (FOV between 60° and 94°)
 * * `"telephoto-camera"`: A built-in camera device with a longer focal length than a wide-angle camera. (FOV of 60° or lower)
 *
 * Some Camera devices consist of multiple physical devices. They can be interpreted as _logical devices_, for example:
 *
 * * `"ultra-wide-angle-camera"` + `"wide-angle-camera"` = **dual wide-angle camera**.
 * * `"wide-angle-camera"` + `"telephoto-camera"` = **dual camera**.
 * * `"ultra-wide-angle-camera"` + `"wide-angle-camera"` + `"telephoto-camera"` = **triple camera**.
 */
export type PhysicalCameraDeviceType = 'ultra-wide-angle-camera' | 'wide-angle-camera' | 'telephoto-camera'

/**
 * Indicates a format's autofocus system.
 *
 * * `"none"`: Indicates that autofocus is not available
 * * `"contrast-detection"`: Indicates that autofocus is achieved by contrast detection. Contrast detection performs a focus scan to find the optimal position
 * * `"phase-detection"`: Indicates that autofocus is achieved by phase detection. Phase detection has the ability to achieve focus in many cases without a focus scan. Phase detection autofocus is typically less visually intrusive than contrast detection autofocus
 */
export type AutoFocusSystem = 'contrast-detection' | 'phase-detection' | 'none'

/**
 * Indicates a format's supported video stabilization mode. Enabling video stabilization may introduce additional latency into the video capture pipeline.
 *
 * * `"off"`: No video stabilization. Indicates that video should not be stabilized
 * * `"standard"`: Standard software-based video stabilization. Standard video stabilization reduces the field of view by about 10%.
 * * `"cinematic"`: Advanced software-based video stabilization. This applies more aggressive cropping or transformations than standard.
 * * `"cinematic-extended"`: Extended software- and hardware-based stabilization that aggressively crops and transforms the video to apply a smooth cinematic stabilization.
 * * `"auto"`: Indicates that the most appropriate video stabilization mode for the device and format should be chosen automatically
 */
export type VideoStabilizationMode = 'off' | 'standard' | 'cinematic' | 'cinematic-extended' | 'auto'

/**
 * A Camera Device's stream-configuration format.
 *
 * A format specifies:
 * - Video Resolution (`videoWidth`/`videoHeight`)
 * - Photo Resolution (`photoWidth`/`photoHeight`)
 * - Possible FPS ranges (`fps`)
 * - Video Stabilization Modes (`videoStabilizationModes`)
 */
export interface CameraDeviceFormat {
  /**
   * The height of the highest resolution a still image (photo) can be produced in
   */
  photoHeight: number
  /**
   * The width of the highest resolution a still image (photo) can be produced in
   */
  photoWidth: number
  /**
   * The video resolutions's height
   */
  videoHeight: number
  /**
   * The video resolution's width
   */
  videoWidth: number
  /**
   * Maximum supported ISO value
   */
  maxISO: number
  /**
   * Minimum supported ISO value
   */
  minISO: number
  /**
   * The video field of view in degrees
   */
  fieldOfView: number
  /**
   * Specifies whether this format supports HDR mode for video capture
   */
  supportsVideoHdr: boolean
  /**
   * Specifies whether this format supports HDR mode for photo capture
   */
  supportsPhotoHdr: boolean
  /**
   * Specifies whether this format supports delivering depth data for photo or video capture.
   */
  supportsDepthCapture: boolean
  /**
   * The minum frame rate this Format needs to run at. High resolution formats often run at lower frame rates.
   */
  minFps: number
  /**
   * The maximum frame rate this Format is able to run at. High resolution formats often run at lower frame rates.
   */
  maxFps: number
  /**
   * Specifies this format's auto focus system.
   */
  autoFocusSystem: AutoFocusSystem
  /**
   * All supported video stabilization modes
   */
  videoStabilizationModes: VideoStabilizationMode[]
}

/**
 * Represents a camera device discovered by the {@linkcode Camera.getAvailableCameraDevices | Camera.getAvailableCameraDevices()} function
 */
export interface CameraDevice {
  /**
   * The native ID of the camera device instance.
   */
  id: string
  /**
   * The physical devices this `CameraDevice` consists of.
   *
   * * If this camera device is a **logical camera** (combination of multiple physical cameras, e.g. "Triple Camera"), there are multiple cameras in this array.
   * * If this camera device is a **physical camera** (e.g. "wide-angle-camera"), there is only a single element in this array.
   *
   * You can check if the camera is a logical multi-camera by using the `isMultiCam` property.
   */
  physicalDevices: PhysicalCameraDeviceType[]
  /**
   * Specifies the physical position of this camera.
   * - `back`: The Camera Device is located on the back of the phone. These devices can be used for capturing what's in front of the user.
   * - `front`: The Camera Device is located on the front of the phone. These devices can be used for selfies or FaceTime.
   * - `external`: The Camera Device is an external device. These devices can be either:
   *     - USB Camera Devices (if they support the [USB Video Class (UVC) Specification](https://en.wikipedia.org/wiki/List_of_USB_video_class_devices))
   *     - [Continuity Camera Devices](https://support.apple.com/en-us/HT213244) (e.g. your iPhone's or Mac's Camera connected through WiFi/Continuity)
   *     - Bluetooth/WiFi Camera Devices (if they are supported in the platform-native Camera APIs; Camera2 and AVFoundation)
   */
  position: CameraPosition
  /**
   * A friendly localized name describing the camera.
   */
  name: string
  /**
   * Specifies whether this camera supports enabling flash for photo capture.
   */
  hasFlash: boolean
  /**
   * Specifies whether this camera supports continuously enabling the flash to act like a torch (flash with video capture)
   */
  hasTorch: boolean
  /**
   * The minimum distance this device can properly focus to (in centimeters/cm) or `0` if unknown.
   */
  minFocusDistance: number
  /**
   * A property indicating whether the device is a virtual multi-camera consisting of multiple combined physical cameras.
   *
   * Examples:
   * * The Dual Camera, which supports seamlessly switching between a wide and telephoto camera while zooming and generating depth data from the disparities between the different points of view of the physical cameras.
   * * The TrueDepth Camera, which generates depth data from disparities between a YUV camera and an Infrared camera pointed in the same direction.
   */
  isMultiCam: boolean
  /**
   * Minimum available zoom factor (e.g. `1`)
   */
  minZoom: number
  /**
   * Maximum available zoom factor (e.g. `128`)
   */
  maxZoom: number
  /**
   * The zoom factor where the camera is "neutral".
   *
   * * For single-physical cameras this property is always `1.0`.
   * * For multi cameras this property is a value between `minZoom` and `maxZoom`, where the camera is in _wide-angle_ mode and hasn't switched to the _ultra-wide-angle_ ("fish-eye") or telephoto camera yet.
   *
   * Use this value as an initial value for the zoom property if you implement custom zoom. (e.g. reanimated shared value should be initially set to this value)
   * @example
   * const device = ...
   *
   * const zoom = useSharedValue(device.neutralZoom) // <-- initial value so it doesn't start at ultra-wide
   * const cameraProps = useAnimatedProps(() => ({
   *   zoom: zoom.value
   * }))
   */
  neutralZoom: number
  /**
   * The minimum Exposure-Bias value this format supports. When setting the `exposure` to this value, the image is almost completely dark (under-exposed).
   */
  minExposure: number
  /**
   * The maximum Exposure-Bias value this format supports. When setting the `exposure` to this value, the image is almost completely bright (over-exposed).
   */
  maxExposure: number
  /**
   * All available formats for this camera device. Use this to find the best format for your use case and set it to the Camera's {@linkcode CameraProps.format | Camera's .format} property.
   *
   * See [the Camera Formats documentation](https://react-native-vision-camera.com/docs/guides/formats) for more information about Camera Formats.
   */
  formats: CameraDeviceFormat[]
  /**
   * Whether this camera device supports low light boost.
   */
  supportsLowLightBoost: boolean
  /**
   * Whether this camera supports taking photos in RAW format
   *
   * **! Work in Progress !**
   */
  supportsRawCapture: boolean
  /**
   * Specifies whether this device supports focusing ({@linkcode Camera.focus | Camera.focus(...)})
   */
  supportsFocus: boolean
  /**
   * Specifies whether this devices supports depth data output streaming.
   */
  supportsDepthData: boolean
  /**
   * The hardware level of the Camera.
   * - On Android, some older devices are running at a `legacy` or `limited` level which means they are running in a backwards compatible mode.
   * - On iOS, all devices are `full`.
   */
  hardwareLevel: 'legacy' | 'limited' | 'full'
  /**
   * Represents the sensor's orientation relative to the phone.
   * For most phones this will be landscape, as Camera sensors are usually always rotated by 90 degrees (i.e. width and height are flipped).
   *
   * All Camera streams will stream in this orientation. To properly rotate the buffers "up-right",
   * frames will need to be counter-rotated by this orientation here.
   * - For photo and video capture this is handled using EXIF flags.
   * - For preview this is handled using view transforms (rotate + translate matrix).
   * - For frame processors this needs to be handled manually by the user (see `Frame.orientation`)
   *
   * @see See ["Orientation"](https://react-native-vision-camera.com/docs/guides/orientation)
   */
  sensorOrientation: Orientation
}
