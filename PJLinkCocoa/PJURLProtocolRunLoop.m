//
//  PJURLProtocolRunLoop.m
//  PJLinkCocoa
//
//  Created by Eric Hyche on 4/25/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJURLProtocolRunLoop.h"
#import "AsyncSocket.h"
#import <CommonCrypto/CommonDigest.h>

NSString* const kPJLinkScheme      = @"pjlink";
NSString* const kPJLinkPOWR        = @"POWR";
NSString* const kPJLinkINPT        = @"INPT";
NSString* const kPJLinkAVMT        = @"AVMT";
NSString* const kPJLinkERST        = @"ERST";
NSString* const kPJLinkLAMP        = @"LAMP";
NSString* const kPJLinkINST        = @"INST";
NSString* const kPJLinkNAME        = @"NAME";
NSString* const kPJLinkINF1        = @"INF1";
NSString* const kPJLinkINF2        = @"INF2";
NSString* const kPJLinkINFO        = @"INFO";
NSString* const kPJLinkCLSS        = @"CLSS";
NSString* const kPJLinkOK          = @"OK";
NSString* const kPJLinkERR1        = @"ERR1";
NSString* const kPJLinkERR2        = @"ERR2";
NSString* const kPJLinkERR3        = @"ERR3";
NSString* const kPJLinkERR4        = @"ERR4";
NSString* const kPJLinkHeaderClass = @"%1";
NSString* const kPJLinkCR          = @"\r";
NSString* const PJLinkErrorDomain  = @"PJLinkErrorDomain";

NSString* const kPJLinkQuerySuffix     = @" ?";
NSString* const kPJLinkPowerOnSuffix   = @" 1";
NSString* const kPJLinkPowerOffSuffix  = @" 0";
NSString* const kPJLinkSpace           = @" ";
NSString* const kPJLinkAuthChallenge   = @"PJLINK 1";
NSString* const kPJLinkNoAuthChallenge = @"PJLINK 0";
NSString* const kPJLinkAuthError       = @"PJLINK ERRA\r";

const NSInteger kPJLinkTagWriteRequest           = 10;
const NSInteger kPJLinkTagReadProjectorChallenge = 20;
const NSInteger kPJLinkTagReadCommandResponse    = 21;

@interface PJURLProtocolRunLoop() <AsyncSocketDelegate, NSURLAuthenticationChallengeSender>
{
    AsyncSocket*    _socket;
    NSError*        _error;
    NSMutableArray* _requests;
    NSTimeInterval  _timeout;
    BOOL            _usesAuthentication;
    NSString*       _randomSequence;
    NSString*       _password;
    NSInteger       _failureCount;
    NSString*       _hashedPassword;
    NSUInteger      _bytesSent;
    BOOL            _stopLoadingCalled;
}

+ (NSArray*)validPJLinkCommandsFromRequest:(NSURLRequest*)request;
+ (BOOL)isValidPJLinkRequest:(NSString*) reqStr;
+ (NSMutableArray*)pjlinkRequestsFromRequest:(NSURLRequest*)request;
- (void)callClientDidFailWithError:(NSError*) error;
- (void)callClientDidReceiveResponse;
- (void)callClientDidLoadData:(NSData*) data;
- (void)callClientDidFinishLoading;
- (BOOL)handleProjectorChallenge:(NSData*)data error:(NSError**)pError;
- (BOOL)handleCommandResponse:(NSData*)data error:(NSError**)pError;
- (void)sendNextRequest;
- (void)dequeueNextRequest;
- (void)finishDueToNoPassword;
+ (NSString*)hashedPasswordFromRandomSequence:(NSString*) sequence password:(NSString*) password;
- (void)closeSocket;

@end

@implementation PJURLProtocolRunLoop

- (void) dealloc {
    [self closeSocket];
}

#pragma mark -
#pragma mark NSURLProtocol implementation methods

