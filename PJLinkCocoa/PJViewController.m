//
//  PJViewController.m
//  PJLinkCocoa
//
//  Created by Eric Hyche on 4/15/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJViewController.h"
#import "AFPJLinkClient.h"

@interface PJViewController ()
{
    AFPJLinkClient* _client;
}

@end

@implementation PJViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)sendButtonTapped:(id)sender {
    // Remove the keyboard
    [self.requestTextView resignFirstResponder];
    // If the IP address or port changed, then we need to re-create the AFPJLinkClient
    if (_client == nil ||
        ![self.ipAddressTextField.text isEqualToString:_client.host] ||
        ![self.portTextField.text isEqualToString:[[NSNumber numberWithInteger:_client.port] stringValue]]) {
        // Create the new URL
        NSURL* baseURL = [NSURL URLWithString:[NSString stringWithFormat:@"pjlink://%@:%@/", self.ipAddressTextField.text, self.portTextField.text]];
        // Create a new AFPJLinkClient
        _client = [[AFPJLinkClient alloc] initWithBaseURL:baseURL];
    }
    // Start the activity indicator animating
    [self.responseActivityIndicator startAnimating];
    // The UITextView by default puts in newlines (\n) instead of
    // carriage returns (\r). So we replace all the occurrences
    // of \n with \r.
    NSString* requestText = [self.requestTextView.text stringByReplacingOccurrencesOfString:@"\n" withString:@"\r"];
    // Send the request
    [_client makeRequestWithBody:requestText
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
