//
//  AppDelegate.h
//  Requests
//
//  Created by caabernathy on 1/24/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Facebook.h"

@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate,FBSessionDelegate,FBDialogDelegate,FBRequestDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ViewController *viewController;

@property (nonatomic, retain) Facebook *facebook;

@property (nonatomic, retain) NSURL *openedURL;

@property (nonatomic, assign) BOOL appUsageCheckEnabled;

- (void) login;
- (void) logout;
- (void) sendRequest;

@end
