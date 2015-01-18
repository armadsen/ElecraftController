//
//  AppDelegate.m
//  Elecraft Controller
//
//  Created by Andrew Madsen on 1/18/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import "ORSAppController.h"
#import "ORSMainWindowController.h"

@interface ORSAppController ()

@property (nonatomic, strong) ORSMainWindowController *mainWindowController;

@end

@implementation ORSAppController

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	self.mainWindowController = [ORSMainWindowController windowController];
	[self.mainWindowController showWindow:nil];
}

@end
