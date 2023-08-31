//
// Created by Marc Rousavy on 29.08.23.
//

#include "OpenGLRenderer.h"

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

#include <android/native_window.h>
#include <android/hardware_buffer_jni.h>
#include <android/log.h>

#include <utility>

#include "OpenGLError.h"

namespace vision {

std::unique_ptr<OpenGLRenderer> OpenGLRenderer::CreateWithWindowSurface(std::shared_ptr<OpenGLContext> context, ANativeWindow* surface) {
  return std::unique_ptr<OpenGLRenderer>(new OpenGLRenderer(std::move(context), surface));
}

OpenGLRenderer::OpenGLRenderer(std::shared_ptr<OpenGLContext> context, ANativeWindow* surface) {
  _context = std::move(context);
  _outputSurface = surface;
  _width = ANativeWindow_getWidth(surface);
  _height = ANativeWindow_getHeight(surface);
}

OpenGLRenderer::~OpenGLRenderer() {
  if (_outputSurface != nullptr) {
    ANativeWindow_release(_outputSurface);
  }
  destroy();
}

void OpenGLRenderer::destroy() {
  if (_context != nullptr && _surface != EGL_NO_DISPLAY) {
    __android_log_print(ANDROID_LOG_INFO, TAG, "Destroying OpenGL Surface...");
    eglDestroySurface(_context->display, _surface);
    _surface = EGL_NO_SURFACE;
  }
}

EGLSurface OpenGLRenderer::getEGLSurface() {
  if (_surface == EGL_NO_SURFACE) {
    __android_log_print(ANDROID_LOG_INFO, TAG, "Creating Window Surface...");
    _context->use();
    _surface = eglCreateWindowSurface(_context->display, _context->config, _outputSurface, nullptr);
  }
  return _surface;
}

void OpenGLRenderer::renderTextureToSurface(const OpenGLTexture& texture, float* transformMatrix) {
  // 1. Get (or create) the OpenGL EGLSurface which is the window render target (Android Surface)
  EGLSurface surface = getEGLSurface();

  // 2. Activate the OpenGL context for this surface
  _context->use(surface);
  OpenGLError::checkIfError("Failed to use context!");

  // 3. Set the viewport for rendering
  glViewport(0, 0, _width, _height);
  glDisable(GL_BLEND);
  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);

  // 4. Draw it using the pass-through shader which binds the texture and applies transforms
  _passThroughShader.draw(texture, transformMatrix);

  // 5 Swap buffers to pass it to the window surface
  _context->flush();
  OpenGLError::checkIfError("Failed to render Frame to Surface!");
}

void OpenGLRenderer::renderTextureToHardwareBuffer(const OpenGLTexture& texture,
                                                   AHardwareBuffer* hardwareBuffer,
                                                   float* transformMatrix) {
  EGLClientBuffer clientBuffer = eglGetNativeClientBufferANDROID(hardwareBuffer);

  EGLint attribs[] = { EGL_IMAGE_PRESERVED_KHR, EGL_TRUE,
                       EGL_NONE };
  EGLDisplay display = eglGetCurrentDisplay();
  // eglCreateImageKHR will add a ref to the AHardwareBuffer
  EGLImageKHR image = eglCreateImageKHR(display,
                                        EGL_NO_CONTEXT,
                                        EGL_NATIVE_BUFFER_ANDROID,
                                        clientBuffer,
                                        attribs);
  if (image == EGL_NO_IMAGE_KHR) {
    throw OpenGLError("Failed to create KHR Image from HardwareBuffer!");
  }

  AHardwareBuffer_Desc description;
  AHardwareBuffer_describe(hardwareBuffer, &description);

  OpenGLTexture bufferTexture = _context->createTexture(OpenGLTexture::Type::Texture2D,
                                                        description.width,
                                                        description.height);

  glBindTexture(bufferTexture.target, bufferTexture.id);
  OpenGLError::checkIfError("Failed to bind to HardwareBuffer texture!");

  glEGLImageTargetTexture2DOES(bufferTexture.target, image);
  OpenGLError::checkIfError("Failed to configure HardwareBuffer as target texture!");

  glViewport(0, 0, description.width, description.height);
  glDisable(GL_BLEND);
  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);

  // 4. Draw it using the pass-through shader which binds the texture and applies transforms
  _passThroughShader.draw(texture, transformMatrix);

  // 5 Swap buffers to pass it to the window surface
  _context->flush();
}

} // namespace vision
