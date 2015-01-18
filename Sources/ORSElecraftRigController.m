//
//  ORSElecraftRigController.m
//  Elecraft Controller
//
//  Created by Andrew Madsen on 1/18/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import "ORSElecraftRigController.h"
#import <ORSSerial/ORSSerial.h>

@interface ORSElecraftRigController () <ORSSerialPortDelegate>

@property (nonatomic, strong) NSTimer *pollingTimer;

@end

@implementation ORSElecraftRigController

#pragma mark - Private

#pragma mark Polling

- (void)startPolling
{
	self.pollingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(pollRigForUpdatedValues:) userInfo:nil repeats:YES];
	[self pollRigForUpdatedValues:nil]; // Poll for the first time immediately
}

- (void)stopPolling
{
	self.pollingTimer = nil;
}

- (void)pollRigForUpdatedValues:(NSTimer *)timer
{
	ORSSerialRequest *vfoARequest = [self requestForRigValueWithDataToSend:[@"fa;" dataUsingEncoding:NSASCIIStringEncoding]
															  propertyName:@"vfoAFrequencyInKHz"
															   parserBlock:^id(NSData *inputData) {
																   return [self vfoFrequencyInKHzFromResponseData:inputData];
															   }];
	ORSSerialRequest *vfoBRequest = [self requestForRigValueWithDataToSend:[@"fb;" dataUsingEncoding:NSASCIIStringEncoding]
															  propertyName:@"vfoBFrequencyInKHz"
															   parserBlock:^id(NSData *inputData) {
																   return [self vfoFrequencyInKHzFromResponseData:inputData];
															   }];
	ORSSerialRequest *modeRequest = [self requestForRigValueWithDataToSend:[@"md;" dataUsingEncoding:NSASCIIStringEncoding]
															  propertyName:@"mode"
															   parserBlock:^id(NSData *inputData) {
																   return [self modeFromResponseData:inputData];
															   }];
	ORSSerialRequest *powerLevelRequest = [self requestForRigValueWithDataToSend:[@"pc;" dataUsingEncoding:NSASCIIStringEncoding]
															  propertyName:@"powerLevelInWatts"
															   parserBlock:^id(NSData *inputData) {
																   return [self powerLevelFromResponseData:inputData];
															   }];
	
	[self.serialPort sendRequest:vfoARequest];
	[self.serialPort sendRequest:vfoBRequest];
	[self.serialPort sendRequest:modeRequest];
	[self.serialPort sendRequest:powerLevelRequest];
}

#pragma mark Communication

#pragma mark Request Generation

- (ORSSerialRequest *)requestForRigValueWithDataToSend:(NSData *)dataToSend
										  propertyName:(NSString *)propertyName
										   parserBlock:(id(^)(NSData *inputData))parserBlock
{
	NSDictionary *userInfo = @{@"propertyName": propertyName,
							   @"parserBlock": [parserBlock copy]};
	return [ORSSerialRequest requestWithDataToSend:dataToSend
										  userInfo:userInfo
								   timeoutInterval:1.0
								 responseEvaluator:^BOOL(NSData *inputData) {
									 return parserBlock(inputData) != nil;
								 }];
}

#pragma mark Response Handling (Parsers)

- (NSNumber *)vfoFrequencyInKHzFromResponseData:(NSData *)data
{
	NSString *string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	if ([string length] != 14) return nil;
	
	NSString *prefix = [string substringToIndex:2];
	if ([prefix caseInsensitiveCompare:@"fa"] != NSOrderedSame &&
		[prefix caseInsensitiveCompare:@"fb"] != NSOrderedSame) return nil;
	
	NSString *frequencyString = [string substringWithRange:NSMakeRange(2, 11)];
	return @([frequencyString doubleValue] / 1000);
}

- (NSNumber *)powerLevelFromResponseData:(NSData *)data
{
	NSString *string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	if ([string length] != 6) return nil;
	
	NSString *prefix = [string substringToIndex:2];
	if ([prefix caseInsensitiveCompare:@"pc"] != NSOrderedSame) return nil;
	
	NSString *powerString = [string substringWithRange:NSMakeRange(2, 3)];
	double power = [powerString doubleValue];
	return (power <= 200 && power > 0) ? @(power) : nil;
}

- (NSString *)modeFromResponseData:(NSData *)data;
{
	NSString *string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	if ([string length] != 4) return nil;
	
	NSString *prefix = [string substringToIndex:2];
	if ([prefix caseInsensitiveCompare:@"md"] != NSOrderedSame) return nil;
	
	NSString *modeCode = [string substringWithRange:NSMakeRange(2, 1)];
	NSDictionary *modeCodeToModeMap = @{@"1": @"LSB",
										@"2": @"USB",
										@"3": @"CW",
										@"4": @"FM",
										@"5": @"AM",
										@"6": @"RTTY",
										@"7": @"CW-R",
										@"9": @"RTTY-R"};
	return modeCodeToModeMap[modeCode];
}

#pragma mark - ORSSerialPortDelegate

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort
{
	[self stopPolling];
}

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort
{
	[self startPolling];
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort
{
	if (self.serialPort == serialPort) self.serialPort = nil;
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveResponse:(NSData *)responseData toRequest:(ORSSerialRequest *)request
{
	NSDictionary *userInfo = request.userInfo;
	NSString *propertyName = userInfo[@"propertyName"];
	id(^parserBlock)(NSData *) = userInfo[@"parserBlock"];
	id value = parserBlock(responseData);
	if (!value) {
		// Handle error
		return;
	}
	[self setValue:value forKey:propertyName];
}

- (void)serialPort:(ORSSerialPort *)serialPort requestDidTimeout:(ORSSerialRequest *)request
{
	NSLog(@"Request %@ timed out.", request);
}

#pragma mark - Properties

- (void)setSerialPort:(ORSSerialPort *)serialPort
{
	if (serialPort != _serialPort) {
		[_serialPort close];
		_serialPort.delegate = nil;
		
		_serialPort = serialPort;
		
		_serialPort.delegate = self;
		_serialPort.baudRate = @4800;
		[_serialPort open];
	}
}

- (void)setPollingTimer:(NSTimer *)pollingTimer
{
	if (pollingTimer != _pollingTimer) {
		[_pollingTimer invalidate];
		_pollingTimer = pollingTimer;
	}
}

@end
