//
//  PJProjector.m
//  ProjectR
//
//  Created by Eric Hyche on 7/7/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJProjector.h"
#import "PJInputInfo.h"
#import "PJRequestInfo.h"
#import "PJResponseInfo.h"
#import "AFPJLinkClient.h"
#import "PJURLProtocolRunLoop.h"

NSString*      const PJProjectorRequestDidBeginNotification          = @"PJProjectorRequestDidBeginNotification";
NSString*      const PJProjectorRequestDidEndNotification            = @"PJProjectorRequestDidEndNotification";
NSString*      const PJProjectorDidChangeNotification                = @"PJProjectorDidChangeNotification";
NSString*      const PJProjectorConnectionStateDidChangeNotification = @"PJProjectorConnectionStateDidChangeNotification";
NSString*      const PJProjectorErrorKey                             = @"PJProjectorErrorKey";
NSString*      const kPJLinkCommandPowerOn                           = @"POWR 1\rPOWR ?\r";
NSString*      const kPJLinkCommandPowerOff                          = @"POWR 0\rPOWR ?\r";
NSTimeInterval const kDefaultRefreshTimerInterval                    = 60.0;
NSTimeInterval const kPowerTransitionRefreshTimerInterval            =  5.0;

@interface PJProjector()

// Readwrite versions of public readonly properties
@property(nonatomic,assign,readwrite)                           PJPowerStatus     powerStatus;
@property(nonatomic,assign,readwrite,getter=isAudioMuted)       BOOL              audioMuted;
@property(nonatomic,assign,readwrite,getter=isVideoMuted)       BOOL              videoMuted;
@property(nonatomic,assign,readwrite)                           PJErrorStatus     fanErrorStatus;
@property(nonatomic,assign,readwrite)                           PJErrorStatus     lampErrorStatus;
@property(nonatomic,assign,readwrite)                           PJErrorStatus     temperatureErrorStatus;
@property(nonatomic,assign,readwrite)                           PJErrorStatus     coverOpenErrorStatus;
@property(nonatomic,assign,readwrite)                           PJErrorStatus     filterErrorStatus;
@property(nonatomic,assign,readwrite)                           PJErrorStatus     otherErrorStatus;
@property(nonatomic,copy,readwrite)                             NSArray*          lampStatus;
@property(nonatomic,copy,readwrite)                             NSArray*          inputs;
@property(nonatomic,assign,readwrite)                           NSUInteger        activeInputIndex;
@property(nonatomic,copy,readwrite)                             NSString*         projectorName;
@property(nonatomic,copy,readwrite)                             NSString*         manufacturerName;
@property(nonatomic,copy,readwrite)                             NSString*         productName;
@property(nonatomic,copy,readwrite)                             NSString*         otherInformation;
@property(nonatomic,assign,readwrite,getter=isClass2Compatible) BOOL              class2Compatible;
@property(nonatomic,assign,readwrite)                           PJConnectionState connectionState;
@property(nonatomic,copy,readwrite)                             NSString*         host;
@property(nonatomic,assign,readwrite)                           NSInteger         port;
// Mutable array member variables for immutable properties
@property(nonatomic,strong) NSMutableArray*  mutableInputs;
@property(nonatomic,strong) NSMutableArray*  mutableLampStatus;
@property(nonatomic,strong) NSMutableString* mutableProjectorName;
@property(nonatomic,strong) NSMutableString* mutableManufacturerName;
@property(nonatomic,strong) NSMutableString* mutableProductName;
@property(nonatomic,strong) NSMutableString* mutableOtherInformation;
// Internal-only properties
@property(nonatomic,assign) BOOL            modelChanged;
@property(nonatomic,strong) AFPJLinkClient* pjlinkClient;
@property(nonatomic,strong) NSTimer*        refreshTimer;
@property(nonatomic,strong) NSTimer*        powerTransitionRefreshTimer;

@end

@implementation PJProjector

