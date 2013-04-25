//
//  PJURLProtocol.m
//  PJController
//
//  Created by Eric Hyche on 12/3/12.
//  Copyright (c) 2012 Eric Hyche. All rights reserved.
//

#import "PJURLProtocol.h"
#import "PJDefinitions.h"
#import "GCDAsyncSocket.h"
#import "NSURLRequest+PJLink.h"
#import "PJRequestInfo.h"
#import "PJResponseInfo.h"
#import "PJURLResponse.h"
#import "NSURL+Utils.h"
#import <CommonCrypto/CommonDigest.h>

#define k_challengeWithAuthentication @"PJLINK 1"
#define k_challengeNoAuthentication   @"PJLINK 0"

#define SOCKET_TAG_READ_PROJECTOR_CHALLENGE 10
#define SOCKET_TAG_READ_COMMAND_RESPONSE    11
#define SOCKET_TAG_WRITE_REQUEST_COMMAND    20

// Our custom PJLink Protocol URLs are of the form:
//
//
// pjlink://username:password@192.168.1.100:4352/
//
// The PJLink category of NSURLRequest contains a
// ".requestCommands" property which contains an array
// of PJRequestInfo objects. These should be executed in
// the order provided and the equivalent response objects
// should be provided for each one.
//

@interface PJURLProtocol() <GCDAsyncSocketDelegate>
{
    NSString*       _password;
    GCDAsyncSocket* _socket;
    NSTimeInterval  _timeout;
    NSString*       _encryptedPassword;
    NSArray*        _requestCommands;
    NSUInteger      _requestCommandIndex;
    NSMutableArray* _responseCommands;
    BOOL            _hasCalledDidFinishWithError;
}

-(NSURL*)         requestURL;
-(NSInteger)      handleProjectorChallenge:(NSData*) data;
-(void)           callClientDidReceiveResponse:(NSURLResponse*) response cacheStoragePolicy:(NSURLCacheStoragePolicy) policy;
-(void)           callClientDidFailWithError:(NSError*) error;
-(void)           callClientDidFinishLoading;
+(NSError*)       pjlinkErrorWithCode:(NSInteger) code;
-(PJRequestInfo*) currentRequestInfo;
-(NSData*)        dataForCurrentRequestInfo;
+(NSArray*)       requestCommandsFromURL:(NSURL*) url;

@end

@implementation PJURLProtocol

-(id) initWithRequest:(NSURLRequest*) request
       cachedResponse:(NSCachedURLResponse*) cachedResponse
               client:(id<NSURLProtocolClient>) client
{
    NSLog(@"PJURLProtocol[%p] initWithRequest:%@ cachedResponse:%@ client:%@", self, request, cachedResponse, client);
    self = [super initWithRequest:request cachedResponse:cachedResponse client:client];
    if (self)
    {
        // Save the timeout
        _timeout = [request timeoutInterval];
        // Get the URL from the request
        NSURL* url = [request URL];
        // Get the password (if there is one)
        _password = [url password];
        // Create the array of PJRequestInfo's from the URL
        _requestCommands = [PJURLProtocol requestCommandsFromURL:url];
        // Create the array of PJResponseInfo's
        _responseCommands = [NSMutableArray array];
    }

    return self;
}

+(BOOL) canInitWithRequest:(NSURLRequest*) request
{
    BOOL bRet = NO;

    // If the scheme of the URL is "pjlink://", then we will handle it
    NSURL* url = [request URL];
    NSString* scheme = [[url scheme] lowercaseString];
    if ([scheme isEqualToString:@"pjlink"])
    {
        bRet = YES;
    }

    NSLog(@"PJURLProtocol canInitWithRequest:%@ returns %u", request, bRet);

    return bRet;
}

+(NSURLRequest*) canonicalRequestForRequest:(NSURLRequest*) request
{
    return request;
}

