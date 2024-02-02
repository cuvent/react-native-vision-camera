package com.mrousavy.camera.core

import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.TotalCaptureResult
import android.util.Log
import com.mrousavy.camera.core.outputs.SurfaceOutput
import com.mrousavy.camera.extensions.capture
import com.mrousavy.camera.extensions.createCaptureSession
import com.mrousavy.camera.extensions.isValid
import com.mrousavy.camera.extensions.openCamera
import com.mrousavy.camera.extensions.tryAbortCaptures
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.Closeable

/**
 * A [CameraCaptureSession] wrapper that safely handles interruptions and remains open whenever available.
 */
class PersistentCameraCaptureSession(private val cameraManager: CameraManager, private val callback: Callback) : Closeable {
  companion object {
    private var counter = 1
  }
  private val TAG = "PersistentCameraCaptureSession${counter++}"

  // Inputs/Dependencies
  private var cameraId: String? = null
  private var outputs: List<SurfaceOutput> = emptyList()
  private var repeatingRequest: RepeatingRequest? = null
  private var isActive = false

  // State/Dependants
  private var device: CameraDevice? = null // depends on [cameraId]
  private var session: CameraCaptureSession? = null // depends on [device, surfaceOutputs]
  private var cameraDeviceDetails: CameraDeviceDetails? = null // depends on [device]

  private val mutex = Mutex()
  private var didDestroyFromOutside = false

  val isRunning: Boolean
    get() = isActive && session != null && device != null && !didDestroyFromOutside

  private suspend fun getOrCreateDevice(cameraId: String): CameraDevice {
    val currentDevice = device
    if (currentDevice?.id == cameraId && currentDevice.isValid) {
      return currentDevice
    }

    Log.i(TAG, "Creating new device...")
    this.session?.tryAbortCaptures()
    this.device?.close()
    this.device = null
    this.session = null

    val newDevice = cameraManager.openCamera(cameraId, { device, error ->
      Log.i(TAG, "Camera $device closed!")
      if (this.device == device) {
        this.didDestroyFromOutside = true
        this.session?.tryAbortCaptures()
        this.session = null
        this.device = null
        this.isActive = false
      }
      if (error != null) {
        callback.onError(error)
      }
    }, CameraQueues.videoQueue)
    this.device = newDevice
    return newDevice
  }

  private suspend fun getOrCreateSession(device: CameraDevice, outputs: List<SurfaceOutput>): CameraCaptureSession {
    val currentSession = session
    if (currentSession?.device == device) {
      return currentSession
    }

    if (outputs.isEmpty()) throw NoOutputsError()

    Log.i(TAG, "Creating new session...")
    this.session?.tryAbortCaptures()
    
    val newSession = device.createCaptureSession(cameraManager, outputs, { session ->
      Log.i(TAG, "Session $session closed!")
      if (this.session == session) {
        this.didDestroyFromOutside = true
        this.session?.tryAbortCaptures()
        this.session = null
        this.isActive = false
      }
    }, CameraQueues.videoQueue)
    session = newSession
    return newSession
  }

  private fun getOrCreateCameraDeviceDetails(device: CameraDevice): CameraDeviceDetails {
    val currentDetails = cameraDeviceDetails
    if (currentDetails?.cameraId == device.id) {
      return currentDetails
    }

    val newDetails = CameraDeviceDetails(cameraManager, device.id)
    cameraDeviceDetails = newDetails
    return newDetails
  }

  private suspend fun configure() {
    if (didDestroyFromOutside && !isActive) {
      Log.d(TAG, "CameraCaptureSession has been destroyed by Android, skipping configuration until isActive is set to `true` again.")
      return
    }
    Log.d(TAG, "Configure() with isActive: $isActive, ID: $cameraId, device: $device, session: $session")
    val cameraId = cameraId ?: throw NoCameraDeviceError()
    val repeatingRequest = repeatingRequest ?: throw CameraNotReadyError()
    val outputs = outputs

    try {
      didDestroyFromOutside = false

      val device = getOrCreateDevice(cameraId)
      if (didDestroyFromOutside) return

      if (outputs.isEmpty()) return
      val session = getOrCreateSession(device, outputs)
      if (didDestroyFromOutside) return

      if (isActive) {
        Log.d(TAG, "Updating repeating request...")
        val details = getOrCreateCameraDeviceDetails(device)
        val captureRequest = repeatingRequest.toRepeatingRequest(device, details, outputs)
        session.setRepeatingRequest(captureRequest, null, null)
      } else {
        session.stopRepeating()
        Log.d(TAG, "Stopping repeating request...")
      }
      Log.d(TAG, "Configure() done! isActive: $isActive, ID: $cameraId, device: $device, session: $session")
    } catch (e: CameraAccessException) {
      if (didDestroyFromOutside) {
        // Camera device has been destroyed in the meantime, that's fine.
        Log.d(TAG, "Configure() canceled, session has been destroyed in the meantime!")
      } else {
        // Camera should still be active, so not sure what went wrong. Rethrow
        throw e
      }
    }
  }

  private fun assertLocked(method: String) {
    if (!mutex.isLocked) {
      throw SessionIsNotLockedError("Failed to call $method, session is not locked! Call beginConfiguration() first.")
    }
  }

  suspend fun withConfiguration(block: suspend () -> Unit) {
    mutex.withLock {
      block()
      configure()
    }
  }

  fun setInput(cameraId: String) {
    Log.d(TAG, "--> setInput($cameraId)")
    assertLocked("setInput")
    if (this.cameraId != cameraId || device?.id != cameraId) {
      this.cameraId = cameraId

      // Abort any captures in the session so we get the onCaptureFailed handler for any outstanding photos
      session?.tryAbortCaptures()
      session = null
      // Closing the device will also close the session above - even faster than manually closing it.
      device?.close()
      device = null
    }
  }

  fun setOutputs(outputs: List<SurfaceOutput>) {
    Log.d(TAG, "--> setOutputs($outputs)")
    assertLocked("setOutputs")
    if (this.outputs != outputs) {
      this.outputs = outputs

      if (outputs.isNotEmpty()) {
        // Outputs have changed to something else, we don't wanna destroy the session directly
        // so the outputs can be kept warm. The session that gets created next will take over the outputs.
        session?.tryAbortCaptures()
      } else {
        // Just stop it, we don't have any outputs
        session?.close()
      }
      session = null
    }
  }

  fun setRepeatingRequest(request: RepeatingRequest) {
    assertLocked("setRepeatingRequest")
    Log.d(TAG, "--> setRepeatingRequest(...)")
    if (this.repeatingRequest != request) {
      this.repeatingRequest = request
    }
  }

  fun setIsActive(isActive: Boolean) {
    assertLocked("setIsActive")
    Log.d(TAG, "--> setIsActive($isActive)")
    if (this.isActive != isActive) {
      this.isActive = isActive
    }
    if (isActive && didDestroyFromOutside) {
      didDestroyFromOutside = false
    }
  }

  suspend fun capture(request: CaptureRequest, enableShutterSound: Boolean): TotalCaptureResult {
    val session = session ?: throw CameraNotReadyError()
    return session.capture(request, enableShutterSound)
  }

  override fun close() {
    session?.tryAbortCaptures()
    device?.close()
  }

  interface Callback {
    fun onError(error: Throwable)
  }

  class SessionIsNotLockedError(message: String): Error(message)
}