- (id)initWithHost:(NSString*)host {
    return [self initWithHost:host port:kDefaultPJLinkPort];
}

- (id)initWithHost:(NSString*)host port:(NSInteger)port {
    self = [super init];
    if (self) {
        // Save the host and port
        self.host = host;
        self.port = port;
        // Set initial values
        self.powerStatus             = PJPowerStatusStandby;
        self.audioMuted              = NO;
        self.videoMuted              = NO;
        self.fanErrorStatus          = PJErrorStatusNoError;
        self.lampErrorStatus         = PJErrorStatusNoError;
        self.temperatureErrorStatus  = PJErrorStatusNoError;
        self.coverOpenErrorStatus    = PJErrorStatusNoError;
        self.filterErrorStatus       = PJErrorStatusNoError;
        self.otherErrorStatus        = PJErrorStatusNoError;
        self.class2Compatible        = NO;
        self.connectionState         = PJConnectionStateDiscovered;
        self.refreshTimerInterval    = kDefaultRefreshTimerInterval;
        self.refreshTimerOn          = NO;
        // Initialize mutable members
        self.mutableInputs           = [NSMutableArray array];
        self.mutableLampStatus       = [NSMutableArray array];
        self.mutableProjectorName    = [NSMutableString string];
        self.mutableManufacturerName = [NSMutableString string];
        self.mutableProductName      = [NSMutableString string];
        self.mutableOtherInformation = [NSMutableString string];
        // Create the AFPJLinkClient
        [self rebuildPJLinkClient];
    }

    return self;
}

- (NSArray*)lampStatus {
    return [NSArray arrayWithArray:self.mutableLampStatus];
}

- (NSArray*)inputs {
    return [NSArray arrayWithArray:self.mutableInputs];
}

- (NSString*)projectorName {
    return [NSString stringWithString:self.mutableProjectorName];
}

- (void)setProjectorName:(NSString *)projectorName {
    if (![self.mutableProjectorName isEqualToString:projectorName]) {
        self.modelChanged = YES;
        [self.mutableProjectorName setString:projectorName];
    }
}

- (NSString*)manufacturerName {
    return [NSString stringWithString:self.mutableManufacturerName];
}

- (void)setManufacturerName:(NSString *)manufacturerName {
    if (![self.mutableManufacturerName isEqualToString:manufacturerName]) {
        self.modelChanged = YES;
        [self.mutableManufacturerName setString:manufacturerName];
    }
}

- (NSString*)productName {
    return [NSString stringWithString:self.mutableProductName];
}

- (void)setProductName:(NSString *)productName {
    if (![self.mutableProductName isEqualToString:productName]) {
        self.modelChanged = YES;
        [self.mutableProductName setString:productName];
    }
}

- (NSString*)otherInformation {
    return [NSString stringWithString:self.mutableOtherInformation];
}

- (void)setOtherInformation:(NSString *)otherInformation {
    if (![self.mutableOtherInformation isEqualToString:otherInformation]) {
        self.modelChanged = YES;
        [self.mutableOtherInformation setString:otherInformation];
    }
}

- (NSUInteger)countOfInputs {
    return [self.mutableInputs count];
}

- (id)objectInInputsAtIndex:(NSUInteger)index {
    return [self.mutableInputs objectAtIndex:index];
}

- (NSArray*)inputsAtIndexes:(NSIndexSet *)indexes {
    return [self.mutableInputs objectsAtIndexes:indexes];
}

- (NSUInteger)countOfLampStatus {
    return [self.mutableLampStatus count];
}

- (id)objectInLampStatusAtIndex:(NSUInteger)index {
    return [self.mutableLampStatus objectAtIndex:index];
}

- (NSArray*)lampStatusAtIndexes:(NSIndexSet *)indexes {
    return [self.mutableLampStatus objectsAtIndexes:indexes];
}

- (void)setPowerStatus:(PJPowerStatus)powerStatus {
    if (_powerStatus != powerStatus) {
        _powerStatus = powerStatus;
        self.modelChanged = YES;
        [self updatePowerTransitionRefreshTimerStatus];
    }
}

