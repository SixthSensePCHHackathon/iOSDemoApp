//
//  HFCommander.m
//  SixthSense
//
//  Created by Samuel Parkinson on 17/10/2015.
//  Copyright © 2015 mettle-studio. All rights reserved.
//

#import "HFCommander.h"

@implementation HFCommander

NSTimer *onRouteTimer;

+ (HFCommander *)sharedCommander {
    static HFCommander *sharedHFCommander = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedHFCommander = [[self alloc] init];
    });
    return sharedHFCommander;
}

- (HFCommander *)init {
    if (self = [super init]) {
        bleShield = [[BLE alloc] init];
        [bleShield controlSetup];
        bleShield.delegate = self;
        [self BLEShieldScan];
    }
    
    return self;
}

-(void) connectionTimer:(NSTimer *)timer
{
    if(bleShield.peripherals.count > 0)
    {
        [bleShield connectPeripheral:[bleShield.peripherals objectAtIndex:0]];
    }
    else
    {
        [self BLEShieldScan];
    }
}

- (void)BLEShieldScan
{
    if (bleShield.activePeripheral)
        if(bleShield.activePeripheral.state == CBPeripheralStateConnected)
        {
            [[bleShield CM] cancelPeripheralConnection:[bleShield activePeripheral]];
            return;
        }
    
    if (bleShield.peripherals)
        bleShield.peripherals = nil;
    
    [bleShield findBLEPeripherals:3];
    [NSTimer scheduledTimerWithTimeInterval:(float)3.0 target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO];
}

NSTimer *rssiTimer;

-(void) readRSSITimer:(NSTimer *)timer
{
    [bleShield readRSSI];
}

- (void) bleDidDisconnect
{
    NSLog(@"bleDidDisconnect");
    [self BLEShieldScan];
}

-(void) bleDidConnect
{
    NSLog(@"bleDidConnect");
    [self sendContinueStraight];
}

-(void) setOnRoute {
    if (!onRouteTimer)
        onRouteTimer = [NSTimer scheduledTimerWithTimeInterval:(float)1.0 target:self selector:@selector(sendOnRoute) userInfo:nil repeats:YES];
}

- (void) unsetOnRoute {
    [onRouteTimer invalidate];
    onRouteTimer = nil;
}

-(void) sendOnRoute {
    [self sendContinueStraight];
}

-(void) sendContinueStraight {
    if (bleShield.activePeripheral.state == CBPeripheralStateConnected) {
        [bleShield write:[@"H50" dataUsingEncoding:NSUTF8StringEncoding]];
    }
}

-(void) sendTurnLeft {
    [NSTimer scheduledTimerWithTimeInterval:(float)0.5 target:self selector:@selector(sendFirstSignal) userInfo:nil repeats:NO];
}

-(void) sendFirstSignal {
    if (bleShield.activePeripheral.state == CBPeripheralStateConnected) {
        [bleShield write:[@"H014" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [NSTimer scheduledTimerWithTimeInterval:(float)0.5 target:self selector:@selector(sendLastSignal) userInfo:nil repeats:NO];
}

-(void) sendLastSignal {
    if (bleShield.activePeripheral.state == CBPeripheralStateConnected) {
        [bleShield write:[@"H014" dataUsingEncoding:NSUTF8StringEncoding]];
    }
}

-(void) sendTurnRight {
    [NSTimer scheduledTimerWithTimeInterval:(float)0.5 target:self selector:@selector(sendLastSignal) userInfo:nil repeats:NO];
}

@end