- (id)initWithRequest:(NSURLRequest *)request
       cachedResponse:(NSCachedURLResponse *)cachedResponse
               client:(id <NSURLProtocolClient>)client {
    self = [super initWithRequest:request cachedResponse:cachedResponse client:client];
    if (self) {
        _timeout = [request timeoutInterval];
    }

    NSLog(@"PJURLProtocolRunLoop[%p] initWithRequest:%@ cachedResponse:%@ client:%@", self, request, cachedResponse, client);
    
    return self;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    // In order to be able to init with this request:
    // a) the URL scheme must be "pjlink://"
    // b) there must be at least one valid PJLINK command
    //    in the request body data
    BOOL ret = NO;
    
    NSString* scheme = [[[request URL] scheme] lowercaseString];
    if ([scheme isEqualToString:kPJLinkScheme]) {
        // Get the valid PJLink commands from the request
        NSArray* validCommands = [PJURLProtocolRunLoop validPJLinkCommandsFromRequest:request];
        if ([validCommands count] > 0) {
            ret = YES;
        }
    }

    NSLog(@"PJURLProtocolRunLoop canInitWithRequest:%@ returns %u", request, ret);
    
    return ret;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSString* host       = [[request URL] host];
    NSString* newURLStr  = [NSString stringWithFormat:@"%@://%@", kPJLinkScheme, host];
    NSURL*    newURL     = [NSURL URLWithString:newURLStr];
    NSArray*  commands   = [PJURLProtocolRunLoop validPJLinkCommandsFromRequest:request];
    NSString* commandStr = [commands componentsJoinedByString:kPJLinkCR];
    commandStr           = [commandStr stringByAppendingString:kPJLinkCR];
    NSData*   cmdData    = [commandStr dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableURLRequest* tmp = [NSMutableURLRequest requestWithURL:newURL
                                                       cachePolicy:[request cachePolicy]
                                                   timeoutInterval:[request timeoutInterval]];
    [tmp setHTTPBody:cmdData];

    NSLog(@"PJURLProtocolRunLoop canonicalRequestForRequest:%@ returns %@", request, tmp);
    
    return [tmp copy];
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    // Two requests are cache-equivalent if:
    // a) their URLs are the same; and
    // b) they have the same valid commands
    NSURL*   aURL           = [a URL];
    NSURL*   bURL           = [b URL];
    NSArray* aValidCommands = [PJURLProtocolRunLoop validPJLinkCommandsFromRequest:a];
    NSArray* bValidCommands = [PJURLProtocolRunLoop validPJLinkCommandsFromRequest:b];
    
    BOOL cacheEquivalent = [aURL isEqual:bURL] && [aValidCommands isEqualToArray:bValidCommands];

    NSLog(@"PJURLProtocolRunLoop requestIsCacheEquivalent:%@ toRequest:%@ returns %u", a, b, cacheEquivalent);

    return cacheEquivalent;
}

- (void)startLoading {
    NSLog(@"PJURLProtocolRunLoop[%p]: startLoading", self);
    // Get the PJLink requests
    _requests = [PJURLProtocolRunLoop pjlinkRequestsFromRequest:[self request]];
    // Make sure we actually have some requests - otherwise fail.
    if ([_requests count] > 0) {
        // Clear the flag that says that stop loading was called
        _stopLoadingCalled = NO;
        // Get the request
        NSURLRequest* request = [self request];
        // Get the URL from the request
        NSURL* url = [request URL];
        // Get the host and port
        NSString* host = [url host];
        // Get the port
        NSNumber* portNum = [url port];
        // Get the port number
        uint16_t port16 = [portNum unsignedShortValue];
        // Create the socket
        _socket = [[AsyncSocket alloc] initWithDelegate:self];
        // Connect to the host
        NSLog(@"PJURLProtocolRunLoop[%p] calling socket connectToHost:%@ onPort:%u withTimeout:%.1f error:",
              self, host, port16, _timeout);
        NSError* connectError = nil;
        BOOL connectRet = [_socket connectToHost:host
                                          onPort:port16
                                     withTimeout:_timeout
                                           error:&connectError];
        if (!connectRet)
        {
            // Call back to the client
            [self callClientDidFailWithError:connectError];
        }
    } else {
        // We had no valid requests, so create a "bad request" error
        NSError* error = [NSError errorWithDomain:PJLinkErrorDomain
                                             code:PJLinkErrorNoValidCommandsInRequest
                                         userInfo:@{NSLocalizedDescriptionKey: @"No valid PJlink requests found."}];
        [self callClientDidFailWithError:error];
    }
}

- (void)stopLoading {
    NSLog(@"PJURLProtocolRunLoop[%p]: stopLoading", self);
    // Close the socket
    [self closeSocket];
    // We do not call back to the client after this, as the
    // documentation says that after we receive a stopLoading,
    // we should make no further calls to the NSURLProtocolClient.
    // Setting this flag prevents us from calling the NSURLProtocolClient.
    _stopLoadingCalled = YES;
}

#pragma mark -
#pragma mark NSURLProtocol overridden methods

- (id<NSURLProtocolClient>)client{
    id<NSURLProtocolClient> ret = [super client];

    if (_stopLoadingCalled) {
        ret = nil;
    }

    return ret;
}

#pragma mark -
#pragma mark AsyncSocketDelegate methods

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err {
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocket:%@ willDisconnectWithError:%@", self, sock, err);
    _error = err;
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock {
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocketDidDisconnect:%@", self, sock);
    [[self client] URLProtocol:self didFailWithError:_error];
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocket:%@ didConnectToHost:%@ port:%@", self, sock, host, @(port));
    // Read the initial challenge from the projector
    NSLog(@"PJURLProtocolRunLoop[%p] calling readDataToData:withTimeout:%@ tag:%@",
          self, @(_timeout), @(kPJLinkTagReadProjectorChallenge));
    [_socket readDataToData:[AsyncSocket CRData]
                withTimeout:_timeout
                        tag:kPJLinkTagReadProjectorChallenge];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString* dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocket:%@ didReadData:\"%@\" withTag:%ld", self, sock, dataStr, tag);
    // Switch on tag
    BOOL     handled = YES;
    NSError* error   = nil;
    if (tag == kPJLinkTagReadProjectorChallenge) {
        handled = [self handleProjectorChallenge:data error:&error];
        if (handled) {
            // Are we using authentication?
            if (_usesAuthentication) {
                [self callClientDidReceiveAuthenticationChallenge];
            } else {
                // We are not using authentication, so just send the next request
                [self sendNextRequest];
            }
        }
    } else if (tag == kPJLinkTagReadCommandResponse) {
        handled = [self handleCommandResponse:data error:&error];
    }
    if (!handled) {
        // Close the socket
        [self closeSocket];
        // Call back to the client with an error
        [self callClientDidFailWithError:error];
    }
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocket:%@ didWriteDataWithTag:%@", self, sock, @(tag));
    if (tag == kPJLinkTagWriteRequest) {
        // Read data up to and including the carriage return
        NSLog(@"PJURLProtocolRunLoop[%p] calling readDataToData:withTimeout:%@ tag:%@",
              self, @(_timeout), @(kPJLinkTagReadCommandResponse));
        [_socket readDataToData:[AsyncSocket CRData]
                    withTimeout:_timeout
                            tag:kPJLinkTagReadCommandResponse];
    }
}

- (NSTimeInterval)onSocket:(AsyncSocket *)sock
  shouldTimeoutReadWithTag:(long)tag
                   elapsed:(NSTimeInterval)elapsed
                 bytesDone:(NSUInteger)length {
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocket:%@ shouldTimeoutReadWithTag:%@ elapsed:%@ bytesDone:%@",
          self, sock, @(tag), @(elapsed), @(length));
    return 0.0;
}

