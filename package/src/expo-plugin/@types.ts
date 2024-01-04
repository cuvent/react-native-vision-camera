export type ConfigProps = {
  /**
   * The text to show in the native dialog when asking for Camera Permissions.
   * @default 'Allow $(PRODUCT_NAME) to access your camera'
   */
  cameraPermissionText?: string
  /**
   * Whether to add Microphone Permissions to the native manifest or not.
   * @default false
   */
  enableMicrophonePermission?: boolean
  /**
   * The text to show in the native dialog when asking for Camera Permissions.
   * @default 'Allow $(PRODUCT_NAME) to access your microphone'
   */
  microphonePermissionText?: string
  /**
   * Whether to enable the Frame Processors runtime, or explicitly disable it.
   * Disabling Frame Processors will make your app smaller as the C++ files will not be compiled.
   * See [Frame Processors](https://react-native-vision-camera.com/docs/guides/frame-processors)
   * @default false
   */
  disableFrameProcessors?: boolean
  /**
   * Whether to enable the QR/Barcode Scanner Model. If true, the MLKit Model will
   * automatically be downloaded on app startup. If false, it will be downloaded
   * once the Camera is created with a `CodeScanner`.
   * See [QR/Barcode Scanning](https://react-native-vision-camera.com/docs/guides/code-scanning)
   *
   * If set to true, it fallbacks to `android-manifest`.
   * @default false
   */
  enableCodeScanner?: boolean | 'android-manifest' | 'gradle-implementation'
};
