//
//  AFPJLinkRequestOperation.h
//  PJLinkCocoa
//
//  Created by Eric Hyche on 5/5/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "AFURLConnectionOperation.h"

@class AFPJLinkRequestOperation;

// Typedef's for the success and failure blocks
typedef void (^AFPJLinkSuccessBlock)(AFPJLinkRequestOperation* operation, NSString* responseBody, NSArray* parsedResponses);
typedef void (^AFPJLinkFailureBlock)(AFPJLinkRequestOperation* operation, NSError* error);


@interface AFPJLinkRequestOperation : AFURLConnectionOperation

@property(nonatomic,readonly,copy) NSArray* responses; // Array of PJResponseInfo objects

- (void)setCompletionBlockWithSuccess:(AFPJLinkSuccessBlock)successBlock
                              failure:(AFPJLinkFailureBlock)failureBlock;

@end