- (void)setAudioMuted:(BOOL)audioMuted {
    if (_audioMuted != audioMuted) {
        _audioMuted = audioMuted;
        self.modelChanged = YES;
    }
}

- (void)setVideoMuted:(BOOL)videoMuted {
    if (_videoMuted != videoMuted) {
        _videoMuted = videoMuted;
        self.modelChanged = YES;
    }
}

- (void)setFanErrorStatus:(PJErrorStatus)fanErrorStatus {
    if (_fanErrorStatus != fanErrorStatus) {
        _fanErrorStatus = fanErrorStatus;
        self.modelChanged = YES;
    }
}

- (void)setLampErrorStatus:(PJErrorStatus)lampErrorStatus {
    if (_lampErrorStatus != lampErrorStatus) {
        _lampErrorStatus = lampErrorStatus;
        self.modelChanged = YES;
    }
}

- (void)setTemperatureErrorStatus:(PJErrorStatus)temperatureErrorStatus {
    if (_temperatureErrorStatus != temperatureErrorStatus) {
        _temperatureErrorStatus = temperatureErrorStatus;
        self.modelChanged = YES;
    }
}

- (void)setCoverOpenErrorStatus:(PJErrorStatus)coverOpenErrorStatus {
    if (_coverOpenErrorStatus != coverOpenErrorStatus) {
        _coverOpenErrorStatus = coverOpenErrorStatus;
        self.modelChanged = YES;
    }
}

- (void)setFilterErrorStatus:(PJErrorStatus)filterErrorStatus {
    if (_filterErrorStatus != filterErrorStatus) {
        _filterErrorStatus = filterErrorStatus;
        self.modelChanged = YES;
    }
}

- (void)setOtherErrorStatus:(PJErrorStatus)otherErrorStatus {
    if (_otherErrorStatus != otherErrorStatus) {
        _otherErrorStatus = otherErrorStatus;
        self.modelChanged = YES;
    }
}

- (void)setActiveInputIndex:(NSUInteger)activeInputIndex {
    if (_activeInputIndex != activeInputIndex) {
        _activeInputIndex = activeInputIndex;
        self.modelChanged = YES;
    }
}

- (void)setClass2Compatible:(BOOL)class2Compatible {
    if (_class2Compatible != class2Compatible) {
        _class2Compatible = class2Compatible;
        self.modelChanged = YES;
    }
}

- (void)setLampStatus:(NSArray *)lampStatus {
    if (![self.mutableLampStatus isEqualToArray:lampStatus]) {
        self.modelChanged = YES;
        [self.mutableLampStatus setArray:lampStatus];
    }
}

- (void)setInputs:(NSArray *)inputs {
    if (![self.mutableInputs isEqualToArray:inputs]) {
        self.modelChanged = YES;
        [self.mutableInputs setArray:inputs];
    }
}

- (void)setPassword:(NSString *)password {
    if (![_password isEqualToString:password]) {
        _password = [password copy];
        // Create an NSURLCredential with this password.
        // PJLink does not require (or use) a username, so we just
        // supply a dummy username.
        NSURLCredential* credential = [NSURLCredential credentialWithUser:@"user"
                                                                 password:_password
                                                              persistence:NSURLCredentialPersistenceForSession];
        // Set this credential as the default credential for our AFPJLinkClient
        [self.pjlinkClient setDefaultCredential:credential];
    }
}

- (void)setConnectionState:(PJConnectionState)connectionState {
    if (_connectionState != connectionState) {
        _connectionState = connectionState;
        // Post a connection state did change notification
        [self postConnectionStateDidChangeNotification];
    }
}

