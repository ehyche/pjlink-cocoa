//
//  PJDefinitions.h
//  PJController
//
//  Created by Eric Hyche on 12/3/12.
//  Copyright (c) 2012 Eric Hyche. All rights reserved.
//

#define k_commandsRequestProperty    @"PJCommands"
#define k_PJCommandTerminator        @"\n"
#define k_PJErrorDomain              @"PJLinkErrorDomain"
#define k_PJErrorOK                  0
#define k_PJErrorCouldNotConnect    -1
#define k_PJErrorUnexpectedResponse -2
#define k_PJErrorNoPasswordProvided -3

typedef enum _PJCommand
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
    PJCommandUnknown
}
PJCommand;

typedef enum _PJPowerStatus
{
    PJPowerStatusStandby,
    PJPowerStatusLampOn,
    PJPowerStatusCooling,
    PJPowerStatusWarmUp,
    NumPJPowerStatuses
}
PJPowerStatus;

typedef enum _PJError
{
    PJErrorOK,
    PJErrorUndefinedCommand,
    PJErrorBadParameter,
    PJErrorCommandUnavailable,
    PJErrorProjectorFailure,
    NumPJErrors
}
PJError;

typedef enum _PJInputType
{
    PJInputTypeRGB     = 1,
    PJInputTypeVideo   = 2,
    PJInputTypeDigital = 3,
    PJInputTypeStorage = 4,
    PJInputTypeNetwork = 5
}
PJInputType;

typedef enum _PJMuteType
{
    PJMuteTypeVideo         = 1,
    PJMuteTypeAudio         = 2,
    PJMuteTypeAudioAndVideo = PJMuteTypeAudio | PJMuteTypeVideo
}
PJMuteType;

typedef enum _PJErrorStatus
{
    PJErrorStatusNoError,
    PJErrorStatusWarning,
    PJErrorStatusError,
    NumPJErrorStatuses
}
PJErrorStatus;

