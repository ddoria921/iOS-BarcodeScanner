//
//  ScanViewController.h
//  Scan
//
//  Created by Darin Doria on 2/10/14.
//  Copyright (c) 2014 Darin Doria. All rights reserved.
//

#import <UIKit/UIKit.h>
@import AVFoundation;


@protocol ScannerViewControllerDelegate <NSObject>

- (void)didFindValidBarcode;
- (void)dismissScanViewController;

@end


@interface ScanViewController : UIViewController

@property (nonatomic, weak) id <ScannerViewControllerDelegate> delegate;

@end