- (void)setRefreshTimerInterval:(NSTimeInterval)refreshTimerInterval {
    if (_refreshTimerInterval != refreshTimerInterval) {
        // Save the new refresh timer interval
        _refreshTimerInterval = refreshTimerInterval;
        // If we are currently refreshing, then we need to tear down the timer and re-build
        if (_refreshTimerOn) {
            // Invalidate the old timer
            [self.refreshTimer invalidate];
            // Create a new one
            self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:_refreshTimerInterval
                                                                 target:self
                                                               selector:@selector(refreshTimerFired:)
                                                               userInfo:nil
                                                                repeats:YES];
        }
    }
}

- (void)setRefreshTimerOn:(BOOL)refreshTimerOn {
    if (_refreshTimerOn && !refreshTimerOn) {
        // Invalidate and destroy the refresh timer
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    } else if (!_refreshTimerOn && refreshTimerOn) {
        // Create a repeating refresh timer
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:self.refreshTimerInterval
                                                             target:self
                                                           selector:@selector(refreshTimerFired:)
                                                           userInfo:nil
                                                            repeats:YES];
    }
}

- (void)refreshQueries:(NSArray*)queries {
    if ([queries count] > 0) {
        // Make the request and handle the responses.
        [self handleResponsesForCommandRequestBody:[PJRequestInfo queryStringForCommands:queries]];
    }
}

- (void)refreshAllQueries {
    [self refreshQueries:@[@(PJCommandPower),
                           @(PJCommandInput),
                           @(PJCommandAVMute),
                           @(PJCommandErrorQuery),
                           @(PJCommandLampQuery),
                           @(PJCommandInputListQuery),
                           @(PJCommandProjectorNameQuery),
                           @(PJCommandManufacturerNameQuery),
                           @(PJCommandProductNameQuery),
                           @(PJCommandOtherInfoQuery),
                           @(PJCommandClassInfoQuery)]];
}

- (void)refreshPowerStatus {
    [self refreshQueries:@[@(PJCommandPower)]];
}

- (void)refreshInputStatus {
    [self refreshQueries:@[@(PJCommandInput)]];
}

- (void)refreshMuteStatus {
    [self refreshQueries:@[@(PJCommandAVMute)]];
}

- (void)refreshSettableQueries {
    [self refreshQueries:@[@(PJCommandPower),
                           @(PJCommandInput),
                           @(PJCommandAVMute)]];
}

- (void)refreshQueriesWeExpectToChange {
    [self refreshQueries:@[@(PJCommandPower),
                           @(PJCommandInput),
                           @(PJCommandAVMute),
                           @(PJCommandErrorQuery),
                           @(PJCommandLampQuery),
                           @(PJCommandInputListQuery)]];
}

- (BOOL)requestPowerStateChange:(BOOL)powerOn {
    NSString* commandBody = nil;
    if (powerOn) {
        // We only want to turn the power on if we are in standby
        if (self.powerStatus == PJPowerStatusStandby) {
            commandBody = kPJLinkCommandPowerOn;
        }
    } else {
        // We only want to turn the power off if we in lamp on status
        if (self.powerStatus == PJPowerStatusLampOn) {
            commandBody = kPJLinkCommandPowerOff;
        }
    }
    // Process the command body (if it is present)
    [self handleResponsesForCommandRequestBody:commandBody];

    return (commandBody != nil ? YES : NO);
}

- (BOOL)requestMuteStateChange:(BOOL)muteOn forTypes:(PJMuteType)type {
    BOOL ret = NO;

    // Determine if we actually need to change anything
    if (type == PJMuteTypeAudio) {
        ret = (self.isAudioMuted != muteOn);
    } else if (type == PJMuteTypeVideo) {
        ret = (self.isVideoMuted != muteOn);
    } else if (type == PJMuteTypeAudioAndVideo) {
        ret = (self.isAudioMuted != muteOn || self.isVideoMuted != muteOn);
    }
    if (ret) {
        [self handleResponsesForCommandRequestBody:[self muteCommandBodyForType:type state:muteOn]];
    }

    return ret;
}

