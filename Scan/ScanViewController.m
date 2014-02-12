//
//  ScanViewController.m
//  Scan
//
//  Created by Darin Doria on 2/10/14.
//  Copyright (c) 2014 Darin Doria. All rights reserved.
//

#import "ScanViewController.h"
#import "DDExpandableButton.h"
#import "CaptureSessionManager.h"
#import "CSAnimationView.h"

#define kSPSightWalkCaptureOverlayAlpha 0.7
#define kSPSightWalkFooterViewHeight    100.0
#define kSPSightWalkHeaderViewHeight    40.0
#define kSPScannerTargetWidth           201.0
#define kSPScannerTargetHeight          200.0
#define kSPSightWalkThumbnailSize       CGSizeMake(230, 90)


@interface ScanViewController () <AVCaptureMetadataOutputObjectsDelegate, UIGestureRecognizerDelegate>
{
    NSString    *_decodedMessage;
    BOOL        _didFindBarcode;
    BOOL        _shouldSaveAssigmnent;
    BOOL        _scanning;
}

@property (nonatomic, readwrite) BOOL isBarcodeValid;

// Properties
@property (nonatomic, strong)   UIButton *doneButton;

@property (nonatomic, weak)     UIView *torchAndDoneHeaderView;
@property (nonatomic, strong)   UITapGestureRecognizer *tapRecognizer;
@property (nonatomic, weak)     UIView *footerOverlay;
@property (nonatomic, weak)     UILabel *messageToUser;
@property (strong, nonatomic)   UIImageView *scanCrosshairs;
@property (nonatomic)           dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.

@property (nonatomic, strong)   DDExpandableButton *torchModeButton;
@property (nonatomic, strong)   CaptureSessionManager *captureManager;
@property (strong, nonatomic)   CSAnimationView *animationView;
@end

@implementation ScanViewController


#pragma mark - Lifecycle

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    [self setCaptureManager:[[CaptureSessionManager alloc] init]];
    [[self captureManager] addVideoPreviewLayer];
    
    [self.view.layer insertSublayer:self.captureManager.previewLayer atIndex:0];
    
    // create an AVCapture session
    self.captureManager.captureSession = [[AVCaptureSession alloc] init];
    
    // add the main camera as an input to the session
    self.captureManager.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
    
    // input is created from AVCaptureDevice object
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:_captureManager.device error:&error];
    
    // check that input was succesfully inititialized
    if (input) {
        [_captureManager.captureSession addInput:input];
    } else {
        [self createEntireViewOverlay];
        NSLog(@"Input varibale returned nil. \nerror: %@", error);
        return;
    }
    
    // layer that shows the video on the screen
    _captureManager.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureManager.captureSession];
    _captureManager.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _captureManager.previewLayer.bounds = self.view.bounds;
    _captureManager.previewLayer.position = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
    [self.view.layer addSublayer:_captureManager.previewLayer];
    
    // Dispatch the rest of session setup to the sessionQueue so that the main queue isn't blocked.
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    [self setSessionQueue:sessionQueue];
    
    // create object to capture the metadata from the video
    AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
    
    // restricting are to scan. In metadata coordinates.
    output.rectOfInterest = CGRectMake(0.25, 0, 0.4, 1);
    
    // set where to put the metadata from the video
    [_captureManager.captureSession addOutput:output];
    
    // set it to look for only QR Codes
    [output setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]];
    NSLog(@"Searching for %@\n\n", [[output metadataObjectTypes] objectAtIndex:0]);
    
    // This VC is the delegate. Please call us on the main queue
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    
    // create view over preview layer
    [self createEntireViewOverlay];
    
    self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToFocus:)];
    _tapRecognizer.delegate = self;
    _tapRecognizer.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:self.tapRecognizer];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        dispatch_async([self sessionQueue], ^{
            [_captureManager.captureSession startRunning];
        });
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
	if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        dispatch_async([self sessionQueue], ^{
            [_captureManager.captureSession stopRunning];
        });
    }
}


- (IBAction)dismissScreen:(UIButton *)sender {
    _shouldSaveAssigmnent = NO;
    [self.delegate dismissScanViewController];
}

