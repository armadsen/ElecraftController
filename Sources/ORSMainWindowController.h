//
//  ORSMainWindowController.h
//  Elecraft Controller
//
//  Created by Andrew Madsen on 1/18/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

@import Cocoa;

@class ORSSerialPortManager;
@class ORSElecraftRigController;

@interface ORSMainWindowController : NSWindowController

+ (instancetype)windowController;

@property (nonatomic, strong) ORSSerialPortManager *serialPortManager;
@property (nonatomic, strong) ORSElecraftRigController *rigController;

@end
