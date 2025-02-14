import type { Orientation } from './Orientation'
import type { PixelFormat } from './PixelFormat'

/**
 * A single frame, as seen by the camera. This is backed by a C++ HostObject wrapping the native GPU buffer.
 * At a 4k resolution, a raw Frame can be 12MB in size.
 *
 * @example
 * ```ts
 * const frameProcessor = useFrameProcessor((frame) => {
 *   'worklet'
 *   console.log(`Frame: ${frame.width}x${frame.height} (${frame.pixelFormat})`)
 * }, [])
 * ```
 */
export interface Frame {
  /**
   * Whether the underlying buffer is still valid or not.
   * A Frame is valid as long as your Frame Processor (or a `runAsync(..)` operation) is still running
   */
  readonly isValid: boolean
  /**
   * Returns the width of the frame, in pixels.
   */
  readonly width: number
  /**
   * Returns the height of the frame, in pixels.
   */
  readonly height: number
  /**
   * Returns the amount of bytes per row.
   */
  readonly bytesPerRow: number
  /**
   * Returns the number of planes this frame contains.
   */
  readonly planesCount: number
  /**
   * Returns whether the Frame is mirrored (selfie camera) or not.
   */
  readonly isMirrored: boolean
  /**
   * Returns the timestamp of the Frame relative to the host sytem's clock.
   */
  readonly timestamp: number
  /**
   * Represents the orientation of the Frame, relative of what the desired output orientation is.
   *
   * For example, if the phone is held in `'portrait'` mode and the Frame's {@linkcode orientation}
   * is `'landscape-left'`, it is 90° rotated relative to the phone's rotation.
   *
   * To make the frame appear up-right, one would need to counter-rotate it by 90°.
   * Such counter-rotations should not actually rotate pixels in the buffers,
   * but instead be handled via flags or transforms to avoid any performance overheads.
   *
   * For example in MLKit, the caller just needs to pass the Frame's {@linkcode orientation}
   * to it's `detect(...)` function and it will interpret buffers in that target orientation.
   *
   * @see See ["Orientation"](https://react-native-vision-camera.com/docs/guides/orientation)
   */
  readonly orientation: Orientation
  /**
   * Represents the pixel-format of the Frame.
   */
  readonly pixelFormat: PixelFormat

  /**
   * Represents the depth data of this Frame, if the Camera is configured to stream depth data.
   */
  readonly depth?: {
    readonly width: number
    readonly height: number
  }

  /**
   * Get the underlying data of the Frame as a uint8 array buffer.
   *
   * The format of the buffer depends on the Frame's {@linkcode pixelFormat}.
   *
   * Note that Frames are allocated on the GPU, so calling `toArrayBuffer()` will copy from the GPU to the CPU.
   *
   * @example
   * ```ts
   * const frameProcessor = useFrameProcessor((frame) => {
   *   'worklet'
   *
   *   if (frame.pixelFormat === 'rgb') {
   *     const buffer = frame.toArrayBuffer()
   *     const data = new Uint8Array(buffer)
   *     console.log(`Pixel at 0,0: RGB(${data[0]}, ${data[1]}, ${data[2]})`)
   *   }
   * }, [])
   * ```
   */
  toArrayBuffer(): ArrayBuffer
  /**
   * Returns a string representation of the frame.
   * @example
   * ```ts
   * console.log(frame.toString()) // -> "3840 x 2160 Frame"
   * ```
   */
  toString(): string
  /**
   * Get the native platform buffer of the Frame.
   * - On Android, this is a `AHardwareBuffer*`
   * - On iOS, this is a `CVPixelBufferRef`
   *
   * The native buffer needs to be manually deleted using
   * {@linkcode NativeBuffer.delete | NativeBuffer.delete()}, and this {@linkcode Frame}
   * needs to be kept alive as long as-, or longer than
   * the {@linkcode NativeBuffer}.
   */
  getNativeBuffer(): NativeBuffer
}

/**
 * A managed memory pointer to a native platform buffer
 */
export interface NativeBuffer {
  /**
   * A uint64_t/uintptr_t to the native platform buffer.
   * - On iOS; this points to a `CVPixelBufferRef`
   * - On Android; this points to a `AHardwareBuffer*`
   */
  pointer: bigint
  /**
   * Delete this reference to the platform buffer again.
   * There might still be other references, so it does not guarantee buffer deletion.
   *
   * This must always be called, otherwise the pipeline will stall.
   */
  delete(): void
}

/** @internal */
export interface FrameInternal extends Frame {
  /**
   * Increment the Frame Buffer ref-count by one.
   *
   * This is a private API, do not use this.
   * @internal
   */
  incrementRefCount(): void
  /**
   * Increment the Frame Buffer ref-count by one.
   *
   * This is a private API, do not use this.
   * @internal
   */
  decrementRefCount(): void
  /**
   * Assign a new base instance to this Frame, and have all properties and methods of
   * {@linkcode baseInstance} also be a part of this Frame.
   *
   * This is useful if you need to pass this {@linkcode Frame} to another consumer
   * (e.g. a native Frame Processor Plugin) and still need it to be a `jsi::HostObject` of
   * type `FrameHostObject` while containing properties of another instance ({@linkcode baseInstance})
   * @param baseInstance The base instance to use.
   * @internal
   * @example
   * ```ts
   * const canvas = skSurface.getCanvas()
   * const drawableFrame = frame.withBaseClass(canvas)
   * // now `drawableFrame` has all methods from `canvas`, as well as `frame`.
   * // it's actual type is still `FrameHostObject`, no `Proxy`, no `Object`, no `Canvas`.
   * drawableFrame.drawRect(...)
   * ```
   */
  withBaseClass<T>(baseInstance: T): T & Frame
}
