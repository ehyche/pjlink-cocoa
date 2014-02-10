//
//  PJProjector.h
//  ProjectR
//
//  Created by Eric Hyche on 7/7/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PJDefinitions.h"

// Notification names
extern NSString* const PJProjectorRequestDidBeginNotification;
extern NSString* const PJProjectorRequestDidEndNotification;
extern NSString* const PJProjectorDidChangeNotification;
extern NSString* const PJProjectorConnectionStateDidChangeNotification;
// User Info dictionary key names
extern NSString* const PJProjectorErrorKey;

@class PJInputInfo;

@interface PJProjector : NSObject <NSCoding>

// PJLink properties
@property(nonatomic,assign,readonly)                           PJPowerStatus powerStatus;
@property(nonatomic,assign,readonly,getter=isAudioMuted)       BOOL          audioMuted;
@property(nonatomic,assign,readonly,getter=isVideoMuted)       BOOL          videoMuted;
@property(nonatomic,assign,readonly)                           PJErrorStatus fanErrorStatus;
@property(nonatomic,assign,readonly)                           PJErrorStatus lampErrorStatus;
@property(nonatomic,assign,readonly)                           PJErrorStatus temperatureErrorStatus;
@property(nonatomic,assign,readonly)                           PJErrorStatus coverOpenErrorStatus;
@property(nonatomic,assign,readonly)                           PJErrorStatus filterErrorStatus;
@property(nonatomic,assign,readonly)                           PJErrorStatus otherErrorStatus;
@property(nonatomic,copy,readonly)                             NSArray*      lampStatus; // NSArray of PJLampStatus
@property(nonatomic,copy,readonly)                             NSArray*      inputs;     // NSArray of PJInputInfo
@property(nonatomic,assign,readonly)                           NSUInteger    activeInputIndex; // Which input is active
@property(nonatomic,copy,readonly)                             NSString*     projectorName;
@property(nonatomic,copy,readonly)                             NSString*     manufacturerName;
@property(nonatomic,copy,readonly)                             NSString*     productName;
@property(nonatomic,copy,readonly)                             NSString*     otherInformation;
@property(nonatomic,assign,readonly,getter=isClass2Compatible) BOOL          class2Compatible;
// Oftentimes the user of the projector will not go into
// the projector settings and change the projector name.
// Therefore, many projectors may have the same name
// in their projectorName property if they are projectors
// of the same model. However, the user of the app may want
// to assign an arbitrary name to the projector like
// "Conference Room 4 Left". So that is the purpose
// of the .userDefinedName property. If assigned by
// the user, it will be used for the .displayName.
@property(nonatomic,copy) NSString* userDefinedName;
// This property is intended to be the display name of the projector.
// It is derived from the other properties of the projector:
// 1) If the .userDefinedName is set (i.e. -[NSString length] > 0), then
//    .displayName returns the .userDefinedName.
// 2) If .userDefinedName is not set, then if the .projectorName
//    property is set, then .displayName returns
//    "<.projectorName>@<host>" if .includeHostInDisplayName is YES, and just
//    "<.projectorName>" if .includehostInDisplayName is NO.
// 3) If .projectorName is not set, then .displayName returns
//    "Projector@<host>" if .includeHostInDisplayName is YES, and just
//    "Projector" if .includeHostInDisplayName is NO.
@property(nonatomic,copy,readonly) NSString* displayName;
@property(nonatomic,assign)        BOOL      includeHostInDisplayName;

// This property is used in between the time that requestInputChangeToInputIndex:
// is called and the time the response comes back with a changed input
// index. This property specifies the input index which is being transitioned *to*.
// If there is no input being transitioned to, then this property will be -1.
@property(nonatomic,assign,readonly) NSInteger pendingActiveInputIndex;

// This property is saved from the call to refreshQueries:forReason:.
// This allows the caller, when a connection state change or projection
// change is encountered, to know how to response. For instance,
// if the refresh reason is due to user interaction, then it may
// be appropriate to show an error UIAlertView. However, if the
// refresh was due to a timer, then the caller may want to handle
// that error silently.
@property(nonatomic,assign,readonly) PJRefreshReason lastRefreshReason;

// KVO-compliant accessors for .inputs property
- (NSUInteger)countOfInputs;
- (id)objectInInputsAtIndex:(NSUInteger)index;
- (NSArray*)inputsAtIndexes:(NSIndexSet *)indexes;

// KVO-compliant accessors for .lampStatus property
- (NSUInteger)countOfLampStatus;
- (id)objectInLampStatusAtIndex:(NSUInteger)index;
- (NSArray*)lampStatusAtIndexes:(NSIndexSet *)indexes;

// Host IP address and port
@property(nonatomic,copy,readonly)   NSString* host;
@property(nonatomic,assign,readonly) NSInteger port;

// Optional password
@property(nonatomic,copy) NSString* password;

// Connection state
@property(nonatomic,assign,readonly) PJConnectionState connectionState;

// Refresh timer
@property(nonatomic,assign)                         NSTimeInterval refreshTimerInterval;
@property(nonatomic,assign,getter=isRefreshTimerOn) BOOL           refreshTimerOn;

// Init with just an IP address and optional port
- (id)initWithHost:(NSString*)host;
- (id)initWithHost:(NSString*)host port:(NSInteger)port;

// Refresh the specified queries
- (void)refreshQueries:(NSArray*)queries forReason:(PJRefreshReason)reason;
// Refresh all queries
- (void)refreshAllQueriesForReason:(PJRefreshReason)reason;
// Refresh the power status
- (void)refreshPowerStatusForReason:(PJRefreshReason)reason;
// Refresh the input status
- (void)refreshInputStatusForReason:(PJRefreshReason)reason;
// Refresh the mute status
- (void)refreshMuteStatusForReason:(PJRefreshReason)reason;
// Refresh the status of the queries that
// we can directly set (power, input, mute).
- (void)refreshSettableQueriesForReason:(PJRefreshReason)reason;
// For certain queries, we do not expect them to change very
// often. For instance, we do not expect the product name or the manufacturer
// name to change much, if ever. These queries can be refreshed
// very infrequently.
- (void)refreshQueriesWeExpectToChangeForReason:(PJRefreshReason)reason;

// Turn the projector on or off. This method returns YES
// if the we initiated a state change, and NO if we
// did not. We may have not initiated a state change
// if the current state was not compatible with the
// change. For instance, if the power status was
// warming up, then the projector is being turned on
// already, so we would not do anything in that case.
- (BOOL)requestPowerStateChange:(BOOL)powerOn;

// Change the mute state of audio, video, or both.
// If the projector is already in the requested mute
// state, then no request is made and this method
// returns NO. Otherwise, a request is made and
// the method returns YES.
- (BOOL)requestMuteStateChange:(BOOL)muteOn forTypes:(PJMuteType)type;

// Change the projector input to the input with the specified index.
// This index is an index into the .inputs array.
// If the requested input index is invalid OR the requested
// input is already the active input, then this method
// returns NO, and no input change request is made.
// Otherwise, a request is made to change the input
// and this method returns YES.
- (BOOL)requestInputChangeToInputIndex:(NSUInteger)inputIndex;

// Change the projector input to the specified input type and
// index within that type. For example, if a projector has
// 3 RGB inputs (indices 0, 1, and 2), then this method could be
// used to switch to "RGB 1"; that is the 2nd RGB input.
- (BOOL)requestInputChangeToInputType:(PJInputType)type number:(NSUInteger)number;

// Get a human readable string for connection state
+ (NSString*)stringForConnectionState:(PJConnectionState)state;

@end
