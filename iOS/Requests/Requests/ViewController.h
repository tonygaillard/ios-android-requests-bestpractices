//
//  ViewController.h
//  Requests
//
//  Created by caabernathy on 1/24/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (retain, nonatomic) IBOutlet UILabel *welcomeLabel;

@property (retain, nonatomic) IBOutlet UIButton *authButton;

- (IBAction)authButtonClicked:(id)sender;

- (IBAction)sendRequestClicked:(id)sender;

@end
