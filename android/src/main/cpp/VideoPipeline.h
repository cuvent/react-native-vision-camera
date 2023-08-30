//
// Created by Marc Rousavy on 25.08.23.
//

#pragma once

#include <jni.h>
#include <fbjni/fbjni.h>
#include <EGL/egl.h>
#include <android/native_window.h>
#include "PassThroughShader.h"
#include "OpenGLRenderer.h"
#include "OpenGLContext.h"
#include <memory>

#include "SkiaRenderer.h"

namespace vision {

#define NO_TEXTURE 0
#define DEFAULT_FRAMEBUFFER 0

using namespace facebook;

class VideoPipeline: public jni::HybridClass<VideoPipeline> {
 public:
  static auto constexpr kJavaDescriptor = "Lcom/mrousavy/camera/utils/VideoPipeline;";
  static jni::local_ref<jhybriddata> initHybrid(jni::alias_ref<jhybridobject> jThis, int width, int height);
  static void registerNatives();

 public:
  ~VideoPipeline();

  // -> SurfaceTexture input
  int getInputTextureId();

  // <- Frame Processor output
  void setFrameProcessorOutputSurface(jobject surface);
  void removeFrameProcessorOutputSurface();

  // <- MediaRecorder output
  void setRecordingSessionOutputSurface(jobject surface);
  void removeRecordingSessionOutputSurface();

  // <- Preview output
  void setPreviewOutputSurface(jobject surface);
  void removePreviewOutputSurface();

  // Frame callbacks
  void onBeforeFrame();
  void onFrame(jni::alias_ref<jni::JArrayFloat> transformMatrix);

  // Skia integration (acts as middleman)
  void setSkiaRenderer(jni::alias_ref<SkiaRenderer::javaobject> skiaRenderer);
  void removeSkiaRenderer();

 private:
  // Private constructor. Use `create(..)` to create new instances.
  explicit VideoPipeline(jni::alias_ref<jhybridobject> jThis, int width, int height);

 private:
  // Input Surface Texture
  GLuint _inputTextureId = NO_TEXTURE;
  int _width = 0;
  int _height = 0;

  // Frame Buffer we're rendering to
  //   (per default it's FBO0, aka the onscreen buffer)
  //   (if we have a Skia context, it's a separate offscreen buffer)
  GLuint _framebuffer = DEFAULT_FRAMEBUFFER;

  // Output Contexts
  std::shared_ptr<OpenGLContext> _context = nullptr;
  std::unique_ptr<OpenGLRenderer> _frameProcessorOutput = nullptr;
  std::unique_ptr<OpenGLRenderer> _recordingSessionOutput = nullptr;
  std::unique_ptr<OpenGLRenderer> _previewOutput = nullptr;
  jni::global_ref<SkiaRenderer::javaobject> _skiaRenderer = nullptr;

 private:
  friend HybridBase;
  jni::global_ref<javaobject> _javaPart;
  static constexpr auto TAG = "VideoPipeline";
};

} // namespace vision
