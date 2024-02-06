package com.mrousavy.camera.extensions

import android.view.SurfaceHolder
import androidx.annotation.UiThread
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

@UiThread
suspend fun SurfaceHolder.resize(width: Int, height: Int) {
  return suspendCancellableCoroutine { continuation ->
    val frame = this.surfaceFrame
    if (frame.width() == width && frame.height() == height) {
      // Already in target size
      continuation.resume(Unit)
      return@suspendCancellableCoroutine
    }

    val callback = object: SurfaceHolder.Callback {
      override fun surfaceCreated(holder: SurfaceHolder) = Unit
      override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        holder.removeCallback(this)
        continuation.resume(Unit)
      }
      override fun surfaceDestroyed(holder: SurfaceHolder) {
        holder.removeCallback(this)
        continuation.cancel(Error("Tried to resize SurfaceView, but Surface has been destroyed!"))
      }
    }
    this.addCallback(callback)
    this.setFixedSize(width, height)
  }
}
