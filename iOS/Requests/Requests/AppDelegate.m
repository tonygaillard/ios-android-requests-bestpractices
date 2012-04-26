//
//  AppDelegate.m
//  Requests
//
//  Created by caabernathy on 1/24/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"

#import "ViewController.h"
#import "FBConnect.h"

static NSString *kAppId = @"264966473580049";
static const int kInviteTrigger = 50;

@implementation AppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;
@synthesize facebook;
@synthesize openedURL;
@synthesize appUsageCheckEnabled;

- (void)dealloc
{
    [facebook release];
    [_window release];
    [_viewController release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    // Override point for customization after application launch.
    self.viewController = [[[ViewController alloc] initWithNibName:@"ViewController" bundle:nil] autorelease];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    facebook = [[Facebook alloc] initWithAppId:kAppId 
                                   andDelegate:self];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"FBAccessTokenKey"] 
        && [defaults objectForKey:@"FBExpirationDateKey"]) {
        facebook.accessToken = [defaults objectForKey:@"FBAccessTokenKey"];
        facebook.expirationDate = [defaults objectForKey:@"FBExpirationDateKey"];
    }
    
    if ([facebook isSessionValid]) {
        [self fbDidLogin];
    } else {
        [self fbDidLogout];
    }

    // We will remember the user's setting if they do not wish to
    // send any more invites.
    self.appUsageCheckEnabled = YES;
    if ([defaults objectForKey:@"AppUsageCheck"]) {
        self.appUsageCheckEnabled = [defaults boolForKey:@"AppUsageCheck"];
    }
    // Hard code temporarily for simple requests testing
    //self.appUsageCheckEnabled = NO;
    
    return YES;
}


#pragma mark - Delegate methods called by View Controller
- (void) login {
    [facebook authorize:nil];
}

- (void) logout {
    [facebook logout];
}

- (void)sendRequest {
    SBJSON *jsonWriter = [[SBJSON new] autorelease];
    NSDictionary *gift = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"5", @"social_karma",
                          @"1", @"badge_of_awesomeness",
                          nil];
    
    NSString *giftStr = [jsonWriter stringWithObject:gift];
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   @"Learn how to make your iOS apps social.",  @"message",
                                   @"Check this out", @"notification_text",
                                   giftStr, @"data",
                                   nil];
    
    [facebook dialog:@"apprequests"
           andParams:params
         andDelegate:self];
}

#pragma mark - Helper methods
/**
 * A function for parsing URL parameters.
 */
- (NSDictionary*)parseURLParams:(NSString *)query {
	NSArray *pairs = [query componentsSeparatedByString:@"&"];
	NSMutableDictionary *params = [[[NSMutableDictionary alloc] init] autorelease];
	for (NSString *pair in pairs) {
		NSArray *kv = [pair componentsSeparatedByString:@"="];
		NSString *val =
        [[kv objectAtIndex:1]
         stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
		[params setObject:val forKey:[kv objectAtIndex:0]];
	}
    return params;
}

- (void)sendInvites {
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   @"Check out this awesome app.",  @"message",
                                   nil];
    
    [facebook dialog:@"apprequests"
           andParams:params
         andDelegate:self];
}

/*
 * This private method will be used to check the app
 * usage counter, update it as necessary, and return
 * back an indication on whether the user should be
 * shown the prompt to invite friends
 */
- (BOOL) checkAppUsageTrigger {
    // Initialize the app active count
    NSInteger appActiveCount = 0;
    // Read the stored value of the counter, if it exists
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"AppUsedCounter"]) {
        appActiveCount = [defaults integerForKey:@"AppUsedCounter"];
        
    }
    // Increment the counter
    appActiveCount++;
    BOOL trigger = NO;
    // Only trigger the prompt if the facebook session is valid and
    // the counter is greater than a defined value
    if ([facebook isSessionValid] && (appActiveCount >= kInviteTrigger)) {
        trigger = YES;
        appActiveCount = 0;
    }
    // Save the updated counter
    [defaults setInteger:appActiveCount forKey:@"AppUsedCounter"];
    [defaults synchronize];
    return trigger;
}

#pragma mark - Handle incoming URLs
// Pre 4.2 support
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    openedURL = url;
    return [facebook handleOpenURL:url]; 
}

// For 4.2+ support
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    openedURL = url;
    return [facebook handleOpenURL:url]; 
}

#pragma mark - FBSession delegate methods
// Implement session delegate methods
- (void)fbDidLogin {
    if (openedURL) {
        NSString *query = [openedURL fragment];
        NSDictionary *params = [self parseURLParams:query];
        // Check target URL exists
        NSString *targetURLString = [params valueForKey:@"target_url"];
        if (targetURLString) {
            NSURL *targetURL = [NSURL URLWithString:targetURLString];
            NSDictionary *targetParams = [self parseURLParams:[targetURL query]];
            NSString *ref = [targetParams valueForKey:@"ref"];
            // Check for the ref parameter to check if this is one of
            // our incoming notification
            if ([ref isEqualToString:@"notif"]) {
                NSString *requestIDParam = [targetParams objectForKey:@"request_ids"];
                NSArray *requestIDs = [requestIDParam componentsSeparatedByString:@","];
                
                // Process the first request id (there may be more than one)
                [facebook requestWithGraphPath:[requestIDs objectAtIndex:0] andDelegate:self];
            }
        }
    }
    self.viewController.welcomeLabel.text = @"Welcome ...";
    [self.viewController.authButton setTitle:@"Logout" forState:UIControlStateNormal];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[facebook accessToken] forKey:@"FBAccessTokenKey"];
    [defaults setObject:[facebook expirationDate] forKey:@"FBExpirationDateKey"];
    [defaults synchronize];
}

