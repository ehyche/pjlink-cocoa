//
//  AFPJLinkRequestOperation.m
//  PJLinkCocoa
//
//  Created by Eric Hyche on 5/5/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "AFPJLinkRequestOperation.h"
#import "PJURLProtocolRunLoop.h"
#import "PJResponseInfo.h"

@interface AFPJLinkRequestOperation()
{
    NSArray* _responses;
}

@property(readwrite,nonatomic,strong) NSRecursiveLock* lock;

@end

@implementation AFPJLinkRequestOperation

- (NSArray*)responses {
    [self.lock lock];
    if (!_responses && [self.responseData length] > 0 && [self isFinished]) {
        // Split up the response string using <CR> as a delimiter
        NSArray* responseComponents = [self.responseString componentsSeparatedByString:kPJLinkCR];
        // Run through the array parsing each one into a PJResponseInfo object
        NSMutableArray* tmp = [NSMutableArray arrayWithCapacity:[responseComponents count]];
        for (NSString* responseComponent in responseComponents) {
            // Make sure these have length > 0
            if ([responseComponent length] > 0) {
                // Parse the response into a PJResponseInfo object
                // We have to check for valid response, since failure
                // to parse could result in a nil return.
                PJResponseInfo* info = [PJResponseInfo infoForResponseStringWithoutHeaderClassTerminator:responseComponent];
                if (info != nil) {
                    [tmp addObject:info];
                }
            }
        }
        // If we have any PJResponseInfo objects, then save them into the instance variable
        if ([tmp count] > 0) {
            _responses = [NSArray arrayWithArray:tmp];
        }
    }
    [self.lock unlock];
    
    return _responses;
}

- (void)setCompletionBlockWithSuccess:(AFPJLinkSuccessBlock)successBlock
                              failure:(AFPJLinkFailureBlock)failureBlock {
    // completionBlock is manually nilled out in AFURLConnectionOperation to break the retain cycle.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    self.completionBlock = ^{
        if (self.error) {
            if (failureBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failureBlock(self, self.error);
                });
            }
        } else {
            if (successBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    successBlock(self, self.responseString, self.responses);
                });
            }
        }
    };
#pragma clang diagnostic pop
}

@end