- (NSTimeInterval)onSocket:(AsyncSocket *)sock
 shouldTimeoutWriteWithTag:(long)tag
                   elapsed:(NSTimeInterval)elapsed
                 bytesDone:(NSUInteger)length {
    
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocket:%@ shouldTimeoutWriteWithTag:%@ elapsed:%@ bytesDone:%@",
          self, sock, @(tag), @(elapsed), @(length));
    return 0.0;
}

#pragma mark -
#pragma mark NSURLAuthenticationChallengeSender methods

- (void)useCredential:(NSURLCredential *)credential forAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    // We better have a password
    if ([credential hasPassword]) {
        // Get the password
        _password = [[credential password] copy];
        // Compute the hashed password
        _hashedPassword = [PJURLProtocolRunLoop hashedPasswordFromRandomSequence:_randomSequence password:_password];
        // Now that we have a hashed password to try, then send the next request
        [self sendNextRequest];
    } else {
        [self finishDueToNoPassword];
    }
}

- (void)continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self finishDueToNoPassword];
}

- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self finishDueToNoPassword];
}

#pragma mark -
#pragma mark PJURLProtocolRunLoop private methods

+ (NSArray*)validPJLinkCommandsFromRequest:(NSURLRequest*)request {
    NSMutableArray* tmp = [NSMutableArray array];

    NSData* bodyData = [request HTTPBody];
    if ([bodyData length] > 0)
    {
        // Assume the data is UTF8 and get a string from it
        NSString* bodyDataStr = [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding];
        // Split up the string by carriage return
        NSArray* components = [bodyDataStr componentsSeparatedByString:kPJLinkCR];
        for (NSString* component in components) {
            if ([PJURLProtocolRunLoop isValidPJLinkRequest:component]) {
                [tmp addObject:component];
            }
        }
    }
    
    
    return [NSArray arrayWithArray:tmp];
}

+ (BOOL)isValidPJLinkRequest:(NSString*) reqStr {
    // This is from the PJLink spec, but the requests
    // do not have the "%1" at the beginning nor the <CR>
    // at the end. These will be added prior to sending.
    BOOL ret = NO;

    NSUInteger reqStrLen = [reqStr length];

    if (reqStrLen > 4) {
        NSString* command = [reqStr substringToIndex:4];
        NSString* suffix  = [reqStr substringFromIndex:4];
        if ([command isEqualToString:kPJLinkPOWR]) {
            // POWR can be:
            // POWR<SP>?
            // POWR<SP>0
            // POWR<SP>1
            if ([suffix isEqualToString:kPJLinkQuerySuffix]   ||
                [suffix isEqualToString:kPJLinkPowerOnSuffix] ||
                [suffix isEqualToString:kPJLinkPowerOffSuffix]) {
                ret = YES;
            }
        } else if ([command isEqualToString:kPJLinkINPT] ||
                   [command isEqualToString:kPJLinkAVMT]) {
            // INPT can be:
            // INPT<SP>?
            // INPT<SP><x><y>
            // where:
            // <x> = [1,5]
            // <y> = [1,9]
            //
            // AVMT can be:
            // AVMT<SP>?
            // AVMT<SP><x><y>
            // where:
            // <x> = [1,3]
            // <y> = [0,1]
            if ([suffix isEqualToString:kPJLinkQuerySuffix]) {
                ret = YES;
            } else if (reqStrLen == 7) {
                NSString* char4    = [reqStr substringWithRange:NSMakeRange(4, 1)];
                NSString* char5    = [reqStr substringWithRange:NSMakeRange(5, 1)];
                NSString* char6    = [reqStr substringWithRange:NSMakeRange(6, 1)];
                NSInteger char5Int = [char5 integerValue];
                NSInteger char6Int = [char6 integerValue];
                if ([char4 isEqualToString:kPJLinkSpace]) {
                    if ([command isEqualToString:kPJLinkINPT]) {
                        if (char5Int >= 1 && char5Int <= 5 &&
                            char6Int >= 1 && char6Int <= 9) {
                            ret = YES;
                        }
                    } else if ([command isEqualToString:kPJLinkAVMT]) {
                        if (char5Int >= 1 && char5Int <= 3 &&
                            char6Int >= 0 && char6Int <= 1) {
                            ret = YES;
                        }
                    }
                }
            }
        } else if ([command isEqualToString:kPJLinkERST] ||
                   [command isEqualToString:kPJLinkLAMP] ||
                   [command isEqualToString:kPJLinkINST] ||
                   [command isEqualToString:kPJLinkNAME] ||
                   [command isEqualToString:kPJLinkINF1] ||
                   [command isEqualToString:kPJLinkINF2] ||
                   [command isEqualToString:kPJLinkINFO] ||
                   [command isEqualToString:kPJLinkCLSS]) {
            // This all are only GET commands, so the
            // rest of the string better be "<SP>?"
            if ([suffix isEqualToString:kPJLinkQuerySuffix]) {
                ret = YES;
            }
        }
    }

    return ret;
}

