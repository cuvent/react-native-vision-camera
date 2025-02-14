//
//  Frame.m
//  VisionCamera
//
//  Created by Marc Rousavy on 08.06.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

#import "Frame.h"
#import <CoreMedia/CMSampleBuffer.h>
#import <Foundation/Foundation.h>

@implementation Frame {
  CMSampleBufferRef _Nonnull _buffer;
  UIImageOrientation _orientation;
  BOOL _isMirrored;
  AVDepthData* _Nullable _depth;
}

- (instancetype)initWithBuffer:(CMSampleBufferRef)buffer
                   orientation:(UIImageOrientation)orientation
                    isMirrored:(BOOL)isMirrored
                     depthData:(nullable AVDepthData*)depth {
  self = [super init];
  if (self) {
    _buffer = buffer;
    _orientation = orientation;
    _isMirrored = isMirrored;
    _depth = depth;
  }
  return self;
}

- (void)incrementRefCount {
  CFRetain(_buffer);
  if (_depth) {
    CFRetain(_depth);
  }
}

- (void)decrementRefCount {
  CFRelease(_buffer);
  if (_depth) {
    CFRelease(_depth);
  }
}

- (CMSampleBufferRef)buffer {
  if (!self.isValid) {
    @throw [[NSException alloc] initWithName:@"capture/frame-invalid"
                                      reason:@"Trying to access an already closed Frame! "
                                              "Are you trying to access the Image data outside of a Frame Processor's lifetime?\n"
                                              "- If you want to use `console.log(frame)`, use `console.log(frame.toString())` instead.\n"
                                              "- If you want to do async processing, use `runAsync(...)` instead.\n"
                                              "- If you want to use runOnJS, increment it's ref-count: `frame.incrementRefCount()`"
                                    userInfo:nil];
  }
  return _buffer;
}

- (nullable AVDepthData*)depth {
  return _depth;
}

- (BOOL)isValid {
  return _buffer != nil && CFGetRetainCount(_buffer) > 0 && CMSampleBufferIsValid(_buffer);
}

- (UIImageOrientation)orientation {
  return _orientation;
}

- (NSString*)pixelFormat {
  CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(self.buffer);
  FourCharCode mediaType = CMFormatDescriptionGetMediaSubType(format);
  switch (mediaType) {
    case kCVPixelFormatType_32BGRA:
    case kCVPixelFormatType_Lossy_32BGRA:
      return @"rgb";
    case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
    case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
    case kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
    case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
    case kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarFullRange:
    case kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarVideoRange:
    case kCVPixelFormatType_Lossy_420YpCbCr10PackedBiPlanarVideoRange:
      return @"yuv";
    default:
      return @"unknown";
  }
}

- (BOOL)isMirrored {
  return _isMirrored;
}

- (size_t)width {
  CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(self.buffer);
  return CVPixelBufferGetWidth(imageBuffer);
}

- (size_t)height {
  CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(self.buffer);
  return CVPixelBufferGetHeight(imageBuffer);
}

- (double)timestamp {
  CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(self.buffer);
  return CMTimeGetSeconds(timestamp) * 1000.0;
}

- (size_t)bytesPerRow {
  CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(self.buffer);
  return CVPixelBufferGetBytesPerRow(imageBuffer);
}

- (size_t)planesCount {
  CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(self.buffer);
  return CVPixelBufferGetPlaneCount(imageBuffer);
}

@end
