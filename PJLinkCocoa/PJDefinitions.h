//
//  PJDefinitions.h
//  PJController
//
//  Created by Eric Hyche on 12/3/12.
//  Copyright (c) 2012 Eric Hyche. All rights reserved.
//

typedef NS_ENUM(NSInteger, PJCommand)
{
    PJCommandPower,
    PJCommandInput,
    PJCommandAVMute,
    PJCommandErrorQuery,
    PJCommandLampQuery,
    PJCommandInputListQuery,
    PJCommandProjectorNameQuery,
    PJCommandManufacturerNameQuery,
    PJCommandProductNameQuery,
    PJCommandOtherInfoQuery,
    PJCommandClassInfoQuery,
    NumPJCommands
};

typedef NS_ENUM(NSInteger, PJPowerStatus)
{
    PJPowerStatusStandby,
    PJPowerStatusLampOn,
    PJPowerStatusCooling,
    PJPowerStatusWarmUp,
    NumPJPowerStatuses
};

typedef NS_ENUM(NSInteger, PJError)
{
    PJErrorOK,
    PJErrorUndefinedCommand,
    PJErrorBadParameter,
    PJErrorCommandUnavailable,
    PJErrorProjectorFailure,
    NumPJErrors
};

typedef NS_ENUM(NSInteger, PJInputType)
{
    PJInputTypeInvalid = 0,
    PJInputTypeRGB     = 1,
    PJInputTypeVideo   = 2,
    PJInputTypeDigital = 3,
    PJInputTypeStorage = 4,
    PJInputTypeNetwork = 5,
    NumPJInputTypes    = 6
};

typedef NS_ENUM(NSInteger, PJMuteType)
{
    PJMuteTypeVideo         = 1,
    PJMuteTypeAudio         = 2,
    PJMuteTypeAudioAndVideo = PJMuteTypeAudio | PJMuteTypeVideo
};

typedef NS_ENUM(NSInteger, PJErrorStatus)
{
    PJErrorStatusNoError,
    PJErrorStatusWarning,
    PJErrorStatusError,
    NumPJErrorStatuses
};

typedef NS_ENUM(NSInteger, PJConnectionState)
{
    PJConnectionStateDiscovered,       // Initial state - No PJLink network connections attempted yet
    PJConnectionStateConnecting,       // First PJLink network connection attempt is in progress
    PJConnectionStatePasswordError,    // First PJLink network connection attempt resulted in password failure
    PJConnectionStateConnectionError,  // First PJLink network connection attempt resulted in network error other than password
    PJConnectionStateConnected,        // First and subsequent PJLink network connection attempts succeeded
    NumPJConnectionStates
};

typedef NS_ENUM(NSInteger, PJRefreshReason)
{
    PJRefreshReasonUnknown,
    PJRefreshReasonTimed,
    PJRefreshReasonAppStateChange,
    PJRefreshReasonProjectorCreation,
    PJRefreshReasonUserInteraction,
    PJRefreshReasonCount
};

#define kDefaultPJLinkPort 4352

