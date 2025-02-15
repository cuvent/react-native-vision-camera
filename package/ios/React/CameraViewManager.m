//
//  CameraViewManager.m
//  mrousavy
//
//  Created by Marc Rousavy on 09.11.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <React/RCTUtils.h>
#import <React/RCTViewManager.h>

@interface RCT_EXTERN_REMAP_MODULE (CameraView, CameraViewManager, RCTViewManager)

// Module Functions
RCT_EXTERN__BLOCKING_SYNCHRONOUS_METHOD(getCameraPermissionStatus);
RCT_EXTERN__BLOCKING_SYNCHRONOUS_METHOD(getMicrophonePermissionStatus);
RCT_EXTERN__BLOCKING_SYNCHRONOUS_METHOD(getLocationPermissionStatus);
RCT_EXTERN_METHOD(requestCameraPermission : (RCTPromiseResolveBlock)resolve reject : (RCTPromiseRejectBlock)reject);
RCT_EXTERN_METHOD(requestMicrophonePermission : (RCTPromiseResolveBlock)resolve reject : (RCTPromiseRejectBlock)reject);
RCT_EXTERN_METHOD(requestLocationPermission : (RCTPromiseResolveBlock)resolve reject : (RCTPromiseRejectBlock)reject);

RCT_EXTERN__BLOCKING_SYNCHRONOUS_METHOD(installFrameProcessorBindings);

// Camera View Properties
RCT_EXPORT_VIEW_PROPERTY(isActive, BOOL);
RCT_EXPORT_VIEW_PROPERTY(enableIdleTimer, BOOL);
RCT_EXPORT_VIEW_PROPERTY(cameraId, NSString);
RCT_EXPORT_VIEW_PROPERTY(enableDepthData, BOOL);
RCT_EXPORT_VIEW_PROPERTY(enablePortraitEffectsMatteDelivery, BOOL);
RCT_EXPORT_VIEW_PROPERTY(enableBufferCompression, BOOL);
RCT_EXPORT_VIEW_PROPERTY(isMirrored, BOOL);
// use cases
RCT_EXPORT_VIEW_PROPERTY(preview, BOOL);
RCT_EXPORT_VIEW_PROPERTY(photo, BOOL);
RCT_EXPORT_VIEW_PROPERTY(video, BOOL);
RCT_EXPORT_VIEW_PROPERTY(audio, BOOL);
RCT_EXPORT_VIEW_PROPERTY(enableFrameProcessor, BOOL);
RCT_EXPORT_VIEW_PROPERTY(enableLocation, BOOL);
// device format
RCT_EXPORT_VIEW_PROPERTY(format, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(minFps, NSNumber);
RCT_EXPORT_VIEW_PROPERTY(maxFps, NSNumber);
RCT_EXPORT_VIEW_PROPERTY(videoHdr, BOOL);
RCT_EXPORT_VIEW_PROPERTY(photoHdr, BOOL);
RCT_EXPORT_VIEW_PROPERTY(photoQualityBalance, NSString);
RCT_EXPORT_VIEW_PROPERTY(lowLightBoost, BOOL);
RCT_EXPORT_VIEW_PROPERTY(videoStabilizationMode, NSString);
RCT_EXPORT_VIEW_PROPERTY(pixelFormat, NSString);
RCT_EXPORT_VIEW_PROPERTY(videoBitRateOverride, NSNumber);
RCT_EXPORT_VIEW_PROPERTY(videoBitRateMultiplier, NSNumber);
// other props
RCT_EXPORT_VIEW_PROPERTY(torch, NSString);
RCT_EXPORT_VIEW_PROPERTY(zoom, NSNumber);
RCT_EXPORT_VIEW_PROPERTY(exposure, NSNumber);
RCT_EXPORT_VIEW_PROPERTY(enableZoomGesture, BOOL);
RCT_EXPORT_VIEW_PROPERTY(outputOrientation, NSString);
RCT_EXPORT_VIEW_PROPERTY(resizeMode, NSString);
// Camera View Events
RCT_REMAP_VIEW_PROPERTY(onError, onErrorEvent, RCTDirectEventBlock);
RCT_REMAP_VIEW_PROPERTY(onInitialized, onInitializedEvent, RCTDirectEventBlock);
RCT_REMAP_VIEW_PROPERTY(onStarted, onStartedEvent, RCTDirectEventBlock);
RCT_REMAP_VIEW_PROPERTY(onStopped, onStoppedEvent, RCTDirectEventBlock);
RCT_REMAP_VIEW_PROPERTY(onPreviewStarted, onPreviewStartedEvent, RCTDirectEventBlock);
RCT_REMAP_VIEW_PROPERTY(onPreviewStopped, onPreviewStoppedEvent, RCTDirectEventBlock);
RCT_REMAP_VIEW_PROPERTY(onShutter, onShutterEvent, RCTDirectEventBlock);
RCT_REMAP_VIEW_PROPERTY(onOutputOrientationChanged, onOutputOrientationChangedEvent, RCTDirectEventBlock);
RCT_REMAP_VIEW_PROPERTY(onPreviewOrientationChanged, onPreviewOrientationChangedEvent, RCTDirectEventBlock);
RCT_REMAP_VIEW_PROPERTY(onViewReady, onViewReadyEvent, RCTDirectEventBlock);
RCT_REMAP_VIEW_PROPERTY(onAverageFpsChanged, onAverageFpsChangedEvent, RCTDirectEventBlock);
// Code Scanner
RCT_EXPORT_VIEW_PROPERTY(codeScannerOptions, NSDictionary);
RCT_REMAP_VIEW_PROPERTY(onCodeScanned, onCodeScannedEvent, RCTDirectEventBlock);

// Camera View Functions
RCT_EXTERN_METHOD(startRecording : (nonnull NSNumber*)node options : (NSDictionary*)options onRecordCallback : (RCTResponseSenderBlock)
                      onRecordCallback);
RCT_EXTERN_METHOD(pauseRecording : (nonnull NSNumber*)node resolve : (RCTPromiseResolveBlock)resolve reject : (RCTPromiseRejectBlock)
                      reject);
RCT_EXTERN_METHOD(cancelRecording : (nonnull NSNumber*)node resolve : (RCTPromiseResolveBlock)resolve reject : (RCTPromiseRejectBlock)
                      reject);
RCT_EXTERN_METHOD(resumeRecording : (nonnull NSNumber*)node resolve : (RCTPromiseResolveBlock)resolve reject : (RCTPromiseRejectBlock)
                      reject);
RCT_EXTERN_METHOD(stopRecording : (nonnull NSNumber*)node resolve : (RCTPromiseResolveBlock)resolve reject : (RCTPromiseRejectBlock)reject);
RCT_EXTERN_METHOD(takePhoto : (nonnull NSNumber*)node options : (NSDictionary*)options resolve : (RCTPromiseResolveBlock)
                      resolve reject : (RCTPromiseRejectBlock)reject);
RCT_EXTERN_METHOD(takeSnapshot : (nonnull NSNumber*)node options : (NSDictionary*)options resolve : (RCTPromiseResolveBlock)
                      resolve reject : (RCTPromiseRejectBlock)reject);
RCT_EXTERN_METHOD(focus : (nonnull NSNumber*)node point : (NSDictionary*)point resolve : (RCTPromiseResolveBlock)
                      resolve reject : (RCTPromiseRejectBlock)reject);

@end