+(BOOL) requestIsCacheEquivalent:(NSURLRequest*) a toRequest:(NSURLRequest*) b
{
    // Check if the URLs are the same
    NSURL* urlA = [a URL];
    NSURL* urlB = [b URL];
    NSString* urlAStr = [[urlA absoluteString] lowercaseString];
    NSString* urlBStr = [[urlB absoluteString] lowercaseString];
    BOOL bRet = [urlAStr isEqualToString:urlBStr];
    if (bRet)
    {
        // Get their request info arrays
        NSArray* requestCommandsA = [a requestCommands];
        NSArray* requestCommandsB = [b requestCommands];
        // See if these arrays are the same
        bRet = [requestCommandsA isEqualToArray:requestCommandsB];
    }

    NSLog(@"PJURLProtocol requestIsCacheEquivalent:%@ toRequest:%@ returns %u", a, b, bRet);

    return bRet;
}

-(void) startLoading
{
    NSLog(@"PJURLProtocol[%p] startLoading", self);
    // Get the request
    NSURLRequest* request = [self request];
    // Get the URL from the request
    NSURL* url = [request URL];
    // Get the host and port
    NSString* host = [url host];
    // Get the port
    NSNumber* portNum = [url port];
    // Create the socket
    _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    // Get the port number
    uint16_t port16 = [portNum unsignedShortValue];
    // Connect to the host
    NSLog(@"PJURLProtocol[%p] calling connectToHost:%@ onPort:%u withTimeout:%.1f error:",
          self, host, port16, _timeout);
    NSError* error = nil;
    if (![_socket connectToHost:host
                         onPort:port16
                   withTimeout:_timeout
                         error:&error])
    {
        // Create the could not connect error
        NSError* error = [PJURLProtocol pjlinkErrorWithCode:k_PJErrorCouldNotConnect];
        // Call back to the client
        [self callClientDidFailWithError:error];
    }
}

-(void) stopLoading
{
    // Disconnect the socket
    [_socket disconnect];
}

#pragma mark -
#pragma mark GCDAsyncSocketDelegate methods

-(void) socket:(GCDAsyncSocket*) sock didConnectToHost:(NSString*) host port:(UInt16) port
{
    NSLog(@"PJURLProtocol[%p] socket:%@ didConnectToHost:%@ port:%u", self, sock, host, port);
    // We connected, so now we must read the initial response from the projector
    [sock readDataToData:[GCDAsyncSocket CRData]
             withTimeout:_timeout
                     tag:SOCKET_TAG_READ_PROJECTOR_CHALLENGE];
}

-(void) socket:(GCDAsyncSocket*) sock didWriteDataWithTag:(long) tag
{
    NSLog(@"PJURLProtocol[%p] socket:%@ didWriteDataWithTag:%ld", self, sock, tag);
    if (tag == SOCKET_TAG_WRITE_REQUEST_COMMAND)
    {
        // We have written a request. Now we must read the response
        [sock readDataToData:[GCDAsyncSocket CRData]
                 withTimeout:_timeout
                         tag:SOCKET_TAG_READ_COMMAND_RESPONSE];
    }
}

-(void) socket:(GCDAsyncSocket*) sock didReadData:(NSData*) data withTag:(long) tag
{
    NSLog(@"PJURLProtocol[%p] socket:%@ didReadData:withTag:%ld data = %@", self, sock, tag, data);
    // Switch on tag
    NSInteger errorRet = k_PJErrorOK;
    if (tag == SOCKET_TAG_READ_PROJECTOR_CHALLENGE)
    {
        errorRet = [self handleProjectorChallenge:data];
        if (errorRet == k_PJErrorOK)
        {
            // Initialize the request info index
            _requestCommandIndex = 0;
        }
    }
    else if (tag == SOCKET_TAG_READ_COMMAND_RESPONSE)
    {
        // Get the current request info
        PJRequestInfo* currentRequestInfo = [self currentRequestInfo];
        // Create the PJResponseInfo from the data
        PJResponseInfo* responseInfo = [PJResponseInfo infoForResponseData:data fromRequest:currentRequestInfo];
        // Increment the current request info
        _requestCommandIndex++;
        // If we were able to get response info, then
        // add it to the array.
        if (responseInfo != nil)
        {
            [_responseCommands addObject:responseInfo];
        }
    }
    // Were we successful?
    BOOL bDone = NO;
    if (errorRet == k_PJErrorOK)
    {
        // We either have more commands to process or not. If we do,
        // then we will write the data for the next command. If not,
        // then we will close the connection.
        //
        // Get the data for the current request info
        NSData* requestData = [self dataForCurrentRequestInfo];
        if (requestData != nil)
        {
            // Write this request data to the socket
            [sock writeData:requestData
                withTimeout:_timeout
                        tag:SOCKET_TAG_WRITE_REQUEST_COMMAND];
        }
        else
        {
            // Set the flag saying we are done
            bDone = YES;
        }
    }
    if (errorRet != k_PJErrorOK || bDone)
    {
        // Disconnect the socket
        [sock disconnect];
        // Are we done?
        if (bDone)
        {
            // Create the response object
            PJURLResponse* response = [[PJURLResponse alloc] initWithURL:[self requestURL]
                                                               responses:_responseCommands];
            // Call back to the client with the response
            [self callClientDidReceiveResponse:response
                            cacheStoragePolicy:NSURLCacheStorageNotAllowed];
            // Call back to the client saying we are done
            [self callClientDidFinishLoading];
        }
        else
        {
            // Create the error
            NSError* error = [PJURLProtocol pjlinkErrorWithCode:errorRet];
            // Call back to the client with failure
            [self callClientDidFailWithError:error];
        }
    }
}

