//
//  PJTableViewController.m
//  PJLinkCocoaExample
//
//  Created by Eric Hyche on 12/29/13.
//  Copyright (c) 2013 Eric Hyche. All rights reserved.
//

#import "PJTableViewController.h"
#import "PJProjector.h"
#import "PJResponseInfo.h"
#import "PJInputInfo.h"

/*
 *  Projector
 *
 *  Host            127.0.0.1
 *  Port                 4352
 *  Connection     Discovered
 *
 *  Status
 *
 *  Power            Stand By
 *  Audio Mute       UISwitch
 *  Video Mute       UISwitch
 *
 *  Inputs
 *
 *  RGB 1
 *  RGB 2                   x
 *  RGB 3
 *  Video 1
 *  Video 2
 *  Digital 1
 *
 *  Error
 *
 *  Fan                    OK
 *  Lamp                   OK
 *  Temperature            OK
 *  Cover Open             OK
 *  Filter                 OK
 *  Other                  OK
 *
 *  Info
 *
 *  Projector          <Data>
 *  Manufacturer       <Data>
 *  Product            <Data>
 *  Other              <Data>
 *
 */

@interface PJTableViewController () <UITextFieldDelegate>

@property(nonatomic,strong) UITextField*             hostTextField;
@property(nonatomic,strong) UITextField*             portTextField;
@property(nonatomic,strong) UISwitch*                audioMuteSwitch;
@property(nonatomic,strong) UISwitch*                videoMuteSwitch;
@property(nonatomic,strong) PJProjector*             projector;
@property(nonatomic,strong) UIBarButtonItem*         refreshBarButtonItem;
@property(nonatomic,strong) UIActivityIndicatorView* spinner;
@property(nonatomic,strong) UIBarButtonItem*         spinnerBarButtonItem;

@end

@implementation PJTableViewController

- (void)dealloc {
    [self unsubscribeFromNotifications];
}

- (void)awakeFromNib {
    NSLog(@"awakeFromNib");
    [self commonInit];
}

- (id)init {
    return [self initWithStyle:UITableViewStyleGrouped];
}

