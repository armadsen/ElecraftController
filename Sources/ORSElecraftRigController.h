//
//  ORSElecraftRigController.h
//  Elecraft Controller
//
//  Created by Andrew Madsen on 1/18/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ORSElecraftRigController : NSObject

@property (nonatomic) NSInteger vfoAFrequencyInKHz;
@property (nonatomic) NSInteger vfoBFrequencyInKHz;
@property (nonatomic) double powerLevelInWatts;
@property (nonatomic, strong) NSString *mode;

@end
