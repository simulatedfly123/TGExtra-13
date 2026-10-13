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
	
	// Extract Function id 
	int32_t functionID;
	[payload getBytes:&functionID length:4];
	self.functionID = [NSNumber numberWithInt:functionID];
	
	//customLog(@"Function id: %d", functionID);
	
	id(^hooked_block)(NSData *) = ^(NSData *inputData) {
		NSNumber *functionIDNumber = [NSNumber numberWithUnsignedInt:functionID];
		NSData *fuck = [TLParser handleResponse:inputData functionID:functionIDNumber];
		id result;
		if (fuck) {
			result = responseParser(fuck);
		} else {
			result = responseParser(inputData);
		}
		return result;
	};
	
	switch (functionID) {
		case kAccountUpdateOnlineStatus:
		   handleOnlineStatus(self, payload);
		   break;
		case kMessagesSetTypingAction:
		   handleSetTyping(self, payload);
		   break;
		case kMessagesReadHistory:
		   handleMessageReadReceipt(self, payload);
		   break;
		case kStoriesReadStories:
		   handleStoriesReadReceipt(self, payload);
		   break;
		case kGetSponsoredMessages:
		   handleGetSponsoredMessages(self, payload);
		   break;
		case kChannelsReadHistory:
		   handleChannelsReadReceipt(self, payload);
		   break;
		default:
		   break;
		   
	}
	
	NSData *outgoingPayload = payload;
	if (functionID == kAuthSendCode) {
		NSData *patched = patchedSendCodePayload(payload);
		if (patched) {
			outgoingPayload = patched;
		}
	}

	id (^outgoingParser)(NSData *) = responseParser;
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"disableForwardRestriction"]) {
		outgoingParser = hooked_block;
	}

	// Record what the server answered to a login code request; this is the only
	// place the chosen delivery method is visible.
	if (functionID == kAuthSendCode || functionID == kAuthResendCode) {
		id (^wrappedParser)(NSData *) = outgoingParser;
		outgoingParser = ^id(NSData *response) {
			logAuthCodeResponse(functionID, response);
			return wrappedParser(response);
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
%hook MTRequestMessageService

- (void)addRequest:(MTRequest *)request {
    if (request.fakeData) {
        @try {
             if (request.completed) {
                 NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];

                 MTRequestResponseInfo *info = [[%c(MTRequestResponseInfo) alloc] initWithNetworkType:1 
					     timestamp:currentTime 
						  duration:0.045
					   ];
						
						id result = request.responseParser(request.fakeData);
						request.completed(result, info, nil);
             }
         } @catch (NSException *exception) {
             customLog2(@"Exception in MTRequestMessageService hook: %@", exception);
         }
        return;
    }
    %orig;
}

%end
