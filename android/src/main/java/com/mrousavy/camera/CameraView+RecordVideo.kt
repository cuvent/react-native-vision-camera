package com.mrousavy.camera

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import androidx.camera.core.VideoCapture
import androidx.core.content.ContextCompat
import com.facebook.react.bridge.*
import com.mrousavy.camera.utils.makeErrorMap
import kotlinx.coroutines.*
import java.io.File

data class TemporaryFile(val path: String)

@SuppressLint("RestrictedApi", "MissingPermission")
suspend fun CameraView.startRecording(options: ReadableMap, onRecordCallback: Callback): TemporaryFile {
  if (videoCapture == null) {
    if (video == true) {
      throw CameraNotReadyError()
    } else {
      throw VideoNotEnabledError()
    }
  }

  // check audio permission
  if (audio == true) {
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      throw MicrophonePermissionError()
    }
  }

  if (options.hasKey("flash")) {
    val enableFlash = options.getString("flash") == "on"
    // overrides current torch mode value to enable flash while recording
    camera!!.cameraControl.enableTorch(enableFlash)
  }

  @Suppress("BlockingMethodInNonBlockingContext") // in withContext we are not blocking. False positive.
  val videoFile = withContext(Dispatchers.IO) {
    File.createTempFile("video", ".mp4", context.cacheDir).apply { deleteOnExit() }
  }
  val videoFileOptions = VideoCapture.OutputFileOptions.Builder(videoFile)

  videoCapture!!.startRecording(
    videoFileOptions.build(), recordVideoExecutor,
    object : VideoCapture.OnVideoSavedCallback {
      override fun onVideoSaved(outputFileResults: VideoCapture.OutputFileResults) {
        val map = Arguments.createMap()
        map.putString("path", videoFile.absolutePath)
        // TODO: duration and size - see https://github.com/cuvent/react-native-vision-camera/issues/77
        onRecordCallback(map, null)

        // reset the torch mode
        camera!!.cameraControl.enableTorch(torch == "on")
      }

      override fun onError(videoCaptureError: Int, message: String, cause: Throwable?) {
        val error = when (videoCaptureError) {
          VideoCapture.ERROR_ENCODER -> VideoEncoderError(message, cause)
          VideoCapture.ERROR_FILE_IO -> FileIOError(message, cause)
          VideoCapture.ERROR_INVALID_CAMERA -> InvalidCameraError(message, cause)
          VideoCapture.ERROR_MUXER -> VideoMuxerError(message, cause)
          VideoCapture.ERROR_RECORDING_IN_PROGRESS -> RecordingInProgressError(message, cause)
          else -> UnknownCameraError(Error(message, cause))
        }
        val map = makeErrorMap("${error.domain}/${error.id}", error.message, error)
        onRecordCallback(null, map)

        // reset the torch mode
        camera!!.cameraControl.enableTorch(torch == "on")
      }
    }
  )

  return TemporaryFile(videoFile.absolutePath)
}

@SuppressLint("RestrictedApi")
fun CameraView.stopRecording() {
  if (videoCapture == null) {
    throw CameraNotReadyError()
  }

  videoCapture!!.stopRecording()
  // reset torch mode to original value
  camera!!.cameraControl.enableTorch(torch == "on")
}