#pragma mark - Scanner Crosshairs

- (void)createScannerCrosshairs
{
    // setting up animation view
    _animationView = [[CSAnimationView alloc] init];
    [_animationView setBackgroundColor:[UIColor clearColor]];
    
    _animationView.delay = 0;
    _animationView.duration = 0.4;
    _animationView.pauseAnimationOnAwake = YES;
    [self.view addSubview:_animationView];
    
    
    CGFloat scanningViewHeight = self.view.bounds.size.height - kSPSightWalkHeaderViewHeight - kSPSightWalkFooterViewHeight;
    CGFloat scanningViewWidth = self.view.bounds.size.width;
    
    CGFloat scannerTargetYAxis = (scanningViewHeight / 2.0) - (kSPScannerTargetHeight / 2.0) + kSPSightWalkHeaderViewHeight;
    CGFloat scannerTargetXAxis = (scanningViewWidth / 2.0) - (kSPScannerTargetWidth / 2);
    
    _scanCrosshairs = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ScanCrosshairs"]];
    [_scanCrosshairs setFrame:CGRectMake(scannerTargetXAxis, scannerTargetYAxis, kSPScannerTargetWidth, kSPScannerTargetHeight)];
    
    _scanCrosshairs.contentMode = UIViewContentModeScaleToFill;
    
    [_animationView addSubview:_scanCrosshairs];
    [_animationView bringSubviewToFront:_scanCrosshairs];
    [self.view bringSubviewToFront:_animationView];
}


#pragma mark - Header and Footer Overlay

- (void)createEntireViewOverlay
{
    [self createFooterOverlay];
    [self createTorchAndDoneHeader];
    [self createTorchModeButton];
    [self createDoneButton];
    [self createScannerCrosshairs];
    [self createMessageToUser];
}

- (void)createFooterOverlay
{
    CGFloat vOffset = self.view.bounds.size.height - kSPSightWalkFooterViewHeight;
    NSLog(@"vOffset: %f", vOffset);
    UIView * footerOverlay = [[UIView alloc] initWithFrame:CGRectMake(0, vOffset, self.view.bounds.size.width, kSPSightWalkFooterViewHeight)];
    footerOverlay.backgroundColor = [UIColor blackColor];
    footerOverlay.alpha = kSPSightWalkCaptureOverlayAlpha;
    
    [self.view addSubview:footerOverlay];
    self.footerOverlay = footerOverlay;
    [self.view bringSubviewToFront:self.footerOverlay];
    
    
    UILabel *messageToUser = [[UILabel alloc] init];
    self.messageToUser = messageToUser;
    [footerOverlay addSubview:self.messageToUser];
    [footerOverlay bringSubviewToFront:self.messageToUser];
    [self.view bringSubviewToFront:footerOverlay];
}

- (void)createMessageToUser
{
    UILabel *userLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 100)];
    userLabel.text = @"Center code to scan";
    userLabel.textColor = [UIColor whiteColor];
    userLabel.textAlignment = NSTextAlignmentCenter;
    userLabel.font = [[UIFont preferredFontForTextStyle: UIFontTextStyleFootnote] fontWithSize:22.0];
    
    [self.footerOverlay addSubview:userLabel];
    self.messageToUser = userLabel;
}

- (void)createTorchAndDoneHeader
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, kSPSightWalkHeaderViewHeight)];
    NSLog(@"%f", self.view.bounds.size.width);
    view.backgroundColor = [UIColor blackColor];
    view.alpha = kSPSightWalkCaptureOverlayAlpha;
    [self.view addSubview:view];
    self.torchAndDoneHeaderView = view;
}

