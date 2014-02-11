//
//  CaptureSessionManager.h
//  Scan
//
//  Created by Darin Doria on 2/10/14.
//  Copyright (c) 2014 Darin Doria. All rights reserved.
//

@import AVFoundation;

@interface CaptureSessionManager : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> {
    
}

@property (retain) AVCaptureVideoPreviewLayer *previewLayer;
@property (retain) AVCaptureSession *captureSession;
@property (retain) AVCaptureStillImageOutput *stillImageOutput;
@property (retain) AVCaptureDevice *device;
@property (nonatomic, retain) UIImage *stillImage;

- (void)setFlashMode:(AVCaptureFlashMode)mode;
- (void)setTorchMode:(AVCaptureTorchMode)mode;
- (void)addVideoPreviewLayer;
- (void)setupOutputs;
- (void)captureStillImage;
- (void)addVideoInputCamera;
- (void)destroySession;

@end
