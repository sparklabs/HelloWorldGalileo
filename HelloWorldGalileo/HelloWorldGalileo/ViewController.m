//  Created by Chris Harding on 2/25/13.
//  Copyright (c) 2013 Chris Harding. All rights reserved.
//

#import "ViewController.h"
#import <GalileoControl/GalileoControl.h>


// note: observed problems:

//  1) When incrementTargetPosition... is called with waitUntilStationary: set to YES while another incrementTargetPosition call is still in progress,
//     the galileo transitions into an unrecoverable error state where it is no longer able to read byte from the bluetooth connection. :(

//  2) Sometimes the completionBlock for incrementTargetPosition:... is being called before the movement actually finishes.

//  3) Overflow error when rotationg around 360 degs. reproducible via accelerationBugTriggerAction:


@interface ViewController () <GCGalileoDelegate>
@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // Start waiting for Galileo to connect
    [self disableUI];
    [GCGalileo sharedGalileo].logLevel = GCLogLevelWarning;
    [GCGalileo sharedGalileo].delegate = self;
    [[GCGalileo sharedGalileo] waitForConnection];
}

- (void)viewDidUnload {
    [self setPanClockwiseButton:nil];
    [self setStatusLabel:nil];
    [self setTiltClockwiseButton:nil];
    [self setTiltAnticlockwiseButton:nil];
    [super viewDidUnload];
}

#pragma mark -
#pragma mark GalileoDelegate methods

- (void) galileoDidConnect
{
    [self enableUI];
    self.statusLabel.text = @"Galileo is connected";
    self.statusLabel.textColor = [UIColor blackColor];
}

- (void) enableUI
{
    [self.view setUserInteractionEnabled:YES];
}

- (void) galileoDidDisconnect
{
    [self disableUI];
    self.statusLabel.text = @"Galileo is not connected";
    self.statusLabel.textColor = [UIColor redColor];
    [[GCGalileo sharedGalileo] waitForConnection];
}

- (void) disableUI
{
    // note: not blocking the UI on purpose to stress test concurrent commands
    
//    [self.view setUserInteractionEnabled:NO];
}

#pragma mark -
#pragma mark Button handlers

-(BOOL)_waitFlag {
    // note: set this to YES to trigger problem 1)
    return NO;
}

-(dispatch_queue_t)_dispatchQ {
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//    return dispatch_get_main_queue();
}


- (IBAction)panClockwise:(id)sender {
    NSLog(@"panClockwise:");

    [self disableUI];
    NSDate *now = [NSDate date];
    void (^completionBlock) (BOOL) = ^(BOOL wasCommandPreempted)
    {
        [self controlDidReachTargetPosition:wasCommandPreempted commandIssuedDate:now];
    };
    
    dispatch_async([self _dispatchQ], ^{
        [[[GCGalileo sharedGalileo] positionControlForAxis:GCControlAxisPan] incrementTargetPosition:359.9 completionBlock:completionBlock waitUntilStationary:[self _waitFlag]];
    });
}

- (IBAction)panAnticlockwise:(id)sender {
    NSLog(@"panAnticlockwise:");

    [self disableUI];
    NSDate *now = [NSDate date];
    void (^completionBlock) (BOOL) = ^(BOOL wasCommandPreempted)
    {
        [self controlDidReachTargetPosition:wasCommandPreempted commandIssuedDate:now];
    };
    
    dispatch_async([self _dispatchQ], ^{
        [[[GCGalileo sharedGalileo] positionControlForAxis:GCControlAxisPan] incrementTargetPosition:-359.9 completionBlock:completionBlock waitUntilStationary:[self _waitFlag]];
    });
}

- (IBAction)tiltClockwise:(id)sender {
    NSLog(@"tiltClockwise:");
    
    [self disableUI];
    NSDate *now = [NSDate date];
    void (^completionBlock) (BOOL) = ^(BOOL wasCommandPreempted)
    {
        [self controlDidReachTargetPosition:wasCommandPreempted commandIssuedDate:now];
    };
    
    dispatch_async([self _dispatchQ], ^{
        [[[GCGalileo sharedGalileo] positionControlForAxis:GCControlAxisTilt] incrementTargetPosition:359.9 completionBlock:completionBlock waitUntilStationary:[self _waitFlag]];
    });
}

- (IBAction)tiltAnticlockwise:(id)sender {
    NSLog(@"tiltAnticlockwise:");

    [self disableUI];
    NSDate *now = [NSDate date];

    void (^completionBlock) (BOOL) = ^(BOOL wasCommandPreempted)
    {
        [self controlDidReachTargetPosition:wasCommandPreempted commandIssuedDate:now];
    };
    
    dispatch_async([self _dispatchQ], ^{
        GCPositionControl *tilt = [[GCGalileo sharedGalileo] positionControlForAxis:GCControlAxisTilt];
        [tilt setVelocity:tilt.maxVelocity*0.5];
        [tilt setAcceleration:tilt.maxAcceleration*0.5];
        NSLog(@"tiltAnticlockwise: tilt.minVelocity=%@  tilt.maxVelocity=%@  tilt.minAcceleration=%@  tilt.maxAcceleration=%@",
              @(tilt.minVelocity), @(tilt.maxVelocity), @(tilt.minAcceleration), @(tilt.maxAcceleration));
        [tilt incrementTargetPosition:-359.9 completionBlock:completionBlock waitUntilStationary:[self _waitFlag]];
    });
}


- (IBAction)accelerationBugTriggerAction:(id)sender {
    NSLog(@"accelerationBugTriggerAction:");
    
    [self disableUI];
    NSDate *now = [NSDate date];
    
    void (^completionBlock) (BOOL) = ^(BOOL wasCommandPreempted)
    {
        [self controlDidReachTargetPosition:wasCommandPreempted commandIssuedDate:now];
        
        if (sender != nil) {
            [self accelerationBugTriggerAction:nil];
        }
        
    };
    
    
    dispatch_async([self _dispatchQ], ^{
        GCPositionControl *tilt = [[GCGalileo sharedGalileo] positionControlForAxis:GCControlAxisTilt];
        [tilt setVelocity:tilt.maxVelocity*0.5];
        [tilt setAcceleration:tilt.maxAcceleration*0.5];
        
        NSLog(@"accelerationBugTriggerAction: tilt.minVelocity=%@  tilt.maxVelocity=%@  tilt.minAcceleration=%@  tilt.maxAcceleration=%@",
              @(tilt.minVelocity), @(tilt.maxVelocity), @(tilt.minAcceleration), @(tilt.maxAcceleration));
        [tilt incrementTargetPosition:-359.9 completionBlock:completionBlock waitUntilStationary:[self _waitFlag]];
        
        [tilt resetOriginToCurrentPosition];
    });
}


#pragma mark -
#pragma mark PositionControl delegate

- (void) controlDidReachTargetPosition:(BOOL)wasCommandPreempted commandIssuedDate:(NSDate*)commandIssuedDate
{
    NSDate *now = [NSDate date];
    NSTimeInterval commandExecTime = [now timeIntervalSinceDate:commandIssuedDate];
    NSLog(@"controlDidReachTargetPosition: wasCommandPreempted=?%i  commandExecTime=%f\n", wasCommandPreempted, commandExecTime);
    
    if (wasCommandPreempted == NO) {
        // Re-enable the UI now that the target has been reached, assuming we are still connected to Galileo
        if ([[GCGalileo sharedGalileo] isConnected]) {
            [self enableUI];
        }
    } else {
        
    }
    
}


@end