- (void)fbDidLogout {
    self.viewController.welcomeLabel.text = @"Login to continue";
    [self.viewController.authButton setTitle:@"Login" forState:UIControlStateNormal];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"FBAccessTokenKey"];
    [defaults removeObjectForKey:@"FBExpirationDateKey"];
    [defaults synchronize];
}

- (void)fbDidNotLogin:(BOOL)cancelled {
}

- (void)fbDidExtendToken:(NSString*)accessToken
               expiresAt:(NSDate*)expiresAt {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:accessToken forKey:@"FBAccessTokenKey"];
    [defaults setObject:expiresAt forKey:@"FBExpirationDateKey"];
    [defaults synchronize];
}


- (void)fbSessionInvalidated {
}

#pragma mark - FBDialog delegate methods
/**
 * Called when a UIServer Dialog successfully return. Using this callback
 * instead of dialogDidComplete: to properly handle successful shares/sends
 * that return ID data back.
 */
- (void)dialogCompleteWithUrl:(NSURL *)url {
    if (![url query]) {
        NSLog(@"User canceled dialog or there was an error");
        return;
    }
    
    NSDictionary *params = [self parseURLParams:[url query]];
    if ([params objectForKey:@"request"]) {
        // Successful requests are returned in the form:
        // request=1001316103543&to[0]=100003086810435&to[1]=100001482211095
        NSLog(@"Request ID: %@", [params objectForKey:@"request"]);
    }
}

#pragma mark - FBRequest delegate methods
- (void)request:(FBRequest *)request didLoad:(id)result {
    if ([result isKindOfClass:[NSArray class]] && ([result count] > 0)) {
        result = [result objectAtIndex:0];
    }
    NSString *title;
    NSString *message;
    if ([result objectForKey:@"data"]) {
        title = [NSString 
                 stringWithFormat:@"%@ sent you a gift",
                 [[result objectForKey:@"from"] objectForKey:@"name"]];
        SBJSON *jsonParser = [[SBJSON new] autorelease];
        NSDictionary *requestData = [jsonParser objectWithString:[result objectForKey:@"data"]];
        message = [NSString stringWithFormat:@"Badge: %@, Karma: %@",
                   [requestData objectForKey:@"badge_of_awesomeness"],
                   [requestData objectForKey:@"social_karma"]];
    } else {
        title = [NSString
                 stringWithFormat:@"%@ sent you a request",
                 [[result objectForKey:@"from"] objectForKey:@"name"]];
        message = [NSString stringWithString:[result objectForKey:@"message"]];
    }
    
    // Display the request data to the user
    UIAlertView *alert = [[UIAlertView alloc] 
                          initWithTitle:title 
                          message:message
                          delegate:nil 
                          cancelButtonTitle:@"OK" 
                          otherButtonTitles:nil, 
                          nil];
    [alert show];
    [alert release];
    
    // Delete the request
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   @"delete", @"method",nil];
    [facebook requestWithGraphPath:[result objectForKey:@"id"]
                         andParams:params
                       andDelegate:nil];
    
}

/**
 * Called when an error prevents the Facebook API request from completing
 * successfully.
 */
- (void)request:(FBRequest *)request didFailWithError:(NSError *)error {
    // Error could happen if the user clicks on a notification for the second time
    // while the notification is being deleted due to the first click
    NSLog(@"Error message: %@", [[error userInfo] objectForKey:@"error_msg"]);
}

- (void)request:(FBRequest *)request didReceiveResponse:(NSURLResponse *)response {
    NSLog(@"received response");
}

#pragma mark - UIAlertViewDelegate methods
/*
 * When the alert is dismissed check which button was clicked so
 * you can take appropriate action, such as displaying the request
 * dialog, or setting a flag not to prompt the user again.
 */
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        // User has clicked on the No Thanks button, do not ask again
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setBool:YES forKey:@"AppUsageCheck"];
        [defaults synchronize];
        self.appUsageCheckEnabled = NO;
    } else if (buttonIndex == 1) {
        // User has clicked on the Tell Friends button
        [self performSelector:@selector(sendInvites) withObject:nil afterDelay:0.5];
    }
}

#pragma mark -

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

/*
 * When the application becomes active we will check whether or not
 * we should prompt the user to invite friends.
 */
- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Check the flag for enabling any prompts. If that flag is on
    // check the app active counter
    if (self.appUsageCheckEnabled && [self checkAppUsageTrigger]) {
        // If the user should be prompter to invite friends, show
        // an alert with the choices.
        UIAlertView *alert = [[UIAlertView alloc] 
                              initWithTitle:@"Invite Friends" 
                              message:@"If you enjoy using this app, would you mind taking a moment to invite a few friends that you think will also like it?"
                              delegate:self 
                              cancelButtonTitle:@"No Thanks" 
                              otherButtonTitles:@"Tell Friends!", @"Remind Me Later", nil];
        [alert show];
        [alert release];
    }
    
    [facebook extendAccessTokenIfNeeded];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

@end
