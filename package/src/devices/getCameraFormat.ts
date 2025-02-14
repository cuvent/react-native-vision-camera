import type { AutoFocusSystem, CameraDevice, CameraDeviceFormat, VideoStabilizationMode } from '../types/CameraDevice'
import { CameraRuntimeError } from '../CameraError'

interface Size {
  width: number
  height: number
}

export interface FormatFilter {
  /**
   * The target resolution of the video (and frame processor) output pipeline.
   * If no format supports the given resolution, the format closest to this value will be used.
   */
  videoResolution?: Size | 'max'
  /**
   * The target resolution of the photo output pipeline.
   * If no format supports the given resolution, the format closest to this value will be used.
   */
  photoResolution?: Size | 'max'
  /**
   * The target aspect ratio of the video (and preview) output, expressed as a factor: `width / height`.
   * (Note: Cameras are in landscape orientation)
   *
   * In most cases, you want this to be as close to the screen's aspect ratio as possible (usually ~9:16).
   *
   * @example
   * ```ts
   * const screen = Dimensions.get('screen')
   * targetVideoAspectRatio: screen.height / screen.width
   * ```
   */
  videoAspectRatio?: number
  /**
   * The target aspect ratio of the photo output, expressed as a factor: `width / height`.
   * (Note: Cameras are in landscape orientation)
   *
   * In most cases, you want this to be the same as `targetVideoAspectRatio`, which you often want
   * to be as close to the screen's aspect ratio as possible (usually ~9:16)
   *
   * @example
   * ```ts
   * const screen = Dimensions.get('screen')
   * targetPhotoAspectRatio: screen.height / screen.width
   * ```
   */
  photoAspectRatio?: number
  /**
   * The target FPS you want to record video at.
   * If the FPS requirements can not be met, the format closest to this value will be used.
   */
  fps?: number | 'max'
  /**
   * The target video stabilization mode you want to use.
   * If no format supports the target video stabilization mode, the best other matching format will be used.
   */
  videoStabilizationMode?: VideoStabilizationMode
  /**
   * Whether you want to find a format that supports Photo HDR.
   */
  photoHdr?: boolean
  /**
   * Whether you want to find a format that supports Photo HDR.
   */
  videoHdr?: boolean
  /**
   * The target ISO value for capturing photos.
   * Higher ISO values tend to capture sharper photos, at the cost of reduced capture speed.
   * Lower ISO values tend to capture photos quicker.
   */
  iso?: number | 'max' | 'min'
  /**
   * The target auto-focus system.
   * While `phase-detection` is generally the best system available,
   * you might want to choose a different auto-focus system.
   */
  autoFocusSystem?: AutoFocusSystem
  /**
   * Specifies whether to prefer formats that support depth data capture.
   */
  depth?: boolean
}

type FilterWithPriority<T> = {
  target: Exclude<T, null | undefined>
  priority: number
}
type FilterMap = {
  [K in keyof FormatFilter]: FilterWithPriority<FormatFilter[K]>
}
function filtersToFilterMap(filters: FormatFilter[]): FilterMap {
  return filters.reduce<FilterMap>((map, curr, index) => {
    for (const key in curr) {
      // @ts-expect-error keys are untyped
      map[key] = {
        // @ts-expect-error keys are untyped
        // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
        target: curr[key],
        priority: filters.length - index,
      }
    }
    return map
  }, {})
}

/**
 * Get the best matching Camera format for the given device that satisfies your requirements using a sorting filter. By default, formats are sorted by highest to lowest resolution.
 *
 * The {@linkcode filters | filters} are ranked by priority, from highest to lowest.
 * This means the first item you pass will have a higher priority than the second, and so on.
 *
 * @param device The Camera Device you're currently using
 * @param filters The filters you want to use. The format that matches your filter the closest will be returned
 * @returns The format that matches your filter the closest.
 *
 * @example
 * ```ts
 * const format = getCameraFormat(device, [
 *   { videoResolution: { width: 3048, height: 2160 } },
 *   { fps: 60 }
 * ])
 * ```
 */
export function getCameraFormat(device: CameraDevice, filters: FormatFilter[]): CameraDeviceFormat {
  // Combine filters into a single filter map for constant-time lookup
  const filter = filtersToFilterMap(filters)

  let bestFormat = device.formats[0]
  if (bestFormat == null)
    throw new CameraRuntimeError('device/invalid-device', `The given Camera Device (${device.id}) does not have any formats!`)

  // Compare each format using a point scoring system
  for (const format of device.formats) {
    let leftPoints = 0
    let rightPoints = 0

    // Video Resolution
    if (filter.videoResolution != null) {
      const leftVideoResolution = bestFormat.videoWidth * bestFormat.videoHeight
      const rightVideoResolution = format.videoWidth * format.videoHeight
      if (filter.videoResolution.target === 'max') {
        // We just want the maximum resolution
        if (leftVideoResolution > rightVideoResolution) leftPoints += filter.videoResolution.priority
        if (rightVideoResolution > leftVideoResolution) rightPoints += filter.videoResolution.priority
      } else {
        // Find video resolution closest to the filter (ignoring orientation)
        const targetResolution = filter.videoResolution.target.width * filter.videoResolution.target.height
        const leftDiff = Math.abs(leftVideoResolution - targetResolution)
        const rightDiff = Math.abs(rightVideoResolution - targetResolution)
        if (leftDiff < rightDiff) leftPoints += filter.videoResolution.priority
        if (rightDiff < leftDiff) rightPoints += filter.videoResolution.priority
      }
    }

    // Photo Resolution
    if (filter.photoResolution != null) {
      const leftPhotoResolution = bestFormat.photoWidth * bestFormat.photoHeight
      const rightPhotoResolution = format.photoWidth * format.photoHeight
      if (filter.photoResolution.target === 'max') {
        // We just want the maximum resolution
        if (leftPhotoResolution > rightPhotoResolution) leftPoints += filter.photoResolution.priority
        if (rightPhotoResolution > leftPhotoResolution) rightPoints += filter.photoResolution.priority
      } else {
        // Find closest photo resolution to the filter (ignoring orientation)
        const targetResolution = filter.photoResolution.target.width * filter.photoResolution.target.height
        const leftDiff = Math.abs(leftPhotoResolution - targetResolution)
        const rightDiff = Math.abs(rightPhotoResolution - targetResolution)
        if (leftDiff < rightDiff) leftPoints += filter.photoResolution.priority
        if (rightDiff < leftDiff) rightPoints += filter.photoResolution.priority
      }
    }

    // Find closest aspect ratio (video)
    if (filter.videoAspectRatio != null) {
      const leftAspect = bestFormat.videoWidth / bestFormat.videoHeight
      const rightAspect = format.videoWidth / format.videoHeight
      const leftDiff = Math.abs(leftAspect - filter.videoAspectRatio.target)
      const rightDiff = Math.abs(rightAspect - filter.videoAspectRatio.target)
      if (leftDiff < rightDiff) leftPoints += filter.videoAspectRatio.priority
      if (rightDiff < leftDiff) rightPoints += filter.videoAspectRatio.priority
    }

    // Find closest aspect ratio (photo)
    if (filter.photoAspectRatio != null) {
      const leftAspect = bestFormat.photoWidth / bestFormat.photoHeight
      const rightAspect = format.photoWidth / format.photoHeight
      const leftDiff = Math.abs(leftAspect - filter.photoAspectRatio.target)
      const rightDiff = Math.abs(rightAspect - filter.photoAspectRatio.target)
      if (leftDiff < rightDiff) leftPoints += filter.photoAspectRatio.priority
      if (rightDiff < leftDiff) rightPoints += filter.photoAspectRatio.priority
    }

    // Find closest max FPS
    if (filter.fps != null) {
      if (filter.fps.target === 'max') {
        if (bestFormat.maxFps > format.maxFps) leftPoints += filter.fps.priority
        if (format.maxFps > bestFormat.maxFps) rightPoints += filter.fps.priority
      } else {
        if (bestFormat.maxFps >= filter.fps.target) leftPoints += filter.fps.priority
        if (format.maxFps >= filter.fps.target) rightPoints += filter.fps.priority
      }
    }

    // Find closest ISO
    if (filter.iso != null) {
      if (filter.iso.target === 'max') {
        if (bestFormat.maxISO > format.maxISO) leftPoints += filter.iso.priority
        if (format.maxISO > bestFormat.maxISO) rightPoints += filter.iso.priority
      } else if (filter.iso.target === 'min') {
        if (bestFormat.minISO < format.minISO) leftPoints += filter.iso.priority
        if (format.minISO < bestFormat.minISO) rightPoints += filter.iso.priority
      } else {
        if (filter.iso.target >= bestFormat.minISO && filter.iso.target <= bestFormat.maxISO) leftPoints += filter.iso.priority
        if (filter.iso.target >= format.minISO && filter.iso.target <= format.maxISO) rightPoints += filter.iso.priority
      }
    }

    // Find video stabilization mode
    if (filter.videoStabilizationMode != null) {
      if (bestFormat.videoStabilizationModes.includes(filter.videoStabilizationMode.target))
        leftPoints += filter.videoStabilizationMode.priority
      if (format.videoStabilizationModes.includes(filter.videoStabilizationMode.target))
        rightPoints += filter.videoStabilizationMode.priority
    }

    // Find Photo HDR formats
    if (filter.photoHdr != null) {
      if (bestFormat.supportsPhotoHdr === filter.photoHdr.target) leftPoints += filter.photoHdr.priority
      if (format.supportsPhotoHdr === filter.photoHdr.target) rightPoints += filter.photoHdr.priority
    }

    // Find Video HDR formats
    if (filter.videoHdr != null) {
      if (bestFormat.supportsVideoHdr === filter.videoHdr.target) leftPoints += filter.videoHdr.priority
      if (format.supportsVideoHdr === filter.videoHdr.target) rightPoints += filter.videoHdr.priority
    }

    // Find matching AF system
    if (filter.autoFocusSystem != null) {
      if (bestFormat.autoFocusSystem === filter.autoFocusSystem.target) leftPoints += filter.autoFocusSystem.priority
      if (format.autoFocusSystem === filter.autoFocusSystem.target) rightPoints += filter.autoFocusSystem.priority
    }

    // Find depth data
    if (filter.depth != null) {
      if (bestFormat.supportsDepthCapture === filter.depth.target) leftPoints += filter.depth.priority
      if (format.supportsDepthCapture === filter.depth.target) rightPoints += filter.depth.priority
    }

    if (rightPoints > leftPoints) bestFormat = format
  }

  return bestFormat
}
