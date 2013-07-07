//
//  PJViewController.m
//  PJLinkCocoaExample
//
//  Created by Eric Hyche on 7/6/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJViewController.h"
#import "AFPJLinkClient.h"

@interface PJViewController ()

@property(nonatomic,strong) AFPJLinkClient* client;

@end

@implementation PJViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Initialize the command text field.
    self.requestTextView.text = @"POWR ?\nINPT ?\nAVMT ?\nERST ?\nLAMP ?\nINST ?\nNAME ?\nINF1 ?\nINF2 ?\nINFO ?\nCLSS ?\n";
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)sendButtonTapped:(id)sender {
    // Remove the keyboard
    if ([self.ipAddressTextField isFirstResponder]) {
        [self.ipAddressTextField resignFirstResponder];
    }
    if ([self.portTextField isFirstResponder]) {
        [self.portTextField resignFirstResponder];
    }
    if ([self.requestTextView isFirstResponder]) {
        [self.requestTextView resignFirstResponder];
    }
    // If the IP address or port changed, then we need to re-create the AFPJLinkClient
    if (self.client == nil ||
        ![self.ipAddressTextField.text isEqualToString:self.client.host] ||
        ![self.portTextField.text isEqualToString:[[NSNumber numberWithInteger:self.client.port] stringValue]]) {
        // Create the new URL
        NSURL* baseURL = [NSURL URLWithString:[NSString stringWithFormat:@"pjlink://%@:%@/", self.ipAddressTextField.text, self.portTextField.text]];
        // Create a new AFPJLinkClient
        self.client = [[AFPJLinkClient alloc] initWithBaseURL:baseURL];
    }
    // Start the activity indicator animating
    [self.responseActivityIndicator startAnimating];
    // The UITextView by default puts in newlines (\n) instead of
    // carriage returns (\r). So we replace all the occurrences
    // of \n with \r.
    NSString* requestText = [self.requestTextView.text stringByReplacingOccurrencesOfString:@"\n" withString:@"\r"];
    // Send the request
    [self.client makeRequestWithBody:requestText
                             success:^(AFPJLinkRequestOperation* operation, NSString* responseBody, NSArray* parsedResponses) {
                                 // Stop animating the activity indicator (this will also hide it)
                                 [self.responseActivityIndicator stopAnimating];
                                 // Put the response body into the response text view
                                 self.responseTextView.text = responseBody;
                             }
                             failure:^(AFPJLinkRequestOperation* operation, NSError* error) {
                                 // Stop animating the activity indicator (this will also hide it)
                                 [self.responseActivityIndicator stopAnimating];
                                 // Throw up an alert view
                                 UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                                     message:[error localizedDescription]
                                                                                    delegate:nil
                                                                           cancelButtonTitle:@"Dismiss"
                                                                           otherButtonTitles:nil];
                                 [alertView show];
                             }];
}

@end
