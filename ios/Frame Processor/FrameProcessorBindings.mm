//
//  FrameProcessorBindings.mm
//  VisionCamera
//
//  Created by Marc Rousavy on 25.02.21.
//  Copyright © 2021 Facebook. All rights reserved.
//

#import "FrameProcessorBindings.h"

#import <React/RCTBridge.h>
#import <React/RCTBridge+Private.h>
#import <React/RCTUIManager.h>

#import <jsi/jsi.h>
#import "../JSI Utils/YeetJSIUtils.h"
#import "FrameProcessorDelegate.h"

#if __has_include("react_native_vision_camera-Swift.h")
#import "react_native_vision_camera-Swift.h"
#elif __has_include("VisionCamera-Swift.h")
#import "VisionCamera-Swift.h"
#else
#error Objective-C Generated Interface Header (VisionCamera-Swift.h) was not found!
#endif

using namespace facebook;

@implementation FrameProcessorBindings

+ (void) installFrameProcessorBindings:(RCTBridge*)bridge {
  RCTCxxBridge *cxxBridge = (RCTCxxBridge *)bridge;
  if (!cxxBridge.runtime) {
    return;
  }
  jsi::Runtime& jsiRuntime = *(jsi::Runtime*)cxxBridge.runtime;

  // setFrameProcessor(viewTag: number, frameProcessor: (frame: Frame) => void)
  auto setFrameProcessor = [&bridge](jsi::Runtime& runtime, const jsi::Value& thisValue, const jsi::Value* arguments, size_t count) -> jsi::Value {
    if (!arguments[0].isNumber()) throw jsi::JSError(runtime, "Camera::setFrameProcessor: First argument ('viewTag') must be a number!");
    if (!arguments[1].isObject()) throw jsi::JSError(runtime, "Camera::setFrameProcessor: Second argument ('frameProcessor') must be a function!");

    auto viewTag = arguments[0].asNumber();
    auto function = arguments[1].asObject(runtime).asFunction(runtime);

    auto anonymousView = [bridge.uiManager viewForReactTag:[NSNumber numberWithDouble:viewTag]];
    auto view = static_cast<CameraView*>(anonymousView);
    if (view.frameProcessorDelegate == nil) {
      view.frameProcessorDelegate = [[FrameProcessorDelegate alloc] init];
    }
    
    // TODO: I am pretty sure it is a _very_ bad idea to move the worklet to the stack and pass that pointer around.
    // alternative:  auto functionPointer = std::make_unique<jsi::Function>(std::move(function));
    auto functionPointer = new jsi::Function(std::move(function));
    [view.frameProcessorDelegate setFrameProcessorFunction:(void*)functionPointer];

    return jsi::Value::undefined();
  };
  jsiRuntime.global().setProperty(jsiRuntime, "setFrameProcessor", jsi::Function::createFromHostFunction(jsiRuntime,
                                                                                                         jsi::PropNameID::forAscii(jsiRuntime, "setFrameProcessor"),
                                                                                                         2,  // viewTag, frameProcessor
                                                                                                         setFrameProcessor));

  // unsetFrameProcessor(viewTag: number)
  auto unsetFrameProcessor = [&bridge](jsi::Runtime& runtime, const jsi::Value& thisValue, const jsi::Value* arguments, size_t count) -> jsi::Value {
    if (!arguments[0].isNumber()) throw jsi::JSError(runtime, "Camera::unsetFrameProcessor: First argument ('viewTag') must be a number!");
    auto viewTag = arguments[0].asNumber();

    auto anonymousView = [bridge.uiManager viewForReactTag:[NSNumber numberWithDouble:viewTag]];
    auto view = static_cast<CameraView*>(anonymousView);
    view.frameProcessorDelegate = nil;

    return jsi::Value::undefined();
  };
  jsiRuntime.global().setProperty(jsiRuntime, "unsetFrameProcessor", jsi::Function::createFromHostFunction(jsiRuntime,
                                                                                                           jsi::PropNameID::forAscii(jsiRuntime, "unsetFrameProcessor"),
                                                                                                           1,  // viewTag
                                                                                                           unsetFrameProcessor));
}

+ (void) uninstallFrameProcessorBindings {
  // TODO: Any cleanup?
}

@end