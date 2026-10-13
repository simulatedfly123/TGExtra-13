#import <UIKit/UIKit.h>
#import "Headers.h"
#import "../Logger/Logger.h"

// Menu Open
@interface ASDisplayNode : NSObject
@property (atomic, assign, readonly) UIView *view;
@property (atomic, copy, readonly) NSArray *subnodes;
@property (atomic, copy, readwrite) NSString *accessibilityLabel;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGesture;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
- (void)__handleSettingsTabLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)__handle5PleTap;
@end

static ThreeFingerGestureHandler *gestureHandler = nil;
static __weak TGLocalization *TGLocalizationShared = nil;

%hook TGLocalization

- (id)initWithVersion:(int)a code:(id)b dict:(id)c isActive:(BOOL)d {
    TGLocalization *instance = %orig;
    if (a != 96929692 && instance) {
        TGLocalizationShared = instance;
    }
    return instance;
}

%end

// Telegram's window routes touches itself: it walks its own subviews but only
// hit-tests the handful of system classes it knows about, and hands everything
// else to its content. A view added to that window is drawn and never touched.
// The launcher button therefore lives in this window, above Telegram's, and
// every point that is not the button is passed down untouched.
@interface TGExtraOverlayWindow : UIWindow
@end

@implementation TGExtraOverlayWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	UIView *result = [super hitTest:point withEvent:event];

	if (result == self) {
		return nil;
	}

	return result;
}

@end

// keyWindow is nil for the first moments of a launch and empty on a scene based
// app until a window is attached, so every window lookup goes through here.
static UIWindow *activeWindow() {
	UIApplication *application = UIApplication.sharedApplication;

	for (UIScene *scene in application.connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) {
			continue;
		}

		UIWindowScene *windowScene = (UIWindowScene *)scene;
		UIWindow *fallback = nil;

		for (UIWindow *candidate in windowScene.windows) {
			if ([candidate isKindOfClass:[TGExtraOverlayWindow class]]) {
				continue; // ours, never the app's own window
			}

			if (candidate.isKeyWindow) {
				return candidate;
			}

			if (!fallback) {
				fallback = candidate;
			}
		}

		if (fallback) {
			return fallback;
		}
	}

	return application.keyWindow;
}

static UIWindowScene *activeWindowScene() {
	NSArray<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes.allObjects;

	for (UIScene *scene in scenes) {
		if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
			return (UIWindowScene *)scene;
		}
	}

	for (UIScene *scene in scenes) {
		if ([scene isKindOfClass:[UIWindowScene class]]) {
			return (UIWindowScene *)scene;
		}
	}

	return nil;
}

void showUI() {
	TGExtra *ui = [TGExtra new];
	UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:ui];

	UIViewController *rootVC = activeWindow().rootViewController;

	// Presenting on a controller that already presents something does nothing,
	// so walk up to whatever is on screen.
	while (rootVC.presentedViewController) {
		rootVC = rootVC.presentedViewController;
	}

	if (rootVC) {
	    [rootVC presentViewController:navVC animated:YES completion:nil];
	}
}

void handleThreeFingerLongPress(UILongPressGestureRecognizer *gesture) {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        showUI();
    }
}

@implementation ThreeFingerGestureHandler
- (void)handleThreeFingerLongPress:(UILongPressGestureRecognizer *)gesture {
    handleThreeFingerLongPress(gesture);
}
@end

// Entry points into the tweak menu
//
// The three finger long press used to be attached once, a second after launch,
// to whatever keyWindow returned - nil that early, which left no way into the
// menu at all. It is now attached as soon as a window exists, re-attached when
// the key window changes, and joined by a draggable button, so the menu is
// reachable without knowing a gesture.

#define TGEXTRA_LAUNCHER_TAG 7700002
#define TGEXTRA_LAUNCHER_SIDE 40.0

@interface TGExtraLauncher : NSObject
+ (instancetype)shared;
- (void)start;
@end

@implementation TGExtraLauncher {
	NSInteger _attempts;
	BOOL _dismissed;
	TGExtraOverlayWindow *_overlayWindow;
}

+ (instancetype)shared {
	static TGExtraLauncher *instance;
	static dispatch_once_t token;
	dispatch_once(&token, ^{
		instance = [[TGExtraLauncher alloc] init];
	});
	return instance;
}

- (void)start {
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(windowBecameKey:)
	                                             name:UIWindowDidBecomeKeyNotification
	                                           object:nil];
	[self attach];

	// The overlay window has to follow rotations and screen size changes, and
	// Telegram can add windows of its own above ours.
	__weak TGExtraLauncher *weakSelf = self;
	[NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *timer) {
		[weakSelf refreshOverlay];
	}];
}

- (void)refreshOverlay {
	if (!_overlayWindow || _dismissed) {
		return;
	}

	UIWindowScene *scene = activeWindowScene();
	CGRect bounds = scene ? scene.coordinateSpace.bounds : UIScreen.mainScreen.bounds;

	if (!CGRectEqualToRect(_overlayWindow.frame, bounds) && bounds.size.width > 0.0) {
		_overlayWindow.frame = bounds;

		UIView *launcher = [_overlayWindow viewWithTag:TGEXTRA_LAUNCHER_TAG];
		CGFloat inset = TGEXTRA_LAUNCHER_SIDE / 2.0;
		launcher.center = CGPointMake(MAX(inset, MIN(bounds.size.width - inset, launcher.center.x)),
		                              MAX(inset + 20.0, MIN(bounds.size.height - inset - 20.0, launcher.center.y)));
	}

	_overlayWindow.windowLevel = UIWindowLevelAlert + 1.0;
}

- (void)windowBecameKey:(NSNotification *)notification {
	[self attachToWindow:notification.object];
}

- (void)attach {
	[self attachToWindow:activeWindow()];

	// Not gated on the app's window: the button only needs a scene.
	[self installOverlay];

	_attempts += 1;
	if (_attempts > 120) {
		return; // a minute of launching is enough; the notification covers the rest
	}

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self attach];
	});
}

- (void)attachToWindow:(UIWindow *)window {
	if (![window isKindOfClass:[UIWindow class]] || _dismissed) {
		return;
	}

	if (!gestureHandler) {
		gestureHandler = [[ThreeFingerGestureHandler alloc] init];
	}

	BOOL hasGesture = NO;
	for (UIGestureRecognizer *recognizer in window.gestureRecognizers) {
		if (recognizer.view == window && [recognizer isKindOfClass:[UILongPressGestureRecognizer class]] && ((UILongPressGestureRecognizer *)recognizer).numberOfTouchesRequired == 3) {
			hasGesture = YES;
			break;
		}
	}

	if (!hasGesture) {
		UILongPressGestureRecognizer *threeFingerLongPress = [[UILongPressGestureRecognizer alloc]
		    initWithTarget:gestureHandler
		    action:@selector(handleThreeFingerLongPress:)];
		threeFingerLongPress.numberOfTouchesRequired = 3;
		threeFingerLongPress.minimumPressDuration = 0.5;
		[window addGestureRecognizer:threeFingerLongPress];
	}

	[self installOverlay];
}

- (void)installOverlay {
	if (_overlayWindow || _dismissed) {
		return;
	}

	// A window has to belong to a scene to be shown at all, so wait for one
	// rather than creating a window that never appears.
	UIWindowScene *scene = activeWindowScene();
	if (!scene) {
		return;
	}

	CGRect bounds = scene.coordinateSpace.bounds;
	if (bounds.size.width <= 0.0) {
		return;
	}

	TGExtraOverlayWindow *overlay = [[TGExtraOverlayWindow alloc] initWithWindowScene:scene];
	overlay.frame = bounds;
	overlay.windowLevel = UIWindowLevelAlert + 1.0;
	overlay.backgroundColor = [UIColor clearColor];
	overlay.opaque = NO;
	overlay.userInteractionEnabled = YES;

	UIButton *launcher = [UIButton buttonWithType:UIButtonTypeCustom];
	launcher.tag = TGEXTRA_LAUNCHER_TAG;
	launcher.frame = CGRectMake(bounds.size.width - TGEXTRA_LAUNCHER_SIDE - 10.0,
	                            floor(bounds.size.height * 0.35),
	                            TGEXTRA_LAUNCHER_SIDE, TGEXTRA_LAUNCHER_SIDE);
	launcher.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.55];
	launcher.layer.cornerRadius = TGEXTRA_LAUNCHER_SIDE / 2.0;
	launcher.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
	launcher.accessibilityLabel = @"TGExtra";
	[launcher setTitle:@"TG" forState:UIControlStateNormal];
	[launcher setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[launcher addTarget:self action:@selector(launcherTapped) forControlEvents:UIControlEventTouchUpInside];

	[launcher addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(launcherDragged:)]];
	[launcher addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(launcherHeld:)]];

	[overlay addSubview:launcher];
	overlay.hidden = NO;

	_overlayWindow = overlay;
}

- (void)launcherTapped {
	// The button floats above the menu it opens, so make a second tap a no-op
	// instead of stacking another copy on top.
	UIViewController *top = activeWindow().rootViewController;
	while (top.presentedViewController) {
		top = top.presentedViewController;
	}

	if ([top isKindOfClass:[UINavigationController class]] &&
	    [[(UINavigationController *)top topViewController] isKindOfClass:[TGExtra class]]) {
		return;
	}

	showUI();
}

- (void)launcherDragged:(UIPanGestureRecognizer *)gesture {
	UIView *launcher = gesture.view;
	UIView *window = launcher.superview;
	if (!window) {
		return;
	}

	CGPoint translation = [gesture translationInView:window];
	CGPoint center = CGPointMake(launcher.center.x + translation.x, launcher.center.y + translation.y);
	CGFloat inset = TGEXTRA_LAUNCHER_SIDE / 2.0;
	center.x = MAX(inset, MIN(window.bounds.size.width - inset, center.x));
	center.y = MAX(inset + 20.0, MIN(window.bounds.size.height - inset - 20.0, center.y));
	launcher.center = center;

	[gesture setTranslation:CGPointZero inView:window];
}

// Held down: out of the way until the next launch. The three finger long press
// still opens the menu.
- (void)launcherHeld:(UILongPressGestureRecognizer *)gesture {
	if (gesture.state != UIGestureRecognizerStateBegan) {
		return;
	}

	_dismissed = YES;
	[gesture.view removeFromSuperview];
}

@end

%hook ASDisplayNode
%property (nonatomic, strong) UILongPressGestureRecognizer *longPressGesture;
%property (nonatomic, strong) UITapGestureRecognizer *tapGesture;

%new
- (void)__handleSettingsTabLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
		showUI();
    }
}

%new
- (void)__handle5PleTap {
	showUI();
}

%end

%hook TabBarNode

- (void)didEnterHierarchy {
	%orig;

	ASDisplayNode *mainNode = self;

    for (ASDisplayNode *child in mainNode.subnodes) {
		NSString *localizedTitle = @"Chats";

		NSString *resultTitle = [TGLocalizationShared get:@"DialogList.TabTitle"];
		if (resultTitle.length > 0 && ![resultTitle isEqualToString:@"DialogList.TabTitle"]) {
			localizedTitle = resultTitle;
		}

        if ([child.accessibilityLabel isEqualToString:localizedTitle]) {

			if (!child.tapGesture) {
				child.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:child action:@selector(__handle5PleTap)];
				child.tapGesture.numberOfTapsRequired = 5;
			}

			if (![child.view.gestureRecognizers containsObject:child.tapGesture]) {
                [child.view addGestureRecognizer:child.tapGesture];
			}
        }
    }
}

%end

%hook PeerInfoScreenItemNode

- (void)didEnterHierarchy {
    %orig;

    ASDisplayNode *mainNode = self;

	if (!mainNode.longPressGesture) {
		 mainNode.longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:mainNode action:@selector(__handleSettingsTabLongPress:)];
	}

    // Check children for specific node
    for (ASDisplayNode *child in mainNode.subnodes) {
        if ([NSStringFromClass([child class]) isEqualToString:@"Display.AccessibilityAreaNode"]) {
			NSString *localizedTitle = @"Telegram Features";

			NSString *resultTitle = [TGLocalizationShared get:@"Settings.Support"];
			if (resultTitle.length > 0 && ![resultTitle isEqualToString:@"Settings.Support"]) {
				localizedTitle = resultTitle;
			}

            if ([child.accessibilityLabel isEqualToString:localizedTitle]) {

				if (![mainNode.view.gestureRecognizers containsObject:mainNode.longPressGesture]) {
					[mainNode.view addGestureRecognizer:mainNode.longPressGesture];
				}
            }
        }
    }
}

%end

__attribute__((constructor))
static void hook() {
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		// Installed first: it must not depend on the class lookups below, which
		// are what break when Telegram renames or moves a node.
		[[TGExtraLauncher shared] start];

		Class tabBarNode = objc_getClass("TabBarUI.TabBarNode");
		Class peerInfoScreenItemNode = objc_getClass("PeerInfoScreen.PeerInfoScreenItemNode");

		if (tabBarNode && peerInfoScreenItemNode) {
			%init(
			    TabBarNode = tabBarNode,
			    PeerInfoScreenItemNode = peerInfoScreenItemNode
			);
		} else {
			customLog2(@"Menu node classes missing (tabBar: %d, peerInfo: %d); using the floating button only.", tabBarNode != Nil, peerInfoScreenItemNode != Nil);
		}
	});
}
