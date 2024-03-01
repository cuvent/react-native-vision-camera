package com.mrousavy.camera.core

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCharacteristics
import android.util.Range
import android.util.Size
import android.util.SizeF
import android.view.WindowManager
import androidx.camera.camera2.internal.Camera2CameraInfoImpl
import androidx.camera.core.CameraInfo
import androidx.camera.core.DisplayOrientedMeteringPointFactory
import androidx.camera.core.DynamicRange
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.impl.CameraInfoInternal
import androidx.camera.core.impl.capability.PreviewCapabilitiesImpl
import androidx.camera.extensions.ExtensionMode
import androidx.camera.extensions.ExtensionsManager
import androidx.camera.video.Quality.ConstantQuality
import androidx.camera.video.Recorder
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.mrousavy.camera.extensions.id
import com.mrousavy.camera.extensions.toJSValue
import com.mrousavy.camera.types.AutoFocusSystem
import com.mrousavy.camera.types.DeviceType
import com.mrousavy.camera.types.HardwareLevel
import com.mrousavy.camera.types.Orientation
import com.mrousavy.camera.types.PixelFormat
import com.mrousavy.camera.types.Position
import com.mrousavy.camera.types.VideoStabilizationMode
import com.mrousavy.camera.utils.CamcorderProfileUtils
import kotlin.math.atan2
import kotlin.math.sqrt

