#import "Headers.h"
#import "UI/Headers.h"
#import <objc/runtime.h>
#import <objc/message.h>

// QR login on the phone number screen
//
// Telegram for iOS can log in with a transfer token, the same way the desktop
// client does, but on iOS the trigger is left as a debug gesture: a single tap
// on the notice text calls -debugQrTap:, which exports the token and draws the
// code. That is impossible to find and easy to miss, so a plain button is added
// to the screen and calls the app's own handler. Nothing about the login itself
// is reimplemented here.
//
// A long press on the same button opens the app's debug menu (ten quick taps on
// the title), which is where logging is turned on.

#define TGEXTRA_QR_BUTTON_TAG 7700001
#define TGEXTRA_QR_CODE_SIDE 200.0
#define TGEXTRA_QR_POLL_ATTEMPTS 20

static NSString *authString(NSString *key, NSString *fallback) {
	NSString *value = [TGExtraLocalization localizedStringForKey:key];
	if (value.length == 0 || [value isEqualToString:key]) {
		return fallback;
	}
	return value;
}

@interface TGExtraAuthNode : NSObject
@property (atomic, assign, readonly) UIView *view;
- (void)__tgextra_installQrButton;
- (void)__tgextra_showQrCode;
- (void)__tgextra_openDebugMenu:(UILongPressGestureRecognizer *)gesture;
- (void)__tgextra_waitForQrCode:(NSNumber *)attempt;
- (void)__tgextra_setButtonTitle:(NSString *)title;
@end

// The app's debug handlers act only on a gesture that has ended, and they are
// called directly here rather than by a real recognizer.
@interface TGExtraEndedTapGesture : UITapGestureRecognizer
@end

@implementation TGExtraEndedTapGesture

- (UIGestureRecognizerState)state {
	return UIGestureRecognizerStateEnded;
}

@end

%hook AuthPhoneEntryNode

- (void)didEnterHierarchy {
	%orig;
	[(TGExtraAuthNode *)self __tgextra_installQrButton];
}

%new
- (void)__tgextra_installQrButton {
	UIView *view = ((TGExtraAuthNode *)self).view;
	if (!view || [view viewWithTag:TGEXTRA_QR_BUTTON_TAG]) {
		return;
	}

	UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
	button.tag = TGEXTRA_QR_BUTTON_TAG;
	button.titleLabel.font = [UIFont systemFontOfSize:14.0];
	button.titleLabel.numberOfLines = 2;
	button.titleLabel.textAlignment = NSTextAlignmentCenter;
	button.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.15];
	button.layer.cornerRadius = 8.0;
	[button setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
	[button setTitle:authString(@"QR_LOGIN_TITLE", @"QR login") forState:UIControlStateNormal];
	[button addTarget:self action:@selector(__tgextra_showQrCode) forControlEvents:UIControlEventTouchUpInside];

	UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(__tgextra_openDebugMenu:)];
	[button addGestureRecognizer:longPress];

	button.translatesAutoresizingMaskIntoConstraints = NO;
	[view addSubview:button];

	// Pinned to the left, below the navigation bar: the screen's own content is
	// centred, so this corner stays clear whatever the layout does.
	[NSLayoutConstraint activateConstraints:@[
		[button.leadingAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.leadingAnchor constant:8.0],
		[button.topAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.topAnchor constant:52.0],
		[button.widthAnchor constraintEqualToConstant:104.0],
		[button.heightAnchor constraintEqualToConstant:40.0]
	]];
}

%new
- (void)__tgextra_showQrCode {
	if (![(NSObject *)self respondsToSelector:@selector(debugQrTap:)]) {
		[(TGExtraAuthNode *)self __tgextra_setButtonTitle:authString(@"QR_LOGIN_UNAVAILABLE", @"No QR login")];
		return;
	}

	TGExtraEndedTapGesture *gesture = [[TGExtraEndedTapGesture alloc] init];
	((void (*)(id, SEL, id))objc_msgSend)(self, @selector(debugQrTap:), gesture);

	[(TGExtraAuthNode *)self __tgextra_waitForQrCode:@(0)];
}

// The code is drawn once the token comes back from the server, so the node it
// lives in only shows up a moment later.
%new
- (void)__tgextra_waitForQrCode:(NSNumber *)attempt {
	UIView *view = ((TGExtraAuthNode *)self).view;
	if (!view) {
		return;
	}

	UIView *codeView = nil;
	for (UIView *candidate in view.subviews.reverseObjectEnumerator) {
		if (candidate.tag == TGEXTRA_QR_BUTTON_TAG) {
			continue;
		}

		if (candidate.bounds.size.width == TGEXTRA_QR_CODE_SIDE && candidate.bounds.size.height == TGEXTRA_QR_CODE_SIDE) {
			codeView = candidate;
			break;
		}
	}

	if (codeView) {
		CGFloat left = floor((view.bounds.size.width - TGEXTRA_QR_CODE_SIDE) / 2.0);
		CGFloat top = view.safeAreaInsets.top + 56.0;
		codeView.frame = CGRectMake(left, top, TGEXTRA_QR_CODE_SIDE, TGEXTRA_QR_CODE_SIDE);
		[view bringSubviewToFront:codeView];
		[(TGExtraAuthNode *)self __tgextra_setButtonTitle:authString(@"QR_LOGIN_SCAN", @"Scan it")];
		return;
	}

	NSInteger next = attempt.integerValue + 1;
	if (next > TGEXTRA_QR_POLL_ATTEMPTS) {
		[(TGExtraAuthNode *)self __tgextra_setButtonTitle:authString(@"QR_LOGIN_FAILED", @"QR failed")];
		return;
	}

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[(TGExtraAuthNode *)self __tgextra_waitForQrCode:@(next)];
	});
}

%new
- (void)__tgextra_setButtonTitle:(NSString *)title {
	UIView *view = ((TGExtraAuthNode *)self).view;
	UIButton *button = (UIButton *)[view viewWithTag:TGEXTRA_QR_BUTTON_TAG];
	if ([button isKindOfClass:[UIButton class]]) {
		[button setTitle:title forState:UIControlStateNormal];
	}
}

%new
- (void)__tgextra_openDebugMenu:(UILongPressGestureRecognizer *)gesture {
	if (gesture.state != UIGestureRecognizerStateBegan) {
		return;
	}

	if (![(NSObject *)self respondsToSelector:@selector(debugTap:)]) {
		return;
	}

	// The app counts ten taps within a short window before it opens the menu.
	TGExtraEndedTapGesture *tap = [[TGExtraEndedTapGesture alloc] init];
	for (int i = 0; i < 10; i++) {
		((void (*)(id, SEL, id))objc_msgSend)(self, @selector(debugTap:), tap);
	}
}

%end

static void initAuthQrLoginHooks(int attempt) {
	Class phoneEntryNode = objc_getClass("AuthorizationUI.AuthorizationSequencePhoneEntryControllerNode");

	if (phoneEntryNode) {
		%init(AuthPhoneEntryNode = phoneEntryNode);
		return;
	}

	// The class lives in a framework that may not be loaded yet.
	if (attempt >= 20) {
		customLog2(@"Could not find the phone entry node, QR login button not installed.");
		return;
	}

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		initAuthQrLoginHooks(attempt + 1);
	});
}

__attribute__((constructor))
static void initAuthQrLogin() {
	dispatch_async(dispatch_get_main_queue(), ^{
		initAuthQrLoginHooks(0);
	});
}
