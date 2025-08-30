/*****************************************************************************
 * VLCAppCoordinator.h
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2022-2023 VideoLAN. All rights reserved.
 * $Id$
 *
 * Author: Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_IOS
@class MediaLibraryService;
@class VLCRendererDiscovererManager;
@class VLCMLMedia;
@class VLCStripeController;
#endif
#if TARGET_OS_VISION
@class MediaLibraryService;
@class VLCMLMedia;
@class VLCStripeController;
#endif
#if TARGET_OS_WATCH
@class MediaLibraryService;
@class VLCMLMedia;
#endif

#if !TARGET_OS_WATCH
@class VLCFavoriteService;
@class VLCHTTPUploaderController;
#endif

@interface VLCAppCoordinator : NSObject

+ (nonnull instancetype)sharedInstance;

#if !TARGET_OS_WATCH
@property (readonly) VLCHTTPUploaderController *httpUploaderController;
@property (readonly) VLCFavoriteService *favoriteService;
#endif

#if TARGET_OS_IOS
@property (readonly) MediaLibraryService *mediaLibraryService;
@property (readonly) VLCRendererDiscovererManager *rendererDiscovererManager;
@property (readonly) VLCStripeController *stripeController;

@property (nullable) UIWindow *externalWindow;
@property (retain) UITabBarController *tabBarController;

- (void)handleShortcutItem:(UIApplicationShortcutItem *)shortcutItem;
- (nullable VLCMLMedia *)mediaForUserActivity:(NSUserActivity *)userActivity;
#endif

#if TARGET_OS_VISION
@property (readonly) MediaLibraryService *mediaLibraryService;
@property (readonly) VLCStripeController *stripeController;

@property (nullable) UIWindow *externalWindow;
@property (retain) UITabBarController *tabBarController;

- (void)handleShortcutItem:(UIApplicationShortcutItem *)shortcutItem;
- (nullable VLCMLMedia *)mediaForUserActivity:(NSUserActivity *)userActivity;
#endif

#if TARGET_OS_WATCH
@property (readonly) MediaLibraryService *mediaLibraryService;

- (nullable VLCMLMedia *)mediaForUserActivity:(NSUserActivity *)userActivity;
#endif

@end

NS_ASSUME_NONNULL_END
