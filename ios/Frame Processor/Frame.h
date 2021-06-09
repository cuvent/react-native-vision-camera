//
//  Frame.h
//  VisionCamera
//
//  Created by Marc Rousavy on 15.03.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>
#import <CoreMedia/CMSampleBuffer.h>
#import <UIKit/UIImage.h>

@interface Frame : NSObject {
  CMSampleBufferRef buffer;
  UIImageOrientation orientation;
}

- (instancetype) initWithBuffer:(CMSampleBufferRef)buffer orientation:(UIImageOrientation)orientation;

@property (nonatomic) CMSampleBufferRef buffer;
@property (nonatomic) UIImageOrientation orientation;

@end
