//
//  PJURLProtocolRunLoop.m
//  PJLinkCocoa
//
//  Created by Eric Hyche on 4/25/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJURLProtocolRunLoop.h"

NSString* const kPJLinkScheme = @"pjlink";
NSString* const kPJLinkPOWR   = @"POWR";
NSString* const kPJLinkINPT   = @"INPT";
NSString* const kPJLinkAVMT   = @"AVMT";
NSString* const kPJLinkERST   = @"ERST";
NSString* const kPJLinkLAMP   = @"LAMP";
NSString* const kPJLinkINST   = @"INST";
NSString* const kPJLinkNAME   = @"NAME";
NSString* const kPJLinkINF1   = @"INF1";
NSString* const kPJLinkINF2   = @"INF2";
NSString* const kPJLinkINFO   = @"INFO";
NSString* const kPJLinkCLSS   = @"CLSS";

NSString* const kPJLinkQuerySuffix    = @" ?";
NSString* const kPJLinkPowerOnSuffix  = @" 1";
NSString* const kPJLinkPowerOffSuffix = @" 0";
NSString* const kPJLinkSpace          = @" ";
NSString* const kPJLinkCR             = @"\r";

@interface PJURLProtocolRunLoop()
{
    AsyncSocket* _socket;
    NSError*     _error;
}

+ (NSArray*)validPJLinkCommandsFromRequest:(NSURLRequest*)request;
+ (BOOL)isValidPJLinkRequest:(NSString*) reqStr;
- (void)callClientDidFailWithError:(NSError*) error;
- (void)callClientDidReceiveResponse:(NSURLResponse*) response;
- (void)callClientDidLoadData:(NSData*) data;
- (void)callClientDidFinishLoading;

@end

@implementation PJURLProtocolRunLoop

#pragma mark -
#pragma mark NSURLProtocol implementation methods

- (id)initWithRequest:(NSURLRequest *)request
       cachedResponse:(NSCachedURLResponse *)cachedResponse
               client:(id <NSURLProtocolClient>)client {
    self = [super initWithRequest:request cachedResponse:cachedResponse client:client];
    if (self) {
    }

    NSLog(@"PJURLProtocolRunLoop[%p] initWithRequest:%@ cachedResponse:%@ client:%@", self, request, cachedResponse, client);
    
    return self;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSLog(@"PJURLProtocolRunLoop canInitWithRequest:%@", request);
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
    
}

- (void)stopLoading {
    NSLog(@"PJURLProtocolRunLoop[%p]: stopLoading", self);
    
}

#pragma mark -
#pragma mark AsyncSocketDelegate methods

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err {
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocket:%@ willDisconnectWithError:%@", self, sock, err);
    _error = err;
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock {
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocketDidDisconnect:%@", self, sock);
    if (_error) {
        [[self client] URLProtocol:self didFailWithError:_error];
    } else {
        [[self client] URLProtocolDidFinishLoading:self];
    }
}

- (BOOL)onSocketWillConnect:(AsyncSocket *)sock {
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocketWillConnect:%@", self, sock);
    return YES;
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocket:%@ didConnectToHost:%@ port:%u", self, sock, host, port);
    
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocket:%@ didReadData:%@ withTag:%ld", self, sock, data, tag);
    
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocket:%@ didWriteDataWithTag:%ld", self, sock, tag);
    
}

- (NSTimeInterval)onSocket:(AsyncSocket *)sock
  shouldTimeoutReadWithTag:(long)tag
                   elapsed:(NSTimeInterval)elapsed
                 bytesDone:(NSUInteger)length {
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocket:%@ shouldTimeoutReadWithTag:%ld elapsed:%.1f bytesDone:%u",
          self, sock, tag, elapsed, length);
    return 0.0;
}

- (NSTimeInterval)onSocket:(AsyncSocket *)sock
 shouldTimeoutWriteWithTag:(long)tag
                   elapsed:(NSTimeInterval)elapsed
                 bytesDone:(NSUInteger)length {
    
    NSLog(@"PJURLProtocolRunLoop[%p]: onSocket:%@ shouldTimeoutWriteWithTag:%ld elapsed:%.1f bytesDone:%u",
          self, sock, tag, elapsed, length);
    return 0.0;
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

- (void)callClientDidFailWithError:(NSError*) error {
    NSLog(@"PJURLProtocolRunLoop[%p]: URLProtocol:didFailWithError:%@", self, error);
    [[self client] URLProtocol:self didFailWithError:error];
}

- (void)callClientDidReceiveResponse:(NSURLResponse*) response {
    NSLog(@"PJURLProtocolRunLoop[%p]: URLProtocol:didReceiveResponse:%@ cacheStoragePolicy:%u",
          self, response, NSURLCacheStorageNotAllowed);
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)callClientDidLoadData:(NSData*) data {
    NSLog(@"PJURLProtocolRunLoop[%p]: URLProtocol:didLoadData:%@", self, data);
    [[self client] URLProtocol:self didLoadData:data];
}

- (void)callClientDidFinishLoading {
    NSLog(@"PJURLProtocolRunLoop[%p]: URLProtocol:didFinishLoading", self);
    [[self client] URLProtocolDidFinishLoading:self];
}

@end