- (BOOL)requestInputChangeToInput:(PJInputInfo*)input {
    BOOL ret = NO;

    // Find the index of this input in our valid inputs
    NSUInteger inputIndex = [PJProjector indexOfInput:input inInputs:self.mutableInputs];
    // Is this input one of our valid inputs?
    if (inputIndex != NSNotFound) {
        // We will be making a request
        ret = YES;
        // Construct the command and issue the request
        NSString* commandBody = [NSString stringWithFormat:@"INPT %u%u\rINPT ?\r", input.inputType, input.inputNumber];
        [self handleResponsesForCommandRequestBody:commandBody];
    }

    return ret;
}

- (BOOL)requestInputChangeToInputIndex:(NSUInteger)inputIndex {
    BOOL ret = NO;

    if (inputIndex < [self.inputs count]) {
        PJInputInfo* inputInfo = [self.mutableInputs objectAtIndex:inputIndex];
        ret = [self requestInputChangeToInput:inputInfo];
    }

    return ret;
}

- (BOOL)requestInputChangeToInputType:(PJInputType)type number:(NSUInteger)number {
    return [self requestInputChangeToInput:[PJInputInfo inputInfoWithType:type number:number]];
}

#pragma mark - PJProjector private methods

- (void)setActiveInputWithType:(PJInputType)type number:(NSUInteger)number {
    // Find the index of the input with this type and number
    NSUInteger inputIndex = [PJProjector indexOfInput:[PJInputInfo inputInfoWithType:type number:number] inInputs:self.mutableInputs];
    // Is this a valid input?
    if (inputIndex != NSNotFound) {
        // Update the active input index
        self.activeInputIndex = inputIndex;
    }
}

- (void)handleResponses:(NSArray*)responses {
    if ([responses count] > 0) {
        // Clear the flag saying that the model changed
        self.modelChanged = NO;
        // Process all the responses
        for (PJResponseInfo* response in responses) {
            [self handleResponse:response];
        }
        // If the model changed, then issue the did-change notification
        if (self.modelChanged) {
            self.modelChanged = NO;
            [self postProjectorDidChangeNotification];
        }
    }
}

- (void)handleResponse:(PJResponseInfo*)responseInfo {
    // Make sure we didn't encounter an error
    if (responseInfo.error == PJErrorOK) {
        if ([responseInfo isKindOfClass:[PJResponseInfoPowerStatusQuery class]]) {
            PJResponseInfoPowerStatusQuery* powerStatusQuery = (PJResponseInfoPowerStatusQuery*)responseInfo;
            self.powerStatus = powerStatusQuery.powerStatus;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoInputSwitchQuery class]]) {
            PJResponseInfoInputSwitchQuery* inputSwitchQuery = (PJResponseInfoInputSwitchQuery*)responseInfo;
            PJInputInfo* inputInfo = inputSwitchQuery.input;
            [self setActiveInputWithType:inputInfo.inputType number:inputInfo.inputNumber];
        } else if ([responseInfo isKindOfClass:[PJResponseInfoMuteStatusQuery class]]) {
            PJResponseInfoMuteStatusQuery* muteStatusQuery = (PJResponseInfoMuteStatusQuery*)responseInfo;
            if (muteStatusQuery.muteType & PJMuteTypeAudio) {
                self.audioMuted = muteStatusQuery.muteOn;
            }
            if (muteStatusQuery.muteType & PJMuteTypeVideo) {
                self.videoMuted = muteStatusQuery.muteOn;
            }
        } else if ([responseInfo isKindOfClass:[PJResponseInfoErrorStatusQuery class]]) {
            PJResponseInfoErrorStatusQuery* errorStatusQuery = (PJResponseInfoErrorStatusQuery*) responseInfo;
            self.fanErrorStatus         = errorStatusQuery.fanError;
            self.lampErrorStatus        = errorStatusQuery.lampError;
            self.temperatureErrorStatus = errorStatusQuery.temperatureError;
            self.coverOpenErrorStatus   = errorStatusQuery.coverOpenError;
            self.filterErrorStatus      = errorStatusQuery.filterError;
            self.otherErrorStatus       = errorStatusQuery.otherError;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoLampQuery class]]) {
            PJResponseInfoLampQuery* lampQuery = (PJResponseInfoLampQuery*) responseInfo;
            // Check if anything changed
            self.lampStatus = lampQuery.lampStatuses;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoInputTogglingListQuery class]]) {
            PJResponseInfoInputTogglingListQuery* inputListQuery = (PJResponseInfoInputTogglingListQuery*)responseInfo;
            self.inputs = inputListQuery.inputs;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoProjectorNameQuery class]]) {
            PJResponseInfoProjectorNameQuery* projectorNameQuery = (PJResponseInfoProjectorNameQuery*)responseInfo;
            self.projectorName = projectorNameQuery.projectorName;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoManufacturerNameQuery class]]) {
            PJResponseInfoManufacturerNameQuery* manufacturerNameQuery = (PJResponseInfoManufacturerNameQuery*)responseInfo;
            self.manufacturerName = manufacturerNameQuery.manufacturerName;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoProductNameQuery class]]) {
            PJResponseInfoProductNameQuery* productNameQuery = (PJResponseInfoProductNameQuery*)responseInfo;
            self.productName = productNameQuery.productName;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoOtherInfoQuery class]]) {
            PJResponseInfoOtherInfoQuery* otherInfoQuery = (PJResponseInfoOtherInfoQuery*)responseInfo;
            self.otherInformation = otherInfoQuery.otherInfo;
        } else if ([responseInfo isKindOfClass:[PJResponseInfoClassInfoQuery class]]) {
            PJResponseInfoClassInfoQuery* classInfoQuery = (PJResponseInfoClassInfoQuery*)responseInfo;
            self.class2Compatible = classInfoQuery.class2Compatible;
        }
    }
}

- (void)rebuildPJLinkClient {
    NSString* pjlinkURLStr = [NSString stringWithFormat:@"pjlink://%@:%d/", self.host, self.port];
    NSURL*    pjlinkURL    = [NSURL URLWithString:pjlinkURLStr];
    [self.pjlinkClient.operationQueue cancelAllOperations];
    self.pjlinkClient = [[AFPJLinkClient alloc] initWithBaseURL:pjlinkURL];
}

- (void)handleResponsesForCommandRequestBody:(NSString*)requestBody {
    if ([requestBody length] > 0 && self.pjlinkClient != nil) {
        // Send the request did begin notification
        [self postRequestDidBeginNotification];
        // Update the connection state if necessary.
        [self updateConnectionStatePreRequest];
        // Send the request
        [self.pjlinkClient makeRequestWithBody:requestBody
                                       success:^(AFPJLinkRequestOperation* operation, NSString* responseBody, NSArray* parsedResponses) {
                                           // Send the request-did-end notification
                                           [self postRequestDidEndNotificationWithError:nil];
                                           // Update the connection state
                                           [self updateConnectionStatePostRequestWithError:nil];
                                           // Process the responses
                                           [self handleResponses:parsedResponses];
                                       }
                                       failure:^(AFPJLinkRequestOperation* operation, NSError* error) {
                                           // Send the request-did-end notification
                                           [self postRequestDidEndNotificationWithError:error];
                                           // Update the connection state
                                           [self updateConnectionStatePostRequestWithError:error];
                                       }];
    }
}

- (NSString*)muteCommandBodyForType:(PJMuteType)type state:(BOOL)muteOn {
    NSString* ret = nil;

    NSString* muteTypeStr = nil;
    switch (type) {
        case PJMuteTypeVideo:         muteTypeStr = @"1"; break;
        case PJMuteTypeAudio:         muteTypeStr = @"2"; break;
        case PJMuteTypeAudioAndVideo: muteTypeStr = @"3"; break;
    }
    if (muteTypeStr != nil) {
        ret = [NSString stringWithFormat:@"AVMT %@%u\rAVMT ?\r", muteTypeStr, (muteOn ? 1 : 0)];
    }

    return ret;
}