- (void)createTorchModeButton
{
    if (_torchModeButton)
    {
        [self removeTorchModeButton];
    }
    self.torchModeButton = [[DDExpandableButton alloc] initWithPoint:CGPointMake(0.0f, 4.0f)
                                                           leftTitle:[UIImage imageNamed:@"Flash.png"]
                                                             buttons:[NSArray arrayWithObjects:@"Off", @"On", nil]];
    [_torchModeButton setToggleMode:YES];
	[self.torchAndDoneHeaderView addSubview:self.torchModeButton];
	[_torchModeButton addTarget:self action:@selector(toggleFlashlight:) forControlEvents:UIControlEventValueChanged];
	[_torchModeButton setVerticalPadding:6];
	[_torchModeButton updateDisplay];
	[_torchModeButton setSelectedItem:0];
    NSLog(@"Created button");
}

- (void)removeTorchModeButton
{
    if (_torchModeButton.superview)
    {
        [self.torchModeButton removeFromSuperview];
        self.torchModeButton = nil;
    }
}

- (void)toggleFlashlight:(id)sender
{
    [self.captureManager setFlashMode:(2 - _torchModeButton.selectedItem)];
    [self.captureManager setTorchMode:(2 - _torchModeButton.selectedItem)];
    NSLog(@"Tapped light");
}

- (void)createDoneButton
{
    self.doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.doneButton.frame = CGRectMake(280, 0, 40, 40);
    [self.doneButton setImage:[UIImage imageNamed:@"GridCloseButton"] forState:UIControlStateNormal];
    [self.doneButton addTarget:self action:@selector(dismissScreen:) forControlEvents:UIControlEventTouchUpInside];
	[self.torchAndDoneHeaderView addSubview:self.doneButton];
	[_doneButton addTarget:self action:@selector(dismissScreen:) forControlEvents:UIControlEventValueChanged];
}


#pragma mark - AVCaptureMetadata Delegate Method

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (_didFindBarcode || _scanning) {
        return;
    }
    
    for (AVMetadataObject *metadata in metadataObjects) {
        if ([metadata.type isEqualToString:AVMetadataObjectTypeQRCode]) {
            
            // Transform the metadata coordinates to screen coordinates
            AVMetadataMachineReadableCodeObject *transformed = (AVMetadataMachineReadableCodeObject *)[_captureManager.previewLayer transformedMetadataObjectForMetadataObject:metadata];
            
            _decodedMessage = [transformed stringValue];
            
            UIApplication *myApplication = [UIApplication sharedApplication];
            NSURL *url = [NSURL URLWithString:_decodedMessage];
            
            if ([myApplication canOpenURL:url]) {
                [myApplication openURL:url];
                return;
            }
            
            // If a valid barcode was found
            if ([_decodedMessage isEqualToString:@"valid key"]) {
                /*
                 Change image to green and flash. Make flash not so fast and obvious.
                 Stop scanning for barcodes.
                 Exit scanner after 1.5 seconds.
                 */
                
                _shouldSaveAssigmnent = YES;
                _didFindBarcode = YES;
                
                
                //run any updates to the UI on the main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_scanCrosshairs setImage:[UIImage imageNamed:@"ScanCrosshairsValid"]];
                    _animationView.type = @"flash";
                    
                    [_animationView startCanvasAnimation];
                });
                
                double delayInSeconds = 1.0;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [self.delegate didFindValidBarcode];
                });
                
            } else {
                /*
                 Change image to red and perform a quick shake.
                 Delay from scanning until animation is over.
                 Start scanning again.
                 */
                
                _animationView.type = @"shake";
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [_scanCrosshairs setImage:[UIImage imageNamed:@"ScanCrosshairsInvalid"]];
                    
                    if (UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation])) {
                        [self AnimateShakeInLandscapeWithView:_animationView];
                        
                    } else {
                        [_animationView startCanvasAnimation];
                    }
                    
                    [_messageToUser setText:@"Incorrect code"];
                    
                });
                
                // set flags
                _didFindBarcode = NO;
                _scanning = YES;
                
                double delayInSeconds = 1.3;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    
                    
                    
                    //animate back to gray
                    [UIView transitionWithView:_scanCrosshairs
                                      duration:0.3f
                                       options:UIViewAnimationOptionTransitionCrossDissolve
                                    animations:^{
                                        // what do you want to animate?
                                        [_scanCrosshairs setImage:[UIImage imageNamed:@"ScanCrosshairs"]];
                                        [UIView transitionWithView:_messageToUser
                                                          duration:0.3f
                                                           options:UIViewAnimationOptionTransitionCurlDown
                                                        animations:^{ [_messageToUser setText:@"Center code to scan"]; }
                                                        completion:nil];
                                    }
                                    completion:^(BOOL finished) {
                                        //restart scanning
                                        _scanning = NO;}];
                });
            }
            
            NSLog(@"Found: %@\n", _decodedMessage);
        }
    }
}

