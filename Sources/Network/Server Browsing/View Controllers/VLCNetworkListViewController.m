/*****************************************************************************
 * VLCLocalNetworkListViewController
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013-2018 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *          Pierre SAGASPE <pierre.sagaspe # me.com>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCNetworkListViewController.h"
#import "VLCNetworkListCell.h"

#import "VLC-Swift.h"

NSString *VLCNetworkListCellIdentifier = @"VLCNetworkListCellIdentifier";

@interface VLCNetworkListViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UISearchControllerDelegate, UISearchResultsUpdating>
{
    NSMutableArray *_searchData;
    UITapGestureRecognizer *_tapTwiceGestureRecognizer;
    UIActivityIndicatorView *_activityIndicator;
}

@end

@implementation VLCNetworkListViewController

- (void)loadView
{
    CGRect initialRect;
#if TARGET_OS_IOS
    initialRect = [UIScreen mainScreen].bounds;
#else
    initialRect = [[[[UIApplication sharedApplication] delegate] window] bounds];
#endif
    _tableView = [[UITableView alloc] initWithFrame:initialRect style:UITableViewStylePlain];
    _tableView.backgroundColor = PresentationTheme.current.colors.background;
    CGRect frame = _tableView.bounds;
    frame.origin.y = -frame.size.height;
    UIView *topView = [[UIView alloc] initWithFrame:frame];
    topView.backgroundColor = PresentationTheme.current.colors.background;
    [_tableView addSubview:topView];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.opaque = YES;
    _tableView.rowHeight = [VLCNetworkListCell heightOfCell];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.view = _tableView;

#if TARGET_OS_IOS
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
#else
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
#endif
    _activityIndicator.center = _tableView.center;
    _activityIndicator.color = PresentationTheme.current.colors.orangeUI;
    _activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    _activityIndicator.hidesWhenStopped = YES;
    [_activityIndicator startAnimating];
    [self.view addSubview:_activityIndicator];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.tableView.separatorColor = PresentationTheme.current.colors.separatorColor;
    self.view.backgroundColor = PresentationTheme.current.colors.background;

    UINavigationBar *navBar = self.navigationController.navigationBar;
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchController.searchResultsUpdater = self;
    _searchController.delegate = self;
    _searchController.obscuresBackgroundDuringPresentation = NO;

    _searchController.searchBar.delegate = self;
    _searchController.searchBar.barTintColor = navBar.barTintColor;
    _searchController.searchBar.tintColor = navBar.tintColor;
    _searchController.searchBar.translucent = navBar.translucent;
    _searchController.searchBar.opaque = navBar.opaque;
    [_searchController.searchBar sizeToFit];
    if (@available(iOS 11.0 VISIONOS_AVAILABLE, *)) {
        // search bar text field background color
        UITextField *searchTextField = [_searchController.searchBar valueForKey:@"searchField"];
        UIView *backgroundView = searchTextField.subviews.firstObject;
        backgroundView.backgroundColor = UIColor.whiteColor;
        backgroundView.layer.cornerRadius = 10;
        backgroundView.clipsToBounds = YES;

        //_searchController.hidesNavigationBarDuringPresentation = NO;
        _searchController.obscuresBackgroundDuringPresentation = NO;
        self.navigationItem.hidesSearchBarWhenScrolling = YES;
        self.navigationItem.searchController = _searchController;
    } else {
        _tableView.tableHeaderView = _searchController.searchBar;
    }
    self.definesPresentationContext = YES;

    [self addPlayAllAction];

    _searchData = [[NSMutableArray alloc] init];
    [_searchData removeAllObjects];
}

#if TARGET_OS_IOS
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // ensure that the last row is not cut-off on iPad by the tab bar
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && self.tabBarController) {
        UIEdgeInsets contentInsets = UIEdgeInsetsZero;
        contentInsets.bottom += self.tabBarController.tabBar.frame.size.height;

        self.tableView.contentInset = contentInsets;
        self.tableView.scrollIndicatorInsets = contentInsets;
    }
}
#endif

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (@available(iOS 11.0 VISIONOS_AVAILABLE, *)) {
        //iOS 11
    } else {
        CGPoint contentOffset = CGPointMake(0, _tableView.tableHeaderView.bounds.size.height);
        [self.tableView setContentOffset:contentOffset animated:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (self.isEditing)
        [self setEditing:NO animated:YES];
}

#if TARGET_OS_IOS
- (BOOL)shouldAutorotate
{
    UIInterfaceOrientation toInterfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
        return NO;
    return YES;
}
#endif

- (IBAction)playAllAction:(id)sender
{
    // to be implemented by subclass
}

- (void)startActivityIndicator
{
    [_activityIndicator startAnimating];
}

- (void)stopActivityIndicator
{
    [_activityIndicator stopAnimating];
}

- (void)addPlayAllAction
{
    self.navigationItem.rightBarButtonItems = @[[UIBarButtonItem themedPlayAllButtonWithTarget:self andSelector:@selector(playAllAction:)]];
}

- (void)removePlayAllAction
{
    self.navigationItem.rightBarButtonItems = @[];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(VLCNetworkListCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath row] == ((NSIndexPath *)[[tableView indexPathsForVisibleRows] lastObject]).row)
        [_activityIndicator stopAnimating];
}

#pragma mark - Search Controller Delegate

- (void)willPresentSearchController:(UISearchController *)searchController
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        _tableView.rowHeight = 80.0f;
    else
        _tableView.rowHeight = 68.0f;

    _tableView.backgroundColor = PresentationTheme.current.colors.background;
}

#pragma mark - Search Research Updater

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
}

@end
