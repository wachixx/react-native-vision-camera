//
//  CameraView+RecordVideo.swift
//  Cuvent
//
//  Created by Marc Rousavy on 16.12.20.
//  Copyright © 2020 Facebook. All rights reserved.
//

import AVFoundation

private var hasLoggedFrameDropWarning = false

// MARK: - CameraView + AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate

extension CameraView: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
  func startRecording(options: NSDictionary, callback: @escaping RCTResponseSenderBlock) {
    cameraQueue.async {
      do {
        let errorPointer = ErrorPointer(nilLiteral: ())
        guard let tempFilePath = RCTTempFilePath("mov", errorPointer) else {
          return callback([NSNull(), makeReactError(.capture(.createTempFileError), cause: errorPointer?.pointee)])
        }

        let tempURL = URL(string: "file://\(tempFilePath)")!
        if let flashMode = options["flash"] as? String {
          // use the torch as the video's flash
          self.setTorchMode(flashMode)
        }

        var fileType = AVFileType.mov
        if let fileTypeOption = options["fileType"] as? String {
          fileType = AVFileType(withString: fileTypeOption)
        }

        // TODO: The startRecording() func cannot be async because RN doesn't allow
        //       both a callback and a Promise in a single function. Wait for TurboModules?
        //       This means that any errors that occur in this function have to be delegated through
        //       the callback, but I'd prefer for them to throw for the original function instead.

        let onFinish = { (status: AVAssetWriter.Status, error: Error?) -> Void in
          ReactLogger.log(level: .info, message: "RecordingSession finished with status \(status.descriptor).")
          if let error = error {
            let description = (error as NSError).description
            return callback([NSNull(), CameraError.capture(.unknown(message: "An unknown recording error occured! \(description)"))])
          } else {
            if status == .completed {
              return callback([[
                "path": self.recordingSession!.url.absoluteString,
                "duration": self.recordingSession!.duration,
              ], NSNull()])
            } else {
              return callback([NSNull(), CameraError.unknown(message: "AVAssetWriter completed with status: \(status.descriptor)")])
            }
          }
        }

        let videoSettings = self.videoOutput!.recommendedVideoSettingsForAssetWriter(writingTo: fileType)
        let audioSettings = self.audioOutput!.recommendedAudioSettingsForAssetWriter(writingTo: fileType) as? [String: Any]
        self.recordingSession = try RecordingSession(url: tempURL,
                                                     fileType: fileType,
                                                     videoSettings: videoSettings ?? [:],
                                                     audioSettings: audioSettings ?? [:],
                                                     completion: onFinish)

        self.isRecording = true
      } catch let error as NSError {
        return callback([NSNull(), makeReactError(.capture(.createTempFileError), cause: error)])
      }
    }
  }

  func stopRecording(promise: Promise) {
    isRecording = false

    cameraQueue.async {
      withPromise(promise) {
        guard let recordingSession = self.recordingSession else {
          throw CameraError.capture(.noRecordingInProgress)
        }
        recordingSession.finish()
        return nil
      }
    }
  }

  func pauseRecording(promise: Promise) {
    cameraQueue.async {
      withPromise(promise) {
        if self.isRecording {
          self.isRecording = false
          return nil
        } else {
          throw CameraError.capture(.noRecordingInProgress)
        }
      }
    }
  }

  func resumeRecording(promise: Promise) {
    cameraQueue.async {
      withPromise(promise) {
        if !self.isRecording {
          self.isRecording = true
          return nil
        } else {
          throw CameraError.capture(.noRecordingInProgress)
        }
      }
    }
  }

  public func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
    if isRecording {
      guard let recordingSession = recordingSession else {
        return invokeOnError(.capture(.unknown(message: "isRecording was true but the RecordingSession was null!")))
      }
      let type: BufferType
      if let _ = captureOutput as? AVCaptureVideoDataOutput {
        type = .video
      } else if let _ = captureOutput as? AVCaptureAudioDataOutput {
        type = .audio
      } else {
        return invokeOnError(.capture(.unknown(message: "Received CMSampleBuffer from unknown AVCaptureOutput!")))
      }
      recordingSession.appendBuffer(sampleBuffer, type: type)
    }

    if let frameProcessor = frameProcessorCallback {
      // check if last frame was x nanoseconds ago, effectively throttling FPS
      let diff = DispatchTime.now().uptimeNanoseconds - lastFrameProcessorCall.uptimeNanoseconds
      let secondsPerFrame = 1.0 / frameProcessorFps.doubleValue
      let nanosecondsPerFrame = secondsPerFrame * 1_000_000_000.0
      if diff > UInt64(nanosecondsPerFrame) {
        frameProcessor(sampleBuffer)
        lastFrameProcessorCall = DispatchTime.now()
      }
    }
  }

  public func captureOutput(_: AVCaptureOutput, didDrop _: CMSampleBuffer, from _: AVCaptureConnection) {
    if frameProcessorCallback != nil && !hasLoggedFrameDropWarning {
      // TODO: Show in React console?
      ReactLogger.log(level: .warning, message: "Dropped a Frame. This might indicate that your Frame Processor is doing too much work. " +
        "Either throttle the frame processor's frame rate, or optimize your frame processor's execution speed.")
      hasLoggedFrameDropWarning = true
    }
  }
}
