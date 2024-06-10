package com.mrousavy.camera.react

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.core.content.ContextCompat
import com.facebook.react.bridge.Callback
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.modules.core.PermissionAwareActivity
import com.facebook.react.modules.core.PermissionListener
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.common.UIManagerType
import com.mrousavy.camera.BuildConfig
import com.mrousavy.camera.core.CameraError
import com.mrousavy.camera.core.CameraQueues
import com.mrousavy.camera.core.ViewNotFoundError
import com.mrousavy.camera.core.types.PermissionStatus
import com.mrousavy.camera.core.types.RecordVideoOptions
import com.mrousavy.camera.core.types.SnapshotOptions
import com.mrousavy.camera.core.utils.runOnUiThread
import com.mrousavy.camera.core.utils.runOnUiThreadAndWait
import com.mrousavy.camera.frameprocessors.VisionCameraInstaller
import com.mrousavy.camera.frameprocessors.VisionCameraProxy
import com.mrousavy.camera.react.utils.makeErrorMap
import com.mrousavy.camera.react.utils.withPromise
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.cancel
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

@ReactModule(name = CameraViewModule.TAG)
@Suppress("unused")
class CameraViewModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
  companion object {
    const val TAG = "CameraView"
    var sharedRequestCode = 10

    init {
      try {
        // Load the native part of VisionCamera.
        // Includes the OpenGL VideoPipeline, as well as Frame Processor JSI bindings
        System.loadLibrary("VisionCamera")
      } catch (e: UnsatisfiedLinkError) {
        Log.e(VisionCameraProxy.TAG, "Failed to load VisionCamera C++ library!", e)
        throw e
      }
    }
  }

  private val backgroundCoroutineScope = CoroutineScope(CameraQueues.cameraExecutor.asCoroutineDispatcher())

  override fun invalidate() {
    super.invalidate()
    if (backgroundCoroutineScope.isActive) {
      backgroundCoroutineScope.cancel("CameraViewModule has been destroyed.")
    }
  }

  override fun getName(): String = TAG

  private suspend fun findCameraView(viewId: Int): CameraView =
    runOnUiThreadAndWait {
      Log.d(TAG, "Finding view $viewId...")
      val context = reactApplicationContext ?: throw Error("React Context was null!")

      val uiManagerType = if (BuildConfig.IS_NEW_ARCHITECTURE_ENABLED) UIManagerType.FABRIC else UIManagerType.DEFAULT
      val uiManager = UIManagerHelper.getUIManager(context, uiManagerType) ?: throw Error("UIManager not found!")

      val view = uiManager.resolveView(viewId) as? CameraView ?: throw ViewNotFoundError(viewId)
      Log.d(TAG, "Found view $viewId!")
      return@runOnUiThreadAndWait view
    }

  @ReactMethod(isBlockingSynchronousMethod = true)
  fun installFrameProcessorBindings(): Boolean =
    try {
      val proxy = VisionCameraProxy(reactApplicationContext)
      VisionCameraInstaller.install(proxy)
      true
    } catch (e: Error) {
      Log.e(TAG, "Failed to install Frame Processor JSI Bindings!", e)
      false
    }

  @ReactMethod
  fun takePhoto(viewTag: Int, options: ReadableMap, promise: Promise) {
    backgroundCoroutineScope.launch {
      val view = findCameraView(viewTag)
      withPromise(promise) {
        view.takePhoto(options)
      }
    }
  }

  @ReactMethod
  fun takeSnapshot(viewTag: Int, jsOptions: ReadableMap, promise: Promise) {
    backgroundCoroutineScope.launch {
      val view = findCameraView(viewTag)
      runOnUiThread {
        try {
          val options = SnapshotOptions.fromJSValue(jsOptions)
          val result = view.takeSnapshot(options)
          promise.resolve(result)
        } catch (e: Throwable) {
          promise.reject(e)
        }
      }
    }
  }

  // TODO: startRecording() cannot be awaited, because I can't have a Promise and a onRecordedCallback in the same function. Hopefully TurboModules allows that
  @ReactMethod
  fun startRecording(viewTag: Int, jsOptions: ReadableMap, onRecordCallback: Callback) {
    backgroundCoroutineScope.launch {
      val view = findCameraView(viewTag)
      try {
        val options = RecordVideoOptions(jsOptions)
        view.startRecording(options, onRecordCallback)
      } catch (error: CameraError) {
        val map = makeErrorMap("${error.domain}/${error.id}", error.message, error)
        onRecordCallback(null, map)
      } catch (error: Throwable) {
        val map =
          makeErrorMap("capture/unknown", "An unknown error occurred while trying to start a video recording! ${error.message}", error)
        onRecordCallback(null, map)
      }
    }
  }

  @ReactMethod
  fun pauseRecording(viewTag: Int, promise: Promise) {
    backgroundCoroutineScope.launch {
      withPromise(promise) {
        val view = findCameraView(viewTag)
        view.pauseRecording()
        return@withPromise null
      }
    }
  }

  @ReactMethod
  fun resumeRecording(viewTag: Int, promise: Promise) {
    backgroundCoroutineScope.launch {
      val view = findCameraView(viewTag)
      withPromise(promise) {
        view.resumeRecording()
        return@withPromise null
      }
    }
  }

  @ReactMethod
  fun stopRecording(viewTag: Int, promise: Promise) {
    backgroundCoroutineScope.launch {
      val view = findCameraView(viewTag)
      withPromise(promise) {
        view.stopRecording()
        return@withPromise null
      }
    }
  }

  @ReactMethod
  fun cancelRecording(viewTag: Int, promise: Promise) {
    backgroundCoroutineScope.launch {
      val view = findCameraView(viewTag)
      withPromise(promise) {
        view.cancelRecording()
        return@withPromise null
      }
    }
  }

  @ReactMethod
  fun focus(viewTag: Int, point: ReadableMap, promise: Promise) {
    backgroundCoroutineScope.launch {
      val view = findCameraView(viewTag)
      withPromise(promise) {
        view.focus(point)
        return@withPromise null
      }
    }
  }

  @ExperimentalCamera2Interop
  @ReactMethod
  fun focusDepth(viewTag: Int, distance: Double, promise: Promise) {
    backgroundCoroutineScope.launch {
      val view = findCameraView(viewTag)
      withPromise(promise) {
        view.focusDepth(distance)
        return@withPromise null
      }
    }
  }

  private fun canRequestPermission(permission: String): Boolean {
    val activity = currentActivity as? PermissionAwareActivity
    return activity?.shouldShowRequestPermissionRationale(permission) ?: false
  }

  private fun getPermission(permission: String): PermissionStatus {
    val status = ContextCompat.checkSelfPermission(reactApplicationContext, permission)
    var parsed = PermissionStatus.fromPermissionStatus(status)
    if (parsed == PermissionStatus.DENIED && canRequestPermission(permission)) {
      parsed = PermissionStatus.NOT_DETERMINED
    }
    return parsed
  }

  @ReactMethod(isBlockingSynchronousMethod = true)
  fun getCameraPermissionStatus(): String {
    val status = getPermission(Manifest.permission.CAMERA)
    return status.unionValue
  }

  @ReactMethod(isBlockingSynchronousMethod = true)
  fun getMicrophonePermissionStatus(): String {
    val status = getPermission(Manifest.permission.RECORD_AUDIO)
    return status.unionValue
  }

  @ReactMethod(isBlockingSynchronousMethod = true)
  fun getLocationPermissionStatus(): String {
    val fineStatus = getPermission(Manifest.permission.ACCESS_FINE_LOCATION)
    if (fineStatus == PermissionStatus.GRANTED) {
      return fineStatus.unionValue
    }

    val coarseStatus = getPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
    return coarseStatus.unionValue
  }

  private fun requestPermission(permission: String, promise: Promise) {
    val activity = reactApplicationContext.currentActivity
    if (activity is PermissionAwareActivity) {
      val currentRequestCode = sharedRequestCode++
      val listener = PermissionListener { requestCode: Int, _: Array<String>, grantResults: IntArray ->
        if (requestCode == currentRequestCode) {
          val permissionStatus = if (grantResults.isNotEmpty()) grantResults[0] else PackageManager.PERMISSION_DENIED
          val parsed = PermissionStatus.fromPermissionStatus(permissionStatus)
          promise.resolve(parsed.unionValue)
          return@PermissionListener true
        }
        return@PermissionListener false
      }
      activity.requestPermissions(arrayOf(permission), currentRequestCode, listener)
    } else {
      promise.reject("NO_ACTIVITY", "No PermissionAwareActivity was found! Make sure the app has launched before calling this function.")
    }
  }

  @ReactMethod
  fun requestCameraPermission(promise: Promise) {
    requestPermission(Manifest.permission.CAMERA, promise)
  }

  @ReactMethod
  fun requestMicrophonePermission(promise: Promise) {
    requestPermission(Manifest.permission.RECORD_AUDIO, promise)
  }

  @ReactMethod
  fun requestLocationPermission(promise: Promise) {
    requestPermission(Manifest.permission.ACCESS_FINE_LOCATION, promise)
  }
}
