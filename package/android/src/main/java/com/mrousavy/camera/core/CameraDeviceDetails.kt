package com.mrousavy.camera.core

import android.annotation.SuppressLint
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCharacteristics
import android.util.Log
import android.util.Range
import android.util.Size
import android.util.SizeF
import androidx.camera.camera2.internal.Camera2CameraInfoImpl
import androidx.camera.core.CameraInfo
import androidx.camera.core.DynamicRange
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.SurfaceOrientedMeteringPointFactory
import androidx.camera.core.impl.CameraInfoInternal
import androidx.camera.core.impl.capability.PreviewCapabilitiesImpl
import androidx.camera.extensions.ExtensionMode
import androidx.camera.extensions.ExtensionsManager
import androidx.camera.video.Quality.ConstantQuality
import androidx.camera.video.Recorder
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.mrousavy.camera.core.extensions.id
import com.mrousavy.camera.core.types.AutoFocusSystem
import com.mrousavy.camera.core.types.DeviceType
import com.mrousavy.camera.core.types.HardwareLevel
import com.mrousavy.camera.core.types.Orientation
import com.mrousavy.camera.core.types.Position
import com.mrousavy.camera.core.types.VideoStabilizationMode
import com.mrousavy.camera.core.utils.CamcorderProfileUtils
import com.mrousavy.camera.react.extensions.toJSValue
import kotlin.math.atan2
import kotlin.math.min
import kotlin.math.sqrt

@SuppressLint("RestrictedApi")
@Suppress("FoldInitializerAndIfToElvis")
class CameraDeviceDetails(private val cameraInfo: CameraInfo, extensionsManager: ExtensionsManager) {
  companion object {
    private const val TAG = "CameraDeviceDetails"
  }

  // Generic props available on all implementations
  private val cameraId = cameraInfo.id ?: throw NoCameraDeviceError()
  private val position = Position.fromLensFacing(cameraInfo.lensFacing)
  private val name = "$cameraId ($position) ${cameraInfo.implementationType}"
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
  private val sensorRotationDegrees = cameraInfo.sensorRotationDegrees
  private val sensorOrientation = Orientation.fromRotationDegrees(sensorRotationDegrees)

  // CameraX internal props
  private val cameraInfoInternal = cameraInfo as CameraInfoInternal

  // Camera2 specific props
  private val camera2Details = cameraInfo as? Camera2CameraInfoImpl
  private val physicalDeviceIds = camera2Details?.cameraCharacteristicsMap?.keys ?: emptySet()
  private val isMultiCam = physicalDeviceIds.size > 1
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
      try {
        val qualities = videoCapabilities.getSupportedQualities(dynamicRange)
        val videoSizes = qualities.map { it as ConstantQuality }.flatMap { it.typicalSizes }
        val photoSizes = (cameraInfoInternal.getSupportedHighResolutions(ImageFormat.JPEG) union cameraInfoInternal.getSupportedResolutions(ImageFormat.JPEG)).toList()
        val fpsRanges = cameraInfo.supportedFrameRateRanges
        val minFps = fpsRanges.minOf { it.lower }
        val maxFps = fpsRanges.maxOf { it.upper }

        videoSizes.forEach { videoSize ->
          try {
            // not every size supports the maximum FPS range
            val maxFpsForSize = CamcorderProfileUtils.getMaximumFps(cameraId, videoSize) ?: maxFps
            // if the FPS range for this size is even smaller than min FPS, we need to clamp that as well.
            val minFpsForSize = min(minFps, maxFpsForSize)
            val fpsRange = Range(minFpsForSize, maxFpsForSize)

            photoSizes.forEach { photoSize ->
              try {
                val map = buildFormatMap(photoSize, videoSize, fpsRange)
                array.pushMap(map)
              } catch (error: Throwable) {
                Log.w(TAG, "Photo size ${photoSize.width}x${photoSize.height} cannot be used as a format!", error)
              }
            }
          } catch (error: Throwable) {
            Log.w(TAG, "Video size ${videoSize.width}x${videoSize.height} cannot be used as a format!", error)
          }
        }
      } catch (error: Throwable) {
        Log.w(TAG, "Dynamic Range Profile $dynamicRange cannot be used as a format!", error)
      }
    }

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
    map.putBoolean("supportsVideoHdr", supports10BitHdr)
    map.putBoolean("supportsPhotoHdr", supportsHdrExtension)
    map.putBoolean("supportsDepthCapture", supportsDepthCapture)
    map.putString("autoFocusSystem", autoFocusSystem.unionValue)
    map.putArray("videoStabilizationModes", createStabilizationModes())
    return map
  }

  private fun getSupports10BitHDR(): Boolean =
    videoCapabilities.supportedDynamicRanges.any { range ->
      range.is10BitHdr || range == DynamicRange.HDR_UNSPECIFIED_10_BIT
    }

  private fun getSupportsFocus(): Boolean {
    val point = SurfaceOrientedMeteringPointFactory(1.0f, 1.0f).createPoint(0.5f, 0.5f)
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