+ (NSMutableArray*)pjlinkRequestsFromRequest:(NSURLRequest*)request {
    // Get the array of PJLink commands from the request
    NSArray* commands = [PJURLProtocolRunLoop validPJLinkCommandsFromRequest:request];
    // These commands don't have the %1 at the beginning or the <CR> at the end,
    // so go through these command strings and prepare them for transmission.
    // We do this by:
    // a) Pre-pending the command with %1
    // b) Post-pending the command with \r
    NSMutableArray* tmp = [NSMutableArray arrayWithCapacity:[commands count]];
    for (NSString* command in commands) {
        NSString* requestStr  = [NSString stringWithFormat:@"%%1%@\r", command];
        [tmp addObject:requestStr];
    }

    return tmp;
}

- (void)callClientDidFailWithError:(NSError*) error {
    NSLog(@"PJURLProtocolRunLoop[%p]: calling URLProtocol:didFailWithError:%@", self, error);
    [[self client] URLProtocol:self didFailWithError:error];
}

- (void)callClientDidReceiveResponse {
    // There's really nothing in the response we care about - only the URL
    NSURLResponse* response = [[NSURLResponse alloc] initWithURL:[[self request] URL]
                                                        MIMEType:@"text/plain"
                                           expectedContentLength:0
                                                textEncodingName:nil];
    NSLog(@"PJURLProtocolRunLoop[%p]: calling URLProtocol:didReceiveResponse:%@ cacheStoragePolicy:%u",
          self, response, NSURLCacheStorageNotAllowed);
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)callClientDidLoadData:(NSData*) data {
    NSLog(@"PJURLProtocolRunLoop[%p]: calling URLProtocol:didLoadData:%@", self, data);
    [[self client] URLProtocol:self didLoadData:data];
}

- (void)callClientDidFinishLoading {
    NSLog(@"PJURLProtocolRunLoop[%p]: calling URLProtocol:didFinishLoading", self);
    [[self client] URLProtocolDidFinishLoading:self];
}

- (void)callClientDidReceiveAuthenticationChallenge {
    // Get the URL from the request
    NSURL* url = [[self request] URL];
    // Create the NSURLProtectionSpace object
    NSURLProtectionSpace* protectionSpace = [[NSURLProtectionSpace alloc] initWithHost:[url host]
                                                                                  port:[[url port] integerValue]
                                                                              protocol:kPJLinkScheme
                                                                                 realm:nil
                                                                  authenticationMethod:NSURLAuthenticationMethodHTTPBasic];
    // Create a proposed credential object
    NSURLCredential* proposedCredential = nil;
    // Do we have a previously-supplied failed password?
    if ([_password length] > 0) {
        proposedCredential = [NSURLCredential credentialWithUser:nil
                                                        password:_password
                                                     persistence:NSURLCredentialPersistencePermanent];
    }
    // Create the NSURLAuthenticationChallenge object
    NSURLAuthenticationChallenge* challenge = [[NSURLAuthenticationChallenge alloc] initWithProtectionSpace:protectionSpace
                                                                                         proposedCredential:proposedCredential
                                                                                       previousFailureCount:_failureCount
                                                                                            failureResponse:nil
                                                                                                      error:nil
                                                                                                     sender:self];
    // Call to the protocol client
    NSLog(@"PJURLProtocolRunLoop[%p]: calling URLProtocol:didReceiveAuthenticationChallenge:%@", self, challenge);
    [[self client] URLProtocol:self didReceiveAuthenticationChallenge:challenge];
}

