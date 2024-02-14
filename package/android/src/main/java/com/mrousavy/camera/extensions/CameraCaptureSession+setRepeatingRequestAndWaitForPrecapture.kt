package com.mrousavy.camera.extensions

import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CaptureFailure
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.CaptureResult
import android.hardware.camera2.TotalCaptureResult
import android.util.Log
import com.mrousavy.camera.core.CaptureAbortedError
import com.mrousavy.camera.core.CaptureTimedOutError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.coroutineContext

private const val TAG = "CameraCaptureSession"

enum class PrecaptureTrigger {
  AE,
  AF,
  AWB
}

enum class AutoMode {
  Active,
  Passive
}

enum class FocusState {
  Inactive,
  Scanning,
  Focused,
  NotFocused;

  val isCompleted: Boolean
    get() = this == Focused || this == NotFocused

  companion object {
    fun fromAFState(afState: Int): FocusState {
      return when (afState) {
        CaptureResult.CONTROL_AF_STATE_INACTIVE -> Inactive
        CaptureResult.CONTROL_AF_STATE_ACTIVE_SCAN -> Scanning
        CaptureResult.CONTROL_AF_STATE_FOCUSED_LOCKED -> Focused
        CaptureResult.CONTROL_AF_STATE_NOT_FOCUSED_LOCKED -> NotFocused
        CaptureResult.CONTROL_AF_STATE_PASSIVE_SCAN -> Scanning
        CaptureResult.CONTROL_AF_STATE_PASSIVE_FOCUSED -> Focused
        CaptureResult.CONTROL_AF_STATE_PASSIVE_UNFOCUSED -> NotFocused
        else -> throw Error("Invalid CONTROL_AF_STATE! $afState")
      }
    }
  }
}
enum class ExposureState {
  Locked,
  Inactive,
  Precapture,
  Searching,
  Converged,
  FlashRequired;

  val isCompleted: Boolean
    get() = this == Converged || this == FlashRequired

  companion object {
    fun fromAEState(aeState: Int): ExposureState {
      return when (aeState) {
        CaptureResult.CONTROL_AE_STATE_INACTIVE -> Inactive
        CaptureResult.CONTROL_AE_STATE_SEARCHING -> Searching
        CaptureResult.CONTROL_AE_STATE_PRECAPTURE -> Precapture
        CaptureResult.CONTROL_AE_STATE_CONVERGED -> Converged
        CaptureResult.CONTROL_AE_STATE_FLASH_REQUIRED -> FlashRequired
        CaptureResult.CONTROL_AE_STATE_LOCKED -> Locked
        else -> throw Error("Invalid CONTROL_AE_STATE! $aeState")
      }
    }
  }
}

enum class WhiteBalanceState {
  Inactive,
  Locked,
  Searching,
  Converged;

  val isCompleted: Boolean
    get() = this == Converged

  companion object {
    fun fromAWBState(awbState: Int): WhiteBalanceState {
      return when (awbState) {
        CaptureResult.CONTROL_AWB_STATE_INACTIVE -> Inactive
        CaptureResult.CONTROL_AWB_STATE_SEARCHING -> Searching
        CaptureResult.CONTROL_AWB_STATE_CONVERGED -> Converged
        CaptureResult.CONTROL_AWB_STATE_LOCKED -> Locked
        else -> throw Error("Invalid CONTROL_AWB_STATE! $awbState")
      }
    }
  }
}

data class ResultState(val focusState: FocusState, val exposureState: ExposureState, val whiteBalanceState: WhiteBalanceState)

/**
 * Set a new repeating request for the [CameraCaptureSession] that contains a precapture trigger, and wait until the given precaptures have locked.
 */
suspend fun CameraCaptureSession.setRepeatingRequestAndWaitForPrecapture(
  request: CaptureRequest,
  vararg precaptureTriggers: PrecaptureTrigger
): ResultState =
  suspendCancellableCoroutine { continuation ->
    // Map<PrecaptureTrigger, Boolean> of all completed precaptures
    val completed = precaptureTriggers.associateWith { false }.toMutableMap()

    CoroutineScope(Dispatchers.Default).launch {
      delay(5000) // after 5s, cancel capture
      if (continuation.isActive) {
        Log.e(TAG, "Precapture timed out after 5 seconds!")
        continuation.resumeWithException(CaptureTimedOutError())
        try {
          setRepeatingRequest(request, null, null)
        } catch (e: Throwable) {
          // session might have already been closed
          Log.e(TAG, "Error resetting session repeating request..", e)
        }
      }
    }

    this.setRepeatingRequest(
      request,
      object : CameraCaptureSession.CaptureCallback() {
        override fun onCaptureCompleted(session: CameraCaptureSession, request: CaptureRequest, result: TotalCaptureResult) {
          super.onCaptureCompleted(session, request, result)

          if (continuation.isActive) {
            // AF Precapture
            val afState = FocusState.fromAFState(result.get(CaptureResult.CONTROL_AF_STATE) ?: CaptureResult.CONTROL_AF_STATE_INACTIVE)
            val aeState = ExposureState.fromAEState(result.get(CaptureResult.CONTROL_AE_STATE) ?: CaptureResult.CONTROL_AE_STATE_INACTIVE)
            val awbState = WhiteBalanceState.fromAWBState(result.get(CaptureResult.CONTROL_AWB_STATE) ?: CaptureResult.CONTROL_AWB_STATE_INACTIVE)

            if (precaptureTriggers.contains(PrecaptureTrigger.AF) && completed[PrecaptureTrigger.AF] != true) {
              if (afState.isCompleted) {
                completed[PrecaptureTrigger.AF] = true
                Log.i(TAG, "AF precapture completed! State: $afState")
              } else {
                Log.i(TAG, "AF State: $afState")
              }
            }
            // AE Precapture
            if (precaptureTriggers.contains(PrecaptureTrigger.AE) && completed[PrecaptureTrigger.AE] != true) {
              if (aeState.isCompleted) {
                completed[PrecaptureTrigger.AE] = true
                Log.i(TAG, "AE precapture completed! State: $aeState")
              } else {
                Log.i(TAG, "AE State: $aeState")
              }
            }
            // AWB Precapture
            if (precaptureTriggers.contains(PrecaptureTrigger.AWB) && completed[PrecaptureTrigger.AWB] != true) {
              if (awbState.isCompleted) {
                completed[PrecaptureTrigger.AWB] = true
                Log.i(TAG, "AWB precapture completed! State: $awbState")
              } else {
                Log.i(TAG, "AWB State: $awbState")
              }
            }

            if (completed.values.all { it == true }) {
              // All precaptures did complete!
              continuation.resume(ResultState(afState, aeState, awbState))
              session.setRepeatingRequest(request, null, null)
            }
          }
        }
        override fun onCaptureFailed(session: CameraCaptureSession, request: CaptureRequest, failure: CaptureFailure) {
          super.onCaptureFailed(session, request, failure)

          if (continuation.isActive) {
            continuation.resumeWithException(CaptureAbortedError(failure.wasImageCaptured()))
            session.setRepeatingRequest(request, null, null)
          }
        }
      },
      null
    )
  }
