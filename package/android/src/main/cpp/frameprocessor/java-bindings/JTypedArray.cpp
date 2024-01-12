//
// Created by Marc Rousavy on 12.01.24.
//

#include "JTypedArray.h"
#include <android/log.h>

namespace vision {

using namespace facebook;

TypedArrayKind getTypedArrayKind(int unsafeEnumValue) {
    return static_cast<TypedArrayKind>(unsafeEnumValue);
}

JTypedArray::JTypedArray(const jni::alias_ref<JTypedArray::jhybridobject>& javaThis,
                         const jni::alias_ref<JVisionCameraProxy::javaobject>& proxy,
                         int dataType, int size) {
    _javaPart = jni::make_global(javaThis);
    _proxy = jni::make_global(proxy);

    jsi::Runtime& runtime = *proxy->cthis()->getJSRuntime();
    TypedArrayKind kind = getTypedArrayKind(dataType);
    __android_log_print(ANDROID_LOG_INFO, TAG, "Allocating ArrayBuffer with size %i and type %i...", size, dataType);
    _array = std::make_shared<TypedArrayBase>(runtime, size, kind);

    jsi::ArrayBuffer arrayBuffer = _array->getBuffer(runtime);
    __android_log_print(ANDROID_LOG_INFO, TAG, "Wrapping ArrayBuffer in a JNI ByteBuffer");
    auto byteBuffer = jni::JByteBuffer::wrapBytes(arrayBuffer.data(runtime), arrayBuffer.size(runtime));
    _byteBuffer = jni::make_global(byteBuffer);
    __android_log_print(ANDROID_LOG_INFO, TAG, "Successfully created TypedArray!");
}

void JTypedArray::registerNatives() {
    registerHybrid({
       makeNativeMethod("initHybrid", JTypedArray::initHybrid),
       makeNativeMethod("getByteBuffer", JTypedArray::getByteBuffer),
    });
}

jni::local_ref<jni::JByteBuffer> JTypedArray::getByteBuffer() {
    return jni::make_local(_byteBuffer);
}

jni::local_ref<JTypedArray::jhybriddata> JTypedArray::initHybrid(jni::alias_ref<jhybridobject> javaThis,
                                                                 jni::alias_ref<JVisionCameraProxy::javaobject> proxy,
                                                                 jint type,
                                                                 jint size) {
    return makeCxxInstance(javaThis, proxy, type, size);
}

} // vision