- (BOOL)handleProjectorChallenge:(NSData*)data error:(NSError**)pError {
    BOOL ret = NO;

    NSError* error = nil;
    if ([data length] > 0) {
        // Convert to a string
        NSString* challenge = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        // The format of the string is:
        //
        // PJLINK x[ yyyyyyyy]
        //
        // where:
        // x is either 0 (no authentication) or 1 (authentication)
        // yyyyyyyy is a 8-character hex string (only present if x == 1)
        //
        // Get the length of the string
        NSUInteger challengeLength = [challenge length];
        // Make sure we have at least 8 characters
        if (challengeLength >= 8) {
            // Get the substring of the first 8 characters
            NSString* challengePrefix = [challenge substringToIndex:8];
            // Determine if we have authentication or not
            if ([challengePrefix isEqualToString:kPJLinkAuthChallenge]) {
                // In this case, we should have at least 17 characters
                if (challengeLength >= 17) {
                    // Set the flag saying we will be using authentication
                    _usesAuthentication = YES;
                    // Get the substring of characters [9,16]
                    _randomSequence = [challenge substringWithRange:NSMakeRange(9, 8)];
                    // We handled the auth challenge. Now we will need
                    // to call the client with the authentication challenge
                    // and wait for the response
                    ret = YES;
                } else {
                    // Now enough characters to provide random sequence, so error out
                    error = [NSError errorWithDomain:PJLinkErrorDomain
                                                code:PJLinkErrorInvalidAuthSeed
                                            userInfo:@{NSLocalizedDescriptionKey :
                                                       @"Invalid authentication seed received."}];
                }
            }
            else if ([challengePrefix isEqualToString:kPJLinkNoAuthChallenge]) {
                // Clear the flag saying we use authentication
                _usesAuthentication = NO;
                // The challenge from the projector says there is no
                // authentication, so we successfully handled the challenge
                ret = YES;
            }
        }
    } else {
        error = [NSError errorWithDomain:PJLinkErrorDomain
                                    code:PJLinkErrorNoDataInAuthChallenge
                                userInfo:@{NSLocalizedDescriptionKey :
                                           @"No data received for authentication challenge."}];
    }
    if (!ret && pError != NULL) {
        *pError = error;
    }
    
    return ret;
}

- (BOOL)handleCommandResponse:(NSData*)data error:(NSError**)pError {
    BOOL ret = NO;
    
    NSError* error = nil;
    if ([data length] > 0) {
        // Convert to a string
        NSString* responseStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        // Did we receive an authentication error (i.e. - failed password)?
        if ([responseStr isEqualToString:kPJLinkAuthError]) {
            // Set the flag saying we handled this response
            ret = YES;
            // Increment the password failure count
            _failureCount++;
            // The password we sent did not match, so we need to re-send the auth challenge
            [self callClientDidReceiveAuthenticationChallenge];
        } else {
            // We should have a "%1" at the beginning of the string
            if ([responseStr hasPrefix:kPJLinkHeaderClass]) {
                // Create the substring of everything past the "%1"
                NSString* afterHeaderClass = [responseStr substringFromIndex:2];
                // Convert back to UTF8 data
                NSData* dataAfterHeaderClass = [afterHeaderClass dataUsingEncoding:NSUTF8StringEncoding];
                // If we have not sent any data yet, then send a response
                if (_bytesSent == 0) {
                    [self callClientDidReceiveResponse];
                }
                // Respond back to the protocol client with the data
                [self callClientDidLoadData:dataAfterHeaderClass];
                // Add the amount of data we've sent
                _bytesSent += [dataAfterHeaderClass length];
                // We have successfully send the request at the head of the queue,
                // as well as received the response, so we can remove the request
                // at the head of the queue.
                [self dequeueNextRequest];
                // Send the next request. If we don't have any requests
                // left to send, then this will disconnect the socket
                // and send the finish loading call to the clinet.
                [self sendNextRequest];
                // Set the flag saying we handled the request successfully
                ret = YES;
            } else {
                error = [NSError errorWithDomain:PJLinkErrorDomain
                                            code:PJLinkErrorMissingResponseHeader
                                        userInfo:@{NSLocalizedDescriptionKey :
                                                   @"Expected header and class not found in response."}];
            }
        }
    } else {
        error = [NSError errorWithDomain:PJLinkErrorDomain
                                    code:PJLinkErrorNoDataInResponse
                                userInfo:@{NSLocalizedDescriptionKey :
                                           @"No data received in response."}];
    }
    if (!ret && pError != NULL) {
        *pError = error;
    }
    
    return ret;
}

