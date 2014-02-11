//
//  CaptureSessionManager.m
//  Scan
//
//  Created by Darin Doria on 2/10/14.
//  Copyright (c) 2014 Darin Doria. All rights reserved.
//

#import "CaptureSessionManager.h"
#import <ImageIO/ImageIO.h>

@interface CaptureSessionManager()

@property (strong, nonatomic) AVCaptureVideoDataOutput *videoDataOutput;

@end

@implementation CaptureSessionManager

@synthesize captureSession;
@synthesize previewLayer;
@synthesize stillImageOutput;
@synthesize stillImage;

#pragma mark Capture Session Configuration

- (id)init
{
	if ((self = [super init]))
    {
		self.captureSession = [[AVCaptureSession alloc] init];
        [self addVideoInputCamera];
        [self setupOutputs];
	}
	return self;
}

- (void)addVideoPreviewLayer
{
	[self setPreviewLayer:[[AVCaptureVideoPreviewLayer alloc] initWithSession:[self captureSession]]];
	[[self previewLayer] setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
}

- (void)setTorchMode:(AVCaptureTorchMode)mode
{
    if ([_device hasTorch])
    {
        if ([_device lockForConfiguration:nil])
        {
            if ([_device isTorchModeSupported:mode])
            {
                [_device setTorchMode:mode];
            }
            [_device unlockForConfiguration];
        }
    }
}

- (void)setFlashMode:(AVCaptureFlashMode)mode
{
    if ([_device hasFlash])
    {
        if ([_device lockForConfiguration:nil])
        {
            if ([_device isFlashModeSupported:mode])
            {
                [_device setFlashMode:mode];
            }
            [_device unlockForConfiguration];
        }
    }
}

- (void)addVideoInputCamera
{
    NSArray *devices = [AVCaptureDevice devices];
    
    for (AVCaptureDevice *device in devices)
    {
        if ([device hasMediaType:AVMediaTypeVideo])
        {
            if ([device position] == AVCaptureDevicePositionBack)
            {
                self.device = device;
            }
        }
    }
    
    NSError *error = nil;
    
    AVCaptureDeviceInput *backFacingCameraDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:&error];
    if (!error)
    {
        if ([[self captureSession] canAddInput:backFacingCameraDeviceInput])
        {
            [[self captureSession] addInput:backFacingCameraDeviceInput];
        }
        else
        {
            NSLog(@"Couldn't add back facing video input");
        }
    }
    
    [self setFlashMode:AVCaptureFlashModeAuto];
    [self setTorchMode:AVCaptureTorchModeAuto];
    
    NSError *exposureError = nil;
    
    [self.device lockForConfiguration:&exposureError];
    if (self.device.lowLightBoostSupported)
    {
        [self.device setAutomaticallyEnablesLowLightBoostWhenAvailable:YES];
    }
    if (exposureError == nil
        && [self.device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]
        && self.device.exposurePointOfInterestSupported)
    {
        CGPoint exposurePoint = CGPointMake(0.5f, 0.5f);
        [self.device setExposurePointOfInterest:exposurePoint];
        [self.device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    }
    
    [self.device unlockForConfiguration];
}

- (void)setupOutputs
{
    [self.captureSession beginConfiguration];
    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
    [self setStillImageOutput:[[AVCaptureStillImageOutput alloc] init]];
    [[self captureSession] addOutput:[self stillImageOutput]];
    [self.captureSession commitConfiguration];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
}

- (void)captureStillImage
{
	AVCaptureConnection *videoConnection = nil;
	for (AVCaptureConnection *connection in [[self stillImageOutput] connections]) {
		for (AVCaptureInputPort *port in [connection inputPorts]) {
			if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
				videoConnection = connection;
				break;
			}
		}
		if (videoConnection) {
            break;
        }
	}
    
    __weak CaptureSessionManager *captureManager = self;
    
    //	NSLog(@"about to request a capture from: %@", [self stillImageOutput]);
	[[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:videoConnection
                                                         completionHandler:^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
                                                             CFDictionaryRef exifAttachments = CMGetAttachment(imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
                                                             if (exifAttachments)
                                                             {
                                                                 NSLog(@"attachments: %@", exifAttachments);
                                                             }
                                                             else
                                                             {
                                                                 NSLog(@"no attachments");
                                                             }
                                                             NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
                                                             UIImage *image = [[UIImage alloc] initWithData:imageData];
                                                             
                                                             [captureManager setStillImage:image];
//                                                             dispatch_async(dispatch_get_main_queue(), ^{
//                                                                 [[NSNotificationCenter defaultCenter] postNotificationName:kImageCapturedSuccessfully object:nil];
//                                                             });
                                                         }];
}

- (void) destroySession
{
    // cleanup
    [self.captureSession stopRunning];
    [self.previewLayer removeFromSuperlayer];
    
    for (AVCaptureInput *input in self.captureSession.inputs) {
        
        [self.captureSession removeInput:input];
    }
    
    for (AVCaptureOutput *output in self.captureSession.outputs) {
        
        [self.captureSession removeOutput:output];
    }
    
    self.captureSession = nil;
}

- (void)dealloc
{
    NSLog(@"CaptureSessionManager deallocated");
}

@end