-(void) socketDidDisconnect:(GCDAsyncSocket*) sock withError:(NSError*) err
{
    NSLog(@"PJURLProtocol[%p] socketDidDisconnect:%@ withError:%@", self, sock, err);
    // The socket disconnected from the projector-side, so we must call back to the client
    if (!_hasCalledDidFinishWithError)
    {
        // Call back to the client
        [self callClientDidFailWithError:err];
    }
}

#pragma mark -
#pragma mark PJURLProtocol private methods

-(NSURL*) requestURL
{
    NSURL* ret = nil;

    // Get the request
    NSURLRequest* request = [self request];
    if (request != nil)
    {
        ret = [request URL];
    }

    return ret;
}

-(NSInteger) handleProjectorChallenge:(NSData*) data
{
    NSInteger ret = k_PJErrorUnexpectedResponse;
    
    if (data != nil)
    {
        // Convert to a string
        NSString* challenge = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        // The format of the string is:
        //
        // PJLINK x[ yyyyyyyy]
        //
        // where:
        // x is either 0 (no authentication) or 1 (authentication)
        // yyyyyyyy is a 8-character hex string
        //
        // Get the length of the string
        NSUInteger challengeLength = [challenge length];
        // Make sure we have at least 8 characters
        if (challengeLength >= 8)
        {
            // Get the substring of the first 8 characters
            NSString* challengePrefix = [challenge substringToIndex:8];
            // Determine if we have authentication or not
            if ([challengePrefix isEqualToString:k_challengeWithAuthentication])
            {
                // In this case, we should have at least 17 characters
                if (challengeLength >= 17)
                {
                    // Get the substring of characters [9,16]
                    NSString* randomSequence = [challenge substringWithRange:NSMakeRange(9, 8)];
                    // XXXMEH - for now, we must be provided a password in the URL.
                    // Later we should support the call to the NSURLProtocolClient
                    // URLProtocol:didReceiveAuthenticationChallenge:
                    if ([_password length] > 0)
                    {
                        // Append the two strings
                        NSString* randomPlusPassword = [NSString stringWithFormat:@"%@%@", randomSequence, _password];
                        // Convert the NSString to NSData using UTF8 encoding
                        NSData* randomPlusPasswordUTF8 = [randomPlusPassword dataUsingEncoding:NSUTF8StringEncoding];
                        // Call CC_MD5 to do the hash
                        unsigned char md5Result[CC_MD5_DIGEST_LENGTH];
                        CC_MD5([randomPlusPasswordUTF8 bytes], [randomPlusPasswordUTF8 length], md5Result);
                        // Now copy the md5Result into an NSData
                        NSData* passwordData = [NSData dataWithBytes:md5Result length:CC_MD5_DIGEST_LENGTH];
                        // Create a string from this password data
                        _encryptedPassword = [[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding];
                        // Set the return value saying we successfully handled the challenge
                        ret = k_PJErrorOK;
                    }
                    else
                    {
                        NSLog(@"PJURLProtocol[%p] authentication challenge received, but no password provided in NSURL.", self);
                        ret = k_PJErrorNoPasswordProvided;
                    }
                }
            }
            else if ([challengePrefix isEqualToString:k_challengeNoAuthentication])
            {
                // We have no authentication, so _encryptedPassword stays nil.
                ret = k_PJErrorOK;
            }
        }
    }

    return ret;
}

-(void) callClientDidReceiveResponse:(NSURLResponse*) response cacheStoragePolicy:(NSURLCacheStoragePolicy) policy
{
    // Get the client
    id<NSURLProtocolClient> client = [self client];
    if (client != nil)
    {
        NSLog(@"PJURLProtocol[%p] calling URLProtocol:didReceiveResponse:%@ cacheReponsePolicy:%u",
              self, response, policy);
        [client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:policy];
    }
}

-(void) callClientDidFailWithError:(NSError*) error
{
    // Get the client
    id<NSURLProtocolClient> client = [self client];
    if (client != nil)
    {
        // Set the flag saying we've called didFailWithError:
        _hasCalledDidFinishWithError = YES;
        NSLog(@"PJURLProtocol[%p] calling URLProtocol:didFailWithError:%@", self, error);
        [client URLProtocol:self didFailWithError:error];
    }
}

-(void) callClientDidFinishLoading
{
    // Get the client
    id<NSURLProtocolClient> client = [self client];
    if (client != nil)
    {
        NSLog(@"PJURLProtocol[%p] calling URLProtocolDidFinishLoading:", self);
        [client URLProtocolDidFinishLoading:self];
    }
}

+(NSError*) pjlinkErrorWithCode:(NSInteger) code
{
    NSError* ret = nil;
    
    NSString* localizedDescription = nil;

    switch (code)
    {
        case k_PJErrorCouldNotConnect:
            localizedDescription = @"Could not connect";
            break;
    }
    
    // If we have a localized description, then create a user info dictionary
    NSDictionary* userInfo = nil;
    if (localizedDescription != nil)
    {
        userInfo = @{NSLocalizedDescriptionKey : localizedDescription};
    }

    // Create the NSError
    ret = [NSError errorWithDomain:k_PJErrorDomain code:code userInfo:userInfo];

    return ret;
}

-(PJRequestInfo*) currentRequestInfo
{
    PJRequestInfo* ret = nil;

    // Get the request
    NSURLRequest* request = [self request];
    if (request != nil)
    {
        // Get the request commands
        NSArray* requestCommands = [request requestCommands];
        // Get the number of request commands
        NSUInteger numRequestCommands = [requestCommands count];
        // Make sure we have a valid index
        if (_requestCommandIndex < numRequestCommands)
        {
            // Get the current request command
            ret = [requestCommands objectAtIndex:_requestCommandIndex];
        }
    }

    return ret;
}

-(NSData*) dataForCurrentRequestInfo
{
    NSData* ret = nil;
    
    // Get the current request info
    PJRequestInfo* currentRequestInfo = [self currentRequestInfo];
    if (currentRequestInfo != nil)
    {
        // Is the first request? If so, then we need to
        // set the encrypted password if we have one
        if (_requestCommandIndex == 0)
        {
            currentRequestInfo.encryptedPassword = _encryptedPassword;
        }
        // Get the data for this request
        ret = [currentRequestInfo data];
    }

    return ret;
}

+(NSArray*) requestCommandsFromURL:(NSURL*) url
{
    // Get the dictionary of query parameters
    NSDictionary* queryParams = [url queryParameters];
    // Loop through the dictionary of query parameters
    NSMutableArray* tmp = [NSMutableArray arrayWithCapacity:[queryParams count]];
    for (NSString* queryParamKey in queryParams)
    {
        id queryParamValue = [queryParams objectForKey:queryParamKey];
        // If the value is [NSNull null], then this is a key-only parameter,
        // which means it is a Get operation. If it has both key and value,
        // then it is a Set operation.
        PJRequestInfo* requestInfo = [PJRequestInfo requestInfoFromURLQueryName:queryParamKey
                                                                     queryValue:queryParamValue];
        if (requestInfo != nil)
        {
            // Add this PJRequestInfo to the temporary array
            [tmp addObject:requestInfo];
        }
    }

    return [NSArray arrayWithArray:tmp];
}

@end
