//
//  ORSElecraftRigController.m
//  Elecraft Controller
//
//  Created by Andrew Madsen on 1/18/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import "ORSElecraftRigController.h"
#import <ORSSerial/ORSSerial.h>

#define kORSElecraftTimeoutInterval 1.0
#define kORSElecraftPollingInterval 1.0

@interface ORSElecraftRigController () <ORSSerialPortDelegate>

@property (nonatomic, strong) NSTimer *pollingTimer;
@property (nonatomic, getter=isHandlingResponse) BOOL handlingResponse;

@end

@implementation ORSElecraftRigController

#pragma mark - Private

#pragma mark Polling

- (void)startPolling
{
	self.pollingTimer = [NSTimer scheduledTimerWithTimeInterval:kORSElecraftPollingInterval
														 target:self
													   selector:@selector(pollRigForUpdatedValues:)
													   userInfo:nil
														repeats:YES];
	[self pollRigForUpdatedValues:nil]; // Poll for the first time immediately
}

- (void)stopPolling
{
	self.pollingTimer = nil;
}

- (void)pollRigForUpdatedValues:(NSTimer *)timer
{
	[self requestVFOAFrequencyFromRig];
	[self requestVFOBFrequencyFromRig];
	[self requestModeFromRig];
	[self requestPowerLevelFromRig];
}

#pragma mark Communication

- (void)requestVFOAFrequencyFromRig
{
	ORSSerialRequest *request = [self requestToReadRigValueWithDataToSend:[@"fa;" dataUsingEncoding:NSASCIIStringEncoding]
															 propertyName:@"vfoAFrequencyInKHz"
															  parserBlock:^id(NSData *inputData) {
																  return [self vfoFrequencyInKHzFromResponseData:inputData];
															  }];
	[self.serialPort sendRequest:request];
}

- (void)writeVFOAFrequencyToRig:(NSNumber *)frequency
{
	NSUInteger freqInHz = (NSUInteger)([frequency doubleValue]*(double)1e3);
	NSString *commandString = [NSString stringWithFormat:@"fa%0*li;", 11, (long)freqInHz];
	NSData *dataToSend = [commandString dataUsingEncoding:NSASCIIStringEncoding];
	
	ORSSerialRequest *request = [ORSSerialRequest requestWithDataToSend:dataToSend userInfo:nil timeoutInterval:kORSElecraftTimeoutInterval responseEvaluator:nil];
	[self.serialPort sendRequest:request];
}

- (void)requestVFOBFrequencyFromRig
{
	ORSSerialRequest *request = [self requestToReadRigValueWithDataToSend:[@"fb;" dataUsingEncoding:NSASCIIStringEncoding]
															 propertyName:@"vfoBFrequencyInKHz"
															  parserBlock:^id(NSData *inputData) {
																  return [self vfoFrequencyInKHzFromResponseData:inputData];
															  }];
	[self.serialPort sendRequest:request];
}

- (void)writeVFOBFrequencyToRig:(NSNumber *)frequency
{
	NSUInteger freqInHz = (NSUInteger)([frequency doubleValue]*(double)1e3);
	NSString *commandString = [NSString stringWithFormat:@"fb%0*li;", 11, (long)freqInHz];
	NSData *dataToSend = [commandString dataUsingEncoding:NSASCIIStringEncoding];
	
	ORSSerialRequest *request = [ORSSerialRequest requestWithDataToSend:dataToSend userInfo:nil timeoutInterval:kORSElecraftTimeoutInterval responseEvaluator:nil];
	[self.serialPort sendRequest:request];
}

- (void)requestModeFromRig
{
	ORSSerialRequest *request = [self requestToReadRigValueWithDataToSend:[@"md;" dataUsingEncoding:NSASCIIStringEncoding]
															 propertyName:@"mode"
															  parserBlock:^id(NSData *inputData) {
																  return [self modeFromResponseData:inputData];
															  }];
	[self.serialPort sendRequest:request];
}

- (void)writeModeToRig:(NSString *)mode
{
	NSDictionary *modeToModeCodeMap = @{@"LSB" : @"1",
						   @"USB" : @"2",
						   @"CW" : @"3",
						   @"FM" : @"4",
						   @"AM" : @"5",
						   @"RTTY" : @"6",
						   @"CW-R" : @"7",
						   @"RTTY-R" : @"9"};

	NSString *modeCode = modeToModeCodeMap[mode];
	NSString *commandString = [NSString stringWithFormat:@"md%@;", modeCode];
	NSData *dataToSend = [commandString dataUsingEncoding:NSASCIIStringEncoding];
	
	ORSSerialRequest *request = [ORSSerialRequest requestWithDataToSend:dataToSend userInfo:nil timeoutInterval:kORSElecraftTimeoutInterval responseEvaluator:nil];
	[self.serialPort sendRequest:request];
}

- (void)requestPowerLevelFromRig
{
	ORSSerialRequest *request = [self requestToReadRigValueWithDataToSend:[@"pc;" dataUsingEncoding:NSASCIIStringEncoding]
															 propertyName:@"powerLevelInWatts"
															  parserBlock:^id(NSData *inputData) {
																  return [self powerLevelFromResponseData:inputData];
															  }];
	
	[self.serialPort sendRequest:request];
}

- (void)writePowerLevelToRig:(double)powerLevel
{
	NSString *commandString = [NSString stringWithFormat:@"PC%0*li;", 3, (unsigned long)powerLevel];
	NSData *dataToSend = [commandString dataUsingEncoding:NSASCIIStringEncoding];
	
	ORSSerialRequest *request = [ORSSerialRequest requestWithDataToSend:dataToSend userInfo:nil timeoutInterval:kORSElecraftTimeoutInterval responseEvaluator:nil];
	[self.serialPort sendRequest:request];
}

#pragma mark Request Generation

- (ORSSerialRequest *)requestToReadRigValueWithDataToSend:(NSData *)dataToSend
											 propertyName:(NSString *)propertyName
											  parserBlock:(id(^)(NSData *inputData))parserBlock
{
	NSDictionary *userInfo = @{@"requesetType": @"read",
							   @"propertyName": propertyName,
							   @"parserBlock": [parserBlock copy]};
	return [ORSSerialRequest requestWithDataToSend:dataToSend
										  userInfo:userInfo
								   timeoutInterval:kORSElecraftTimeoutInterval
								 responseEvaluator:^BOOL(NSData *inputData) {
									 return parserBlock(inputData) != nil;
								 }];
}

#pragma mark - Response Handling

- (void)handleResponse:(NSData *)responseData toReadRequest:(ORSSerialRequest *)request
{
	NSDictionary *userInfo = request.userInfo;
	NSString *propertyName = userInfo[@"propertyName"];
	id(^parserBlock)(NSData *) = userInfo[@"parserBlock"];
	id value = parserBlock(responseData);
	if (!value) {
		// Handle error
		return;
	}
	self.handlingResponse = YES; // Prevent sending an update back to the rig
	[self setValue:value forKey:propertyName];
	self.handlingResponse = NO;
}

#pragma mark Response Parsers

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
	[self handleResponse:responseData toReadRequest:request];
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

#pragma mark Rig Values

- (void)setVfoAFrequencyInKHz:(NSInteger)vfoAFrequencyInKHz
{
	if (vfoAFrequencyInKHz != _vfoAFrequencyInKHz) {
		_vfoAFrequencyInKHz = vfoAFrequencyInKHz;
	}
	
	if (!self.isHandlingResponse) {
		[self writeVFOAFrequencyToRig:@(vfoAFrequencyInKHz)];
		[self requestVFOAFrequencyFromRig]; // Verify that write was successful
	}
}

- (void)setVfoBFrequencyInKHz:(NSInteger)vfoBFrequencyInKHz
{
	if (vfoBFrequencyInKHz != _vfoBFrequencyInKHz) {
		_vfoBFrequencyInKHz = vfoBFrequencyInKHz;
	}
	
	if (!self.isHandlingResponse) {
		[self writeVFOBFrequencyToRig:@(vfoBFrequencyInKHz)];
		[self requestVFOBFrequencyFromRig]; // Verify that write was successful
	}
}

- (void)setMode:(NSString *)mode
{
	if (mode != _mode) {
		_mode = mode;
	}
	
	if (!self.isHandlingResponse) {
		[self writeModeToRig:mode];
		[self requestModeFromRig]; // Verify that write was successful
	}
}

- (void)setPowerLevelInWatts:(double)powerLevelInWatts
{
	if (powerLevelInWatts != _powerLevelInWatts) {
		_powerLevelInWatts = powerLevelInWatts;
	}
	
	if (!self.isHandlingResponse) {
		[self writePowerLevelToRig:powerLevelInWatts];
		[self requestPowerLevelFromRig];
	}
}

@end
