#include <jni.h>
#include <fbjni/fbjni.h>
#include "frameprocessor/java-bindings/JVisionCameraScheduler.h"
#include "frameprocessor/java-bindings/JFrameProcessor.h"
#include "frameprocessor/java-bindings/JVisionCameraProxy.h"
#include "frameprocessor/VisionCameraProxy.h"
#include "skia/SkiaRenderer.h"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *) {
  return facebook::jni::initialize(vm, [] {
    vision::VisionCameraInstaller::registerNatives();
    vision::JVisionCameraProxy::registerNatives();
    vision::JVisionCameraScheduler::registerNatives();
#if VISION_CAMERA_ENABLE_FRAME_PROCESSORS
    vision::JFrameProcessor::registerNatives();
#endif
#if VISION_CAMERA_ENABLE_SKIA
    vision::SkiaRenderer::registerNatives();
#endif
  });
}
