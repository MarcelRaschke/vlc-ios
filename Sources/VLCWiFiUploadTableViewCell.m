/*****************************************************************************
 * VLCWiFiUploadTableViewCell.m
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013-2018 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *          Carola Nitz <caro # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCWiFiUploadTableViewCell.h"
#import "Reachability.h"
#import "VLCHTTPUploaderController.h"
#import "VLC-Swift.h"

@interface VLCWiFiUploadTableViewCell()

@property (nonatomic, strong) UISwitch *serverToggle;
@property (nonatomic, strong) Reachability *reachability;

@end

@implementation VLCWiFiUploadTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupReachability];
        [self setupCell];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(netReachabilityChanged) name:kReachabilityChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme) name:kVLCThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [self.reachability stopNotifier];
}

+ (NSString *)cellIdentifier
{
    return @"VLCWiFiUploadTableViewCell";
}

- (void)setupReachability
{
    self.reachability = [Reachability reachabilityForLocalWiFi];
    [self.reachability startNotifier];
}

- (void)setupCell
{
    self.textLabel.text = NSLocalizedString(@"WEBINTF_TITLE", nil);
    self.detailTextLabel.text = NSLocalizedString(@"HTTP_UPLOAD_SERVER_OFF", nil);
    self.detailTextLabel.numberOfLines = 0;

    self.serverToggle = [[UISwitch alloc] init];
    [self.serverToggle addTarget:self action:@selector(toggleHTTPServer) forControlEvents:UIControlEventTouchUpInside];
    self.accessoryView = self.serverToggle;

    self.imageView.image = [UIImage imageNamed:@"WifiIcon"];

    [self updateTheme];
    [self updateHTTPServerAddress];
}

- (void)updateTheme
{
    self.textLabel.textColor = PresentationTheme.current.colors.cellTextColor;
    self.detailTextLabel.textColor = PresentationTheme.current.colors.cellDetailTextColor;
    self.backgroundColor = PresentationTheme.current.colors.background;
}

- (void)netReachabilityChanged
{
    [self updateHTTPServerAddress];
}

- (void)updateHTTPServerAddress
{
    BOOL connectedViaWifi = [[VLCHTTPUploaderController sharedInstance] isReachable];
    self.serverToggle.enabled = connectedViaWifi;

    NSString *uploadText = connectedViaWifi ? [[VLCHTTPUploaderController sharedInstance] httpStatus] : NSLocalizedString(@"HTTP_UPLOAD_NO_CONNECTIVITY", nil);
    self.detailTextLabel.text = uploadText;
    self.serverToggle.on = connectedViaWifi && [VLCHTTPUploaderController sharedInstance].isServerRunning;
    self.selectionStyle = self.serverToggle.isOn ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
}

- (void)toggleHTTPServer
{
    BOOL futureHTTPServerState = ![VLCHTTPUploaderController sharedInstance].isServerRunning ;
    [[NSUserDefaults standardUserDefaults] setBool:futureHTTPServerState forKey:kVLCSettingSaveHTTPUploadServerStatus];
    [[VLCHTTPUploaderController sharedInstance] changeHTTPServerState:futureHTTPServerState];
    [self updateHTTPServerAddress];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self setupCell];
}
@end
