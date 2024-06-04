package com.mrousavy.camera.react

import androidx.camera.camera2.interop.ExperimentalCamera2Interop

@ExperimentalCamera2Interop
fun CameraView.focusDepth(distance: Double) {
  cameraSession.focusDepth(distance)
}
