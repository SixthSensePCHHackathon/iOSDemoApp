//
//  HFCommander.h
//  SixthSense
//
//  Created by Samuel Parkinson on 17/10/2015.
//  Copyright © 2015 mettle-studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLE.h"

@interface HFCommander : NSObject <BLEDelegate>
{
    BLE *bleShield;
}
+ (HFCommander *)sharedCommander;
- (void) setOnRoute;
- (void) unsetOnRoute;
- (void) sendContinueStraight;
- (void) sendTurnLeft;
- (void) sendTurnRight;

@end
