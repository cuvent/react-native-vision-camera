export type PermissionError = 'permission/microphone-permission-denied' | 'permission/camera-permission-denied';
export type ParameterError =
  | 'parameter/invalid-parameter'
  | 'parameter/unsupported-os'
  | 'parameter/unsupported-output'
  | 'parameter/unsupported-input'
  | 'parameter/invalid-combination';
export type DeviceError =
  | 'device/configuration-error'
  | 'device/no-device'
  | 'device/invalid-device'
  | 'device/torch-unavailable'
  | 'device/microphone-unavailable'
  | 'device/low-light-boost-not-supported'
  | 'device/focus-not-supported'
  | 'device/camera-not-available-on-simulator';
export type FormatError =
  | 'format/invalid-fps'
  | 'format/invalid-hdr'
  | 'format/invalid-low-light-boost'
  | 'format/invalid-format'
  | 'format/invalid-color-space'
  | 'format/invalid-preset';
export type SessionError =
  | 'session/camera-not-ready'
  | 'session/audio-session-setup-failed'
  | 'session/audio-in-use-by-other-app'
  | 'audio-session-failed-to-activate';
export type CaptureError =
  | 'capture/invalid-photo-format'
  | 'capture/encoder-error'
  | 'capture/muxer-error'
  | 'capture/recording-in-progress'
  | 'capture/no-recording-in-progress'
  | 'capture/file-io-error'
  | 'capture/create-temp-file-error'
  | 'capture/create-recorder-error'
  | 'capture/invalid-photo-codec'
  | 'capture/not-bound-error'
  | 'capture/capture-type-not-supported'
  | 'capture/video-not-enabled'
  | 'capture/photo-not-enabled'
  | 'capture/aborted'
  | 'capture/unknown';
export type SystemError = 'system/no-camera-manager';
export type UnknownError = 'unknown/unknown';

/**
 * Represents a JSON-style error cause. This contains native `NSError`/`Throwable` information, and can have recursive {@linkcode ErrorWithCause.cause | .cause} properties until the ultimate cause has been found.
 */
export interface ErrorWithCause {
  /**
   * The native error's code.
   *
   * * iOS: `NSError.code`
   * * Android: N/A
   */
  code?: number;
  /**
   * The native error's domain.
   *
   * * iOS: `NSError.domain`
   * * Android: N/A
   */
  domain?: string;
  /**
   * The native error description
   *
   * * iOS: `NSError.message`
   * * Android: `Throwable.message`
   */
  message: string;
  /**
   * Optional additional details
   *
   * * iOS: `NSError.userInfo`
   * * Android: N/A
   */
  details?: Record<string, unknown>;
  /**
   * Optional Java stacktrace
   *
   * * iOS: N/A
   * * Android: `Throwable.stacktrace.toString()`
   */
  stacktrace?: string;
  /**
   * Optional additional cause for nested errors
   *
   * * iOS: N/A
   * * Android: `Throwable.cause`
   */
  cause?: ErrorWithCause;
}

type CameraErrorCode =
  | PermissionError
  | ParameterError
  | DeviceError
  | FormatError
  | SessionError
  | CaptureError
  | SystemError
  | UnknownError;

/**
 * Represents any kind of error that occured in the {@linkcode Camera} View Module.
 */
class CameraError<TCode extends CameraErrorCode> extends Error {
  private readonly _code: TCode;
  private readonly _message: string;
  private readonly _cause?: ErrorWithCause;

  public get code(): TCode {
    return this._code;
  }
  public get message(): string {
    return this._message;
  }
  public get cause(): ErrorWithCause | undefined {
    return this._cause;
  }

  /**
   * @internal
   */
  constructor(code: TCode, message: string, cause?: ErrorWithCause) {
    super(`[${code}]: ${message}${cause != null ? ` (Cause: ${cause.message})` : ''}`);
    super.name = code;
    super.message = message;
    this._code = code;
    this._message = message;
    this._cause = cause;
  }

  public toString(): string {
    return `[${this.code}]: ${this.message}`;
  }
}

/**
 * Represents any kind of error that occured while trying to capture a video or photo.
 *
 * See the ["Camera Errors" documentation](https://cuvent.github.io/react-native-vision-camera/docs/guides/errors) for more information about Camera Errors.
 */
export class CameraCaptureError extends CameraError<CaptureError> {}

/**
 * Represents any kind of error that occured in the Camera View Module.
 *
 * See the ["Camera Errors" documentation](https://cuvent.github.io/react-native-vision-camera/docs/guides/errors) for more information about Camera Errors.
 */
export class CameraRuntimeError extends CameraError<
  PermissionError | ParameterError | DeviceError | FormatError | SessionError | SystemError | UnknownError
> {}

/**
 * Checks if the given `error` is of type {@linkcode ErrorWithCause}
 * @param {unknown} error Any unknown object to validate
 * @returns `true` if the given `error` is of type {@linkcode ErrorWithCause}
 */
export const isErrorWithCause = (error: unknown): error is ErrorWithCause =>
  typeof error === 'object' &&
  error != null &&
  // @ts-expect-error error is still unknown
  typeof error.message === 'string' &&
  // @ts-expect-error error is still unknown
  (typeof error.stacktrace === 'string' || error.stacktrace == null) &&
  // @ts-expect-error error is still unknown
  (isErrorWithCause(error.cause) || error.cause == null);

const isCameraErrorJson = (error: unknown): error is { code: string; message: string; cause?: ErrorWithCause } =>
  typeof error === 'object' &&
  error != null &&
  // @ts-expect-error error is still unknown
  typeof error.code === 'string' &&
  // @ts-expect-error error is still unknown
  typeof error.message === 'string' &&
  // @ts-expect-error error is still unknown
  (typeof error.cause === 'object' || error.cause == null);

/**
 * Tries to parse an error coming from native to a typed JS camera error.
 * @param {CameraError} nativeError The native error instance. This is a JSON in the legacy native module architecture.
 * @returns A {@linkcode CameraRuntimeError} or {@linkcode CameraCaptureError}, or the `nativeError` itself if it's not parsable
 * @method
 */
export const tryParseNativeCameraError = <T>(nativeError: T): (CameraRuntimeError | CameraCaptureError) | T => {
  if (isCameraErrorJson(nativeError)) {
    if (nativeError.code.startsWith('capture')) {
      return new CameraCaptureError(nativeError.code as CaptureError, nativeError.message, nativeError.cause);
    } else {
      return new CameraRuntimeError(
        // @ts-expect-error the code is string, we narrow it down to TS union.
        nativeError.code,
        nativeError.message,
        nativeError.cause,
      );
    }
  } else {
    return nativeError;
  }
};
