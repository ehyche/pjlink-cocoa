//
//  PJViewController.h
//  PJLinkCocoa
//
//  Created by Eric Hyche on 4/15/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PJViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *ipAddressTextField;
@property (weak, nonatomic) IBOutlet UITextField *portTextField;
@property (weak, nonatomic) IBOutlet UITextView *requestTextView;
@property (weak, nonatomic) IBOutlet UITextView *responseTextView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *responseActivityIndicator;

- (IBAction)sendButtonTapped:(id)sender;

@end
