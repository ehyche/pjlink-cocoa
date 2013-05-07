//
//  AFPJLinkRequestOperation.h
//  PJLinkCocoa
//
//  Created by Eric Hyche on 5/5/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "AFURLConnectionOperation.h"

@interface AFPJLinkRequestOperation : AFURLConnectionOperation

@property(nonatomic,readonly,copy) NSArray* responses; // Array of PJResponseInfo objects

- (void)setCompletionBlockWithSuccess:(void (^)(AFPJLinkRequestOperation* operation, NSString* responseBody, NSArray* parsedResponses))success
                              failure:(void (^)(AFPJLinkRequestOperation* operation, NSError* error))failure;

@end