- (void)sendNextRequest {
    // Do we have any more requests to send?
    if ([_requests count] > 0) {
        // Get the next request. We will not dequeue it yet,
        // since if we get a failed password error, then we
        // may want to try again with the same request.
        NSString* nextRequest = [_requests objectAtIndex:0];
        // If we have a hashed password, then we need to prepend
        // it to the request string
        if ([_hashedPassword length] > 0) {
            nextRequest = [_hashedPassword stringByAppendingString:nextRequest];
        }
        // Encode as UTF8
        NSData* nextRequestData = [nextRequest dataUsingEncoding:NSUTF8StringEncoding];
        // Write the request to the socket
        NSLog(@"PJURLProtocolRunLoop[%p] calling writeData:withTimeout:%@ tag:%@ dataStr=\"%@\"",
              self, @(_timeout), @(kPJLinkTagWriteRequest), nextRequest);
        [_socket writeData:nextRequestData
               withTimeout:_timeout
                       tag:kPJLinkTagWriteRequest];
    }
    else {
        // Close the socket
        [self closeSocket];
        // Call back to the client with did finish loading
        [self callClientDidFinishLoading];
    }
}

- (void)dequeueNextRequest {
    if ([_requests count] > 0) {
        [_requests removeObjectAtIndex:0];
    }
}

- (void)finishDueToNoPassword {
    // We cannot continue without a password, so we disconnect the socket
    [self closeSocket];
    // Create an error
    NSError* error = [NSError errorWithDomain:PJLinkErrorDomain
                                         code:PJLinkErrorNoPasswordProvided
                                     userInfo:@{NSLocalizedDescriptionKey :
                                                @"Authentication required, but no password provided."}];
    // Call back with failure
    [self callClientDidFailWithError:error];
}

+ (NSString*)hashedPasswordFromRandomSequence:(NSString*) sequence password:(NSString*) password {
    // Append the two strings
    NSString* randomPlusPassword = [NSString stringWithFormat:@"%@%@", sequence, password];
    // Convert the NSString to NSData using UTF8 encoding
    NSData* randomPlusPasswordUTF8 = [randomPlusPassword dataUsingEncoding:NSUTF8StringEncoding];
    // Call CC_MD5 to do the hash
    unsigned char md5Result[CC_MD5_DIGEST_LENGTH];
    CC_MD5([randomPlusPasswordUTF8 bytes], (CC_LONG)[randomPlusPasswordUTF8 length], md5Result);
    // Create a hex string from the MD5 data
    NSMutableString* tmpStr = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH];
    for (NSUInteger i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        unsigned char ithChar = md5Result[i];
        [tmpStr appendFormat:@"%02x", ithChar];
    }
    // Create the string to return
    NSString* hashedPassword = [NSString stringWithString:tmpStr];

    return hashedPassword;
}

- (void)closeSocket {
    [_socket setDelegate:nil];
    [_socket disconnect];
    // Don't release, as we may closeSocket in the didReadDataWithTag: callstack
    // and the AsyncSocket still may want to call self after that. We can wait
    // for ARC to release the socket after this object goes away.
//    _socket = nil;
}

@end
