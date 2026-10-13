#import "Headers.h"

#define kChannelsReadHistory -871347913

// initConnection carries the api_id on every connection, and the server
// compares it with the one in auth.sendCode, so both have to agree.
%hook MTApiEnvironment

- (int32_t)apiId {
	int32_t custom = customApiId();
	return custom > 0 ? custom : %orig;
}

%end

%hook MTRequest
%property (nonatomic, strong) NSData *fakeData;
%property (nonatomic, strong) NSNumber *functionID;

- (void)setPayload:(NSData *)payload metadata:(id)metadata shortMetadata:(id)shortMetadata responseParser:(id (^)(NSData *))responseParser {
	int32_t functionID;
	[payload getBytes:&functionID length:4];
	self.functionID = [NSNumber numberWithInt:functionID];

	// Everything that depends on which account is sending waits for addRequest,
	// where the service, and so the account, is known. Login happens before any
	// account exists, so those requests are handled here.
	NSData *outgoingPayload = payload;
	id (^outgoingParser)(NSData *) = responseParser;

	if (functionID == kAuthSendCode || functionID == kAuthResendCode) {
		NSData *patched = (functionID == kAuthSendCode) ? patchedSendCodePayload(payload) : nil;
		if (patched) {
			outgoingPayload = patched;
		}

		// The only place the chosen code delivery method is visible.
		outgoingParser = ^id(NSData *response) {
			logAuthCodeResponse(functionID, response);
			return responseParser(response);
		};
	}

	%orig(outgoingPayload, metadata, shortMetadata, outgoingParser);
}

// Errors never reach the response parser, so they are picked up here: a code
// request that is refused (flood limits, a banned or invalid number) looks the
// same on screen as one that succeeded and delivered nothing.
- (void)setCompleted:(void (^)(id, MTRequestResponseInfo *, MTRpcError *))completed {
	int32_t functionID = self.functionID.intValue;

	if (completed && (functionID == kAuthSendCode || functionID == kAuthResendCode)) {
		void (^wrappedCompleted)(id, MTRequestResponseInfo *, MTRpcError *) = completed;
		%orig(^(id result, MTRequestResponseInfo *info, MTRpcError *error) {
			if (error) {
				logAuthCodeError(functionID, error);
			}
			wrappedCompleted(result, info, error);
		});
		return;
	}

	%orig;
}

%end


// Manager which handles requests
//
// A request reaches the server through the service of one account, so this is
// where per account settings can be applied. The account is identified by the
// auth key of the MTProto connection the service is attached to.

@interface TGExtraWeakBox : NSObject
@property (nonatomic, weak) id object;
@end

@implementation TGExtraWeakBox
@end

%hook MTRequestMessageService
%property (nonatomic, strong) TGExtraWeakBox *tgextraMtProtoBox;
%property (nonatomic, strong) NSString *tgextraAccountKey;

- (void)mtProtoWillAddService:(MTProto *)mtProto {
	TGExtraWeakBox *box = [TGExtraWeakBox new];
	box.object = mtProto;
	self.tgextraMtProtoBox = box;

	%orig;
}

%new
- (NSString *)__tgextra_accountKey {
	NSString *cached = self.tgextraAccountKey;
	if (cached.length > 0) {
		return cached;
	}

	MTProto *mtProto = self.tgextraMtProtoBox.object;
	if (!mtProto) {
		return nil;
	}

	// Missing while an account is still signing in; it is cached once it exists.
	MTDatacenterAuthInfo *authInfo = [mtProto.context authInfoForDatacenterWithId:mtProto.datacenterId
	                                                                    selector:MTDatacenterAuthInfoSelectorPersistentKey];
	if (!authInfo || authInfo.authKeyId == 0) {
		return nil;
	}

	NSString *key = [NSString stringWithFormat:@"%lld", authInfo.authKeyId];
	self.tgextraAccountKey = key;

	return key;
}

- (void)addRequest:(MTRequest *)request {
	NSString *account = [self __tgextra_accountKey];
	int32_t functionID = request.functionID.intValue;

	// Presence is reported for the account in the foreground, which is the one
	// whose settings the menu should show.
	if (functionID == kAccountUpdateOnlineStatus) {
		noteActiveAccount(account);
	}

	switch (functionID) {
		case kAccountUpdateOnlineStatus:
		   handleOnlineStatus(request, request.payload, account);
		   break;
		case kMessagesSetTypingAction:
		   handleSetTyping(request, request.payload, account);
		   break;
		case kMessagesReadHistory:
		   handleMessageReadReceipt(request, request.payload, account);
		   break;
		case kStoriesReadStories:
		   handleStoriesReadReceipt(request, request.payload, account);
		   break;
		case kGetSponsoredMessages:
		   handleGetSponsoredMessages(request, request.payload, account);
		   break;
		case kChannelsReadHistory:
		   handleChannelsReadReceipt(request, request.payload, account);
		   break;
		default:
		   break;
	}

	if (request.fakeData) {
		@try {
			if (request.completed) {
				NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];

				MTRequestResponseInfo *info = [[%c(MTRequestResponseInfo) alloc] initWithNetworkType:1
				                                                                          timestamp:currentTime
				                                                                           duration:0.045];

				id result = request.responseParser(request.fakeData);
				request.completed(result, info, nil);
			}
		} @catch (NSException *exception) {
			customLog2(@"Exception in MTRequestMessageService hook: %@", exception);
		}
		return;
	}

	// Rewriting the payload or the parser needs the account, so it happens here
	// by setting them again; everything else about the request is preserved.
	if (functionID != kAuthSendCode && functionID != kAuthResendCode) {
		NSData *scheduled = scheduledSendPayload(request.payload, account);
		BOOL unwrapProtectedContent = accountBoolForKey(kDisableForwardRestriction, account);

		if (scheduled || unwrapProtectedContent) {
			NSData *payload = scheduled ?: request.payload;
			id (^parser)(NSData *) = request.responseParser;

			if (unwrapProtectedContent) {
				id (^originalParser)(NSData *) = parser;
				NSNumber *functionIDNumber = [NSNumber numberWithInt:functionID];
				parser = ^id(NSData *response) {
					NSData *reparsed = [TLParser handleResponse:response functionID:functionIDNumber];
					return originalParser(reparsed ?: response);
				};
			}

			[request setPayload:payload metadata:request.metadata shortMetadata:request.shortMetadata responseParser:parser];
		}
	}

	%orig;
}

%end