- (void)updateConnectionStatePreRequest {
    // If we are already connected, then we will assume we stay connected.
    // If we are not already connected, then we will change state to connecting.
    if (self.connectionState != PJConnectionStateConnected) {
        self.connectionState = PJConnectionStateConnecting;
    }
}

- (void)updateConnectionStatePostRequestWithError:(NSError*)error {
    PJConnectionState connectionState = self.connectionState;

    if (error != nil) {
        // We had an error. If it is a password error, then we
        // set ourselves into the password error connection state.
        // This tells observers that we need to provide a password.
        // Otherwise, we go to the connection error connection state.
        if ([error.domain isEqualToString:PJLinkErrorDomain]) {
            if (error.code == PJLinkErrorNoPasswordProvided) {
                connectionState = PJConnectionStatePasswordError;
            } else {
                connectionState = PJConnectionStateConnectionError;
            }
        } else {
            connectionState = PJConnectionStateConnectionError;
        }
    } else {
        // No error, so we go to the connected state
        connectionState = PJConnectionStateConnected;
    }

    // Assign the state
    self.connectionState = connectionState;
}

- (void)refreshTimerFired:(NSTimer*)timer {
    [self refreshAllQueries];
}

- (void)powerTransitionRefreshTimerFired:(NSTimer*)timer {
    [self refreshPowerStatus];
}

- (void)updatePowerTransitionRefreshTimerStatus {
    if (self.powerStatus == PJPowerStatusStandby ||
        self.powerStatus == PJPowerStatusLampOn) {
        // We need to stop the timer
        [self.powerTransitionRefreshTimer invalidate];
        self.powerTransitionRefreshTimer = nil;
    } else if (self.powerStatus == PJPowerStatusCooling ||
               self.powerStatus == PJPowerStatusWarmUp) {
        [self.powerTransitionRefreshTimer invalidate];
        self.powerTransitionRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:kPowerTransitionRefreshTimerInterval
                                                                            target:self
                                                                          selector:@selector(powerTransitionRefreshTimerFired:)
                                                                          userInfo:nil
                                                                           repeats:YES];
    }
}

+ (NSUInteger)indexOfInput:(PJInputInfo*)inputInfo inInputs:(NSArray*)inputs {
    NSUInteger ret = NSNotFound;

    // We have a match if the input type and input number match
    NSUInteger inputsCount = [inputs count];
    if (inputInfo != nil && inputsCount > 0) {
        for (NSUInteger i = 0; i < inputsCount; i++) {
            PJInputInfo* ithInfo = (PJInputInfo*) [inputs objectAtIndex:i];
            if (ithInfo.inputType   == inputInfo.inputType &&
                ithInfo.inputNumber == inputInfo.inputNumber) {
                ret = i;
                break;
            }
        }
    }

    return ret;
}

- (void)postNotificationOnMainThread:(NSNotification*)notification {
    dispatch_block_t block = ^{
        [[NSNotificationCenter defaultCenter] postNotification:notification];
	};
    // Ensure that we post the notification on the main thread
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)postConnectionStateDidChangeNotification {
    [self postNotificationOnMainThread:[NSNotification notificationWithName:PJProjectorConnectionStateDidChangeNotification object:self]];
}

- (void)postRequestDidBeginNotification {
    [self postNotificationOnMainThread:[NSNotification notificationWithName:PJProjectorRequestDidBeginNotification object:self]];
}

- (void)postRequestDidEndNotificationWithError:(NSError*)error {
    NSDictionary* userInfo = nil;
    if (error != nil) {
        userInfo = @{PJProjectorErrorKey : error};
    }
    [self postNotificationOnMainThread:[NSNotification notificationWithName:PJProjectorRequestDidEndNotification object:self userInfo:userInfo]];
}

- (void)postProjectorDidChangeNotification {
    [self postNotificationOnMainThread:[NSNotification notificationWithName:PJProjectorDidChangeNotification object:self]];
}

@end