#pragma Animation

- (void)AnimateShakeInLandscapeWithView: (UIView *)view
{
    double duration = 0.4;
    double delay = 0;
    // Start
    view.transform = CGAffineTransformMakeTranslation(0, 0);
    [UIView animateKeyframesWithDuration:duration/5 delay:delay options:0 animations:^{
        // End
        view.transform = CGAffineTransformMakeTranslation(0, 30);
    } completion:^(BOOL finished) {
        [UIView animateKeyframesWithDuration:duration/5 delay:0 options:0 animations:^{
            // End
            view.transform = CGAffineTransformMakeTranslation(0, -30);
        } completion:^(BOOL finished) {
            [UIView animateKeyframesWithDuration:duration/5 delay:0 options:0 animations:^{
                // End
                view.transform = CGAffineTransformMakeTranslation(0, 15);
            } completion:^(BOOL finished) {
                [UIView animateKeyframesWithDuration:duration/5 delay:0 options:0 animations:^{
                    // End
                    view.transform = CGAffineTransformMakeTranslation(0, -15);
                } completion:^(BOOL finished) {
                    [UIView animateKeyframesWithDuration:duration/5 delay:0 options:0 animations:^{
                        // End
                        view.transform = CGAffineTransformMakeTranslation(0, 0);
                    } completion:^(BOOL finished) {
                        // End
                    }];
                }];
            }];
        }];
    }];
}


#pragma mark - Tap To Focus

- (void)tapToFocus:(UITapGestureRecognizer *)sender
{
    CGPoint point = [sender locationInView:self.view];
    
    if ([self gestureRecognizerShouldBegin:sender])
    {
        if (sender.state == UIGestureRecognizerStateEnded) {
            [self focusAtPoint:[self convertToPointOfInterestFromViewCoordinates:point]];
        }
    }
}

- (void)focusAtPoint:(CGPoint)point
{
    
    AVCaptureDevice *device = [[self captureManager] device];
    
    NSError *error;
    
    [device lockForConfiguration:&error];
    
    if (!error) {
        
        if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus] &&
            [device isFocusPointOfInterestSupported])
        {
            [device setFocusPointOfInterest:point];
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
        } else {
            NSLog(@"Focur Error: %@", error);
        }
        
        if (device.exposurePointOfInterestSupported) {
            [device setExposurePointOfInterest:point];
            
            if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
                [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        }
    }
    
    [device unlockForConfiguration];
}

- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates
{
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = self.captureManager.previewLayer.frame.size;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = self.captureManager.previewLayer;
    
    AVCaptureInputPort* inputPort = nil;
    for (AVCaptureConnection *connection in self.captureManager.stillImageOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                inputPort = port;
                break;
            }
        }
    }
    
    if ([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize])
    {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    }
    else
    {
        CGRect cleanAperture;
        if (inputPort)
        {
            if ([inputPort mediaType] == AVMediaTypeVideo)
            {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([inputPort formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if ( [[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspect] ) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if (point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if (point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if ([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                    
                }
                
                pointOfInterest = CGPointMake(xc, yc);
            }
        }
    }
    
    return pointOfInterest;
}


#pragma mark - UIGestureRecognizer Delegate Method

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint point = [gestureRecognizer locationInView:self.view];
    
    if (CGRectContainsPoint(self.torchAndDoneHeaderView.bounds, point)) {
        return NO;
    }
    
    return YES;
}


#pragma mark - DPExpandable Button Protocol

- (CGSize)defaultFrameSize
{
    return kSPSightWalkThumbnailSize;
}

#pragma mark - Preferences

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}
@end