- (id)initWithStyle:(UITableViewStyle)style
{
    NSLog(@"initWithStyle");
    self = [super initWithStyle:style];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    NSLog(@"commonInit");
    _hostTextField   = [[UITextField alloc] init];
    _portTextField   = [[UITextField alloc] init];
    _hostTextField.textAlignment = NSTextAlignmentRight;
    _portTextField.textAlignment = NSTextAlignmentRight;
    _hostTextField.delegate = self;
    _portTextField.delegate = self;
    _hostTextField.text = @"888.888.888.888";
    _portTextField.text = @"99999";
    [_hostTextField sizeToFit];
    [_portTextField sizeToFit];
    _hostTextField.text = @"127.0.0.1";
    _portTextField.text = [[NSNumber numberWithInteger:kDefaultPJLinkPort] stringValue];
    _audioMuteSwitch = [[UISwitch alloc] init];
    _videoMuteSwitch = [[UISwitch alloc] init];
    [_audioMuteSwitch sizeToFit];
    [_videoMuteSwitch sizeToFit];
    [_audioMuteSwitch addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
    [_videoMuteSwitch addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
    _projector       = [[PJProjector alloc] initWithHost:@"127.0.0.1"];
    _refreshBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                          target:self
                                                                          action:@selector(refreshButtonTapped:)];
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spinnerBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_spinner];
    self.navigationItem.rightBarButtonItem = self.refreshBarButtonItem;
    self.navigationItem.title = @"PJLinkCocoa";
    [self subscribeToNotifications];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger ret = 0;

    if (section == 0) {
        ret = 3;
    } else if (section == 1) {
        ret = 3;
    } else if (section == 2) {
        ret = [self.projector countOfInputs];
    } else if (section == 3) {
        ret = 6;
    } else if (section == 4) {
        ret = 4;
    }

    return ret;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* CellIDValue1    = @"CellIDValue1";
    static NSString* CellIDTextField = @"CellIDTextField";
    static NSString* CellIDDefault   = @"CellIDDefault";
    static NSString* CellIDSwitch    = @"CellIDSwitch";
    NSString*            cellID    = nil;
    UITableViewCellStyle cellStyle = UITableViewCellStyleDefault;
    if (indexPath.section == 0) {
        if (indexPath.row == 0 || indexPath.row == 1) {
            cellID    = CellIDTextField;
            cellStyle = UITableViewCellStyleDefault;
        } else if (indexPath.row == 2) {
            cellID    = CellIDValue1;
            cellStyle = UITableViewCellStyleValue1;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cellID    = CellIDValue1;
            cellStyle = UITableViewCellStyleValue1;
        } else if (indexPath.row == 1 || indexPath.row == 2) {
            cellID    = CellIDSwitch;
            cellStyle = UITableViewCellStyleDefault;
        }
    } else if (indexPath.section == 2) {
        cellID    = CellIDDefault;
        cellStyle = UITableViewCellStyleDefault;
    } else if (indexPath.section == 3) {
        cellID    = CellIDValue1;
        cellStyle = UITableViewCellStyleValue1;
    } else if (indexPath.section == 4) {
        cellID    = CellIDValue1;
        cellStyle = UITableViewCellStyleValue1;
    }
    // Get the cell
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:cellStyle reuseIdentifier:cellID];
    }
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Host";
            cell.accessoryView  = self.hostTextField;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Port";
            cell.accessoryView  = self.portTextField;
        } else if (indexPath.row == 2) {
            cell.textLabel.text       = @"Connection";
            cell.detailTextLabel.text = [PJProjector stringForConnectionState:self.projector.connectionState];
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text       = @"Power";
            cell.detailTextLabel.text = [PJResponseInfoPowerStatusQuery stringForPowerStatus:self.projector.powerStatus];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Audio Mute";
            self.audioMuteSwitch.on = self.projector.audioMuted;
            cell.accessoryView  = self.audioMuteSwitch;
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Video Mute";
            self.videoMuteSwitch.on = self.projector.videoMuted;
            cell.accessoryView  = self.videoMuteSwitch;
        }
    } else if (indexPath.section == 2) {
        // Get the PJInputInfo for this row
        PJInputInfo* inputInfo = [self.projector objectInInputsAtIndex:indexPath.row];
        cell.textLabel.text = [inputInfo description];
        cell.accessoryType  = (indexPath.row == self.projector.activeInputIndex ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone);
    } else if (indexPath.section == 3) {
        if (indexPath.row == 0) {
            cell.textLabel.text       = @"Fan";
            cell.detailTextLabel.text = [PJResponseInfoErrorStatusQuery stringForErrorStatus:self.projector.fanErrorStatus];
        } else if (indexPath.row == 1) {
            cell.textLabel.text       = @"Lamp";
            cell.detailTextLabel.text = [PJResponseInfoErrorStatusQuery stringForErrorStatus:self.projector.lampErrorStatus];
        } else if (indexPath.row == 2) {
            cell.textLabel.text       = @"Temperature";
            cell.detailTextLabel.text = [PJResponseInfoErrorStatusQuery stringForErrorStatus:self.projector.temperatureErrorStatus];
        } else if (indexPath.row == 3) {
            cell.textLabel.text       = @"Cover Open";
            cell.detailTextLabel.text = [PJResponseInfoErrorStatusQuery stringForErrorStatus:self.projector.coverOpenErrorStatus];
        } else if (indexPath.row == 4) {
            cell.textLabel.text       = @"Filter";
            cell.detailTextLabel.text = [PJResponseInfoErrorStatusQuery stringForErrorStatus:self.projector.filterErrorStatus];
        } else if (indexPath.row == 5) {
            cell.textLabel.text       = @"Other";
            cell.detailTextLabel.text = [PJResponseInfoErrorStatusQuery stringForErrorStatus:self.projector.otherErrorStatus];
        }
    } else if (indexPath.section == 4) {
        if (indexPath.row == 0) {
            cell.textLabel.text       = @"Projector";
            cell.detailTextLabel.text = self.projector.projectorName;
        } else if (indexPath.row == 1) {
            cell.textLabel.text       = @"Manufacturer";
            cell.detailTextLabel.text = self.projector.manufacturerName;
        } else if (indexPath.row == 2) {
            cell.textLabel.text       = @"Product";
            cell.detailTextLabel.text = self.projector.productName;
        } else if (indexPath.row == 3) {
            cell.textLabel.text       = @"Other";
            cell.detailTextLabel.text = self.projector.otherInformation;
        }
    }

    return cell;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString* ret = nil;

    if (section == 0) {
        ret = @"Projector";
    } else if (section == 1) {
        ret = @"Status";
    } else if (section == 2) {
        ret = @"Inputs";
    } else if (section == 3) {
        ret = @"Errors";
    } else if (section == 4) {
        ret = @"Info";
    }
    
    return ret;
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 2) {
        if (indexPath.row != self.projector.activeInputIndex) {
            [self.projector requestInputChangeToInputIndex:indexPath.row];
        }
    }
}

#pragma mark - UITextFieldDelegate methods

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == self.hostTextField) {

    } else if (textField == self.portTextField) {

    }
}

#pragma mark - PJTableViewController private methods

- (void)refreshButtonTapped:(id)sender {
    [self.hostTextField resignFirstResponder];
    [self.portTextField resignFirstResponder];

    NSInteger port = [self.portTextField.text integerValue];
    if (![self.projector.host isEqualToString:self.hostTextField.text] || self.projector.port == port) {
        // Create a new projector object
        self.projector = [[PJProjector alloc] initWithHost:self.hostTextField.text port:port];
    }
    // Refresh all the values
    [self.projector refreshAllQueries];
}

- (void)switchValueChanged:(id)sender {
    if (sender == self.audioMuteSwitch) {
        [self.projector requestMuteStateChange:self.audioMuteSwitch.on forTypes:PJMuteTypeAudio];
    } else if (sender == self.videoMuteSwitch) {
        [self.projector requestMuteStateChange:self.videoMuteSwitch.on forTypes:PJMuteTypeVideo];
    }
}

- (void)subscribeToNotifications {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(projectorRequestDidBegin:)
                               name:PJProjectorRequestDidBeginNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(projectorRequestDidEnd:)
                               name:PJProjectorRequestDidEndNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(projectorDidChange:)
                               name:PJProjectorDidChangeNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(projectorConnectionStateDidChange:)
                               name:PJProjectorConnectionStateDidChangeNotification
                             object:nil];
}

- (void)unsubscribeFromNotifications {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self
                                  name:PJProjectorRequestDidBeginNotification
                                object:nil];
    [notificationCenter removeObserver:self
                                  name:PJProjectorRequestDidEndNotification
                                object:nil];
    [notificationCenter removeObserver:self
                                  name:PJProjectorDidChangeNotification
                                object:nil];
    [notificationCenter removeObserver:self
                                  name:PJProjectorConnectionStateDidChangeNotification
                                object:nil];
}

- (void)projectorRequestDidBegin:(NSNotification*)notification {
    [self.spinner startAnimating];
    self.navigationItem.rightBarButtonItem = self.spinnerBarButtonItem;
}

- (void)projectorRequestDidEnd:(NSNotification*)notification {
    self.navigationItem.rightBarButtonItem = self.refreshBarButtonItem;
    [self.spinner stopAnimating];
}

- (void)projectorDidChange:(NSNotification*)notification {
    // Reload the whole table view
    [self.tableView reloadData];
}

- (void)projectorConnectionStateDidChange:(NSNotification*)notification {
    [self.tableView reloadData];
}

@end
