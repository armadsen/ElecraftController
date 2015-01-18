//
//  ORSMainWindowController.m
//  Elecraft Controller
//
//  Created by Andrew Madsen on 1/18/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import "ORSMainWindowController.h"
#import <ORSSerial/ORSSerial.h>

@implementation ORSMainWindowController

+ (instancetype)windowController
{
	return [[self alloc] initWithWindowNibName:@"MainWindow"];
}

- (ORSSerialPortManager *)serialPortManager { return [ORSSerialPortManager sharedSerialPortManager]; }

@end
