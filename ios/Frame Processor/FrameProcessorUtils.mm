//
//  FrameProcessorUtils.m
//  VisionCamera
//
//  Created by Marc Rousavy on 15.03.21.
//  Copyright © 2021 Facebook. All rights reserved.
//

#import "FrameProcessorUtils.h"
#import <CoreMedia/CMSampleBuffer.h>
#import <chrono>
#import <memory>
#import "FrameHostObject.h"

FrameProcessorCallback convertJSIFunctionToFrameProcessorCallback(jsi::Runtime &runtime, const jsi::Function &value) {
  __block auto cb = value.getFunction(runtime);
  
  return ^(CMSampleBufferRef buffer) {
    NSLog(@"Calling Frame Processor...");
    std::chrono::steady_clock::time_point begin = std::chrono::steady_clock::now();
    
    auto frame = std::make_shared<FrameHostObject>(buffer);
    auto object = jsi::Object::createFromHostObject(runtime, frame);
    cb.callWithThis(runtime, cb, object);
    
    std::chrono::steady_clock::time_point end = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - begin);
    NSLog(@"Finished Frame Processor execution in %lld", duration.count());
    
    // Manually free the buffer because:
    //  1. we are sure we don't need it anymore, the frame processor worklet has finished executing.
    //  2. we don't know when the JS runtime garbage collects this object, it might be holding it for a few more frames
    //     which then blocks the camera queue from pushing new frames (memory limit)
    frame->destroyBuffer();
  };
}