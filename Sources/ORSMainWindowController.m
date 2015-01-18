//
//  ORSMainWindowController.m
//  Elecraft Controller
//
//  Created by Andrew Madsen on 1/18/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import "ORSMainWindowController.h"
#import <ORSSerial/ORSSerial.h>

@interface ORSMainWindowController ()

@end

@implementation ORSMainWindowController

+ (instancetype)windowController
{
	return [[self alloc] initWithWindowNibName:@"MainWindow"];
}

- (instancetype)initWithWindowNibName:(NSString *)windowNibName
{
	self = [super initWithWindowNibName:windowNibName];
	if (self) {
		_serialPortManager = [ORSSerialPortManager sharedSerialPortManager];
	}
	return self;
}

@end