@SuppressLint("RestrictedApi")
@Suppress("FoldInitializerAndIfToElvis")
class CameraDeviceDetails(
  private val cameraInfo: CameraInfo,
  extensionsManager: ExtensionsManager,
  private val context: ReactApplicationContext
) {
  // Generic props available on all implementations
  private val cameraId = cameraInfo.id ?: throw NoCameraDeviceError()
  private val position = Position.fromLensFacing(cameraInfo.lensFacing)
  private val name = "${cameraInfo.implementationType} ($cameraId)"
  private val hasFlash = cameraInfo.hasFlashUnit()
  private val minZoom = cameraInfo.zoomState.value?.minZoomRatio ?: 0f
  private val maxZoom = cameraInfo.zoomState.value?.maxZoomRatio ?: 1f
  private val minExposure = cameraInfo.exposureState.exposureCompensationRange.lower
  private val maxExposure = cameraInfo.exposureState.exposureCompensationRange.upper
  private val supportsFocus = getSupportsFocus()
  private val supportsRawCapture = false
  private val supportsDepthCapture = false
  private val autoFocusSystem = if (supportsFocus) AutoFocusSystem.CONTRAST_DETECTION else AutoFocusSystem.NONE
  private val previewCapabilities = PreviewCapabilitiesImpl.from(cameraInfo)
  private val videoCapabilities = Recorder.getVideoCapabilities(cameraInfo, Recorder.VIDEO_CAPABILITIES_SOURCE_CAMCORDER_PROFILE)
  private val supports10BitHdr = getSupports10BitHDR()

  // CameraX internal props
  private val cameraInfoInternal = cameraInfo as CameraInfoInternal

  // Camera2 specific props
  private val camera2Details = cameraInfo as? Camera2CameraInfoImpl
  private val physicalDeviceIds = camera2Details?.cameraCharacteristicsMap?.keys ?: emptySet()
  private val isMultiCam = physicalDeviceIds.size > 1
  private val sensorRotationDegrees = camera2Details?.sensorRotationDegrees ?: 0
  private val sensorOrientation = Orientation.fromRotationDegrees(sensorRotationDegrees)
  private val cameraHardwareLevel = camera2Details?.cameraCharacteristicsCompat?.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL)
  private val hardwareLevel = HardwareLevel.fromCameraHardwareLevel(
    cameraHardwareLevel ?: CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY
  )
  private val minFocusDistance = getMinFocusDistanceCm()
  private val isoRange = getIsoRange()
  private val maxFieldOfView = getMaxFieldOfView()

  // Extensions
  private val supportsHdrExtension = extensionsManager.isExtensionAvailable(cameraInfo.cameraSelector, ExtensionMode.HDR)
  private val supportsLowLightBoostExtension = extensionsManager.isExtensionAvailable(cameraInfo.cameraSelector, ExtensionMode.NIGHT)

  fun toMap(): ReadableMap {
    val deviceTypes = getDeviceTypes()
    val formats = getFormats()

    val map = Arguments.createMap()
    map.putString("id", cameraId)
    map.putArray("physicalDevices", deviceTypes.toJSValue())
    map.putString("position", position.unionValue)
    map.putString("name", name)
    map.putBoolean("hasFlash", hasFlash)
    map.putBoolean("hasTorch", hasFlash)
    map.putDouble("minFocusDistance", minFocusDistance)
    map.putBoolean("isMultiCam", isMultiCam)
    map.putBoolean("supportsRawCapture", supportsRawCapture)
    map.putBoolean("supportsLowLightBoost", supportsLowLightBoostExtension)
    map.putBoolean("supportsFocus", supportsFocus)
    map.putDouble("minZoom", minZoom.toDouble())
    map.putDouble("maxZoom", maxZoom.toDouble())
    map.putDouble("neutralZoom", 1.0) // Zoom is always relative to 1.0 on Android
    map.putInt("minExposure", minExposure)
    map.putInt("maxExposure", maxExposure)
    map.putString("hardwareLevel", hardwareLevel.unionValue)
    map.putString("sensorOrientation", sensorOrientation.unionValue)
    map.putArray("formats", formats)
    return map
  }

  /**
   * Get a list of formats (or "possible stream resolution combinations") that this device supports.
   *
   * This filters all resolutions according to the
   * [Camera2 "StreamConfigurationMap" documentation](https://developer.android.com/reference/android/hardware/camera2/params/StreamConfigurationMap)
   */
  private fun getFormats(): ReadableArray {
    val array = Arguments.createArray()

    val dynamicRangeProfiles = videoCapabilities.supportedDynamicRanges

    dynamicRangeProfiles.forEach { dynamicRange ->
      val qualities = videoCapabilities.getSupportedQualities(dynamicRange)
      val videoSizes = qualities.map { it as ConstantQuality }.flatMap { it.typicalSizes }
      val photoSizes = cameraInfoInternal.getSupportedResolutions(ImageFormat.JPEG)
      val fpsRanges = cameraInfo.supportedFrameRateRanges
      val minFps = fpsRanges.minOf { it.lower }
      val maxFps = fpsRanges.maxOf { it.upper }

      videoSizes.forEach { videoSize ->
        val maxFpsForSize = CamcorderProfileUtils.getMaximumFps(cameraId, videoSize) ?: maxFps
        val fpsRange = Range(minFps, maxFpsForSize)

        photoSizes.forEach { photoSize ->
          val map = buildFormatMap(photoSize, videoSize, fpsRange)
          array.pushMap(map)
        }
      }
    }

    return array
  }

  private fun createPixelFormats(): ReadableArray {
    // Every output in Camera2 supports YUV and NATIVE
    val array = Arguments.createArray()
    array.pushString(PixelFormat.YUV.unionValue)
    array.pushString(PixelFormat.NATIVE.unionValue)
    return array
  }

  private fun buildFormatMap(photoSize: Size, videoSize: Size, fpsRange: Range<Int>): ReadableMap {
    val map = Arguments.createMap()
    map.putInt("photoHeight", photoSize.height)
    map.putInt("photoWidth", photoSize.width)
    map.putInt("videoHeight", videoSize.height)
    map.putInt("videoWidth", videoSize.width)
    map.putInt("minFps", fpsRange.lower)
    map.putInt("maxFps", fpsRange.upper)
    map.putInt("minISO", isoRange.lower)
    map.putInt("maxISO", isoRange.upper)
    map.putDouble("fieldOfView", maxFieldOfView)
    map.putBoolean("supportsVideoHdr", supports10BitHdr || supportsHdrExtension)
    map.putBoolean("supportsPhotoHdr", supportsHdrExtension)
    map.putBoolean("supportsDepthCapture", supportsDepthCapture)
    map.putString("autoFocusSystem", autoFocusSystem.unionValue)
    map.putArray("videoStabilizationModes", createStabilizationModes())
    map.putArray("pixelFormats", createPixelFormats())
    return map
  }

  private fun getSupports10BitHDR(): Boolean =
    videoCapabilities.supportedDynamicRanges.any { range ->
      range.is10BitHdr || range == DynamicRange.HDR_UNSPECIFIED_10_BIT
    }

  private fun getSupportsFocus(): Boolean {
    val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    @Suppress("DEPRECATION")
    val display = windowManager.defaultDisplay
    val pointFactory = DisplayOrientedMeteringPointFactory(display, cameraInfo, 1f, 1f)
    val point = pointFactory.createPoint(0.5f, 0.5f)
    val action = FocusMeteringAction.Builder(point)
    return cameraInfo.isFocusMeteringSupported(action.build())
  }

  private fun getMinFocusDistanceCm(): Double {
    val device = cameraInfo as? Camera2CameraInfoImpl
    if (device == null) {
      // Device is not a Camera2 device.
      return 0.0
    }

    val distance = device.cameraCharacteristicsCompat.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE)
    if (distance == null || distance == 0f) return 0.0
    if (distance.isNaN() || distance.isInfinite()) return 0.0
    // distance is in "diopters", meaning 1/meter. Convert to meters, then centi-meters
    return 1.0 / distance * 100.0
  }

  private fun getIsoRange(): Range<Int> {
    val device = cameraInfo as? Camera2CameraInfoImpl
    if (device == null) {
      // Device is not a Camera2 device.
      return Range(0, 0)
    }

    val range = device.cameraCharacteristicsCompat.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
    return range ?: Range(0, 0)
  }

  private fun createStabilizationModes(): ReadableArray {
    val modes = mutableSetOf(VideoStabilizationMode.OFF)
    if (videoCapabilities.isStabilizationSupported) {
      modes.add(VideoStabilizationMode.CINEMATIC)
    }
    if (previewCapabilities.isStabilizationSupported) {
      modes.add(VideoStabilizationMode.CINEMATIC_EXTENDED)
    }

    val array = Arguments.createArray()
    modes.forEach { mode ->
      array.pushString(mode.unionValue)
    }
    return array
  }

  private fun getDeviceTypes(): List<DeviceType> {
    val defaultList = listOf(DeviceType.WIDE_ANGLE)
    val camera2Details = camera2Details ?: return defaultList

    val deviceTypes = camera2Details.cameraCharacteristicsMap.map { (_, characteristics) ->
      val sensorSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE) ?: return@map DeviceType.WIDE_ANGLE
      val focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS) ?: return@map DeviceType.WIDE_ANGLE
      val fov = getMaxFieldOfView(focalLengths, sensorSize)

      return@map when {
        fov > 94 -> DeviceType.ULTRA_WIDE_ANGLE
        fov in 60f..94f -> DeviceType.WIDE_ANGLE
        fov < 60f -> DeviceType.TELEPHOTO
        else -> throw Error("Invalid Field Of View! ($fov)")
      }
    }

    return deviceTypes
  }

  private fun getFieldOfView(focalLength: Float, sensorSize: SizeF): Double {
    if ((sensorSize.width == 0f) || (sensorSize.height == 0f)) {
      return 0.0
    }
    val sensorDiagonal = sqrt((sensorSize.width * sensorSize.width + sensorSize.height * sensorSize.height).toDouble())
    val fovRadians = 2.0 * atan2(sensorDiagonal, (2.0 * focalLength))
    return Math.toDegrees(fovRadians)
  }

  private fun getMaxFieldOfView(focalLengths: FloatArray, sensorSize: SizeF): Double {
    val smallestFocalLength = focalLengths.minOrNull() ?: return 0.0
    return getFieldOfView(smallestFocalLength, sensorSize)
  }

  private fun getMaxFieldOfView(): Double {
    val characteristics = camera2Details?.cameraCharacteristicsCompat ?: return 0.0
    val sensorSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE) ?: return 0.0
    val focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS) ?: return 0.0
    return getMaxFieldOfView(focalLengths, sensorSize)
  }
}
