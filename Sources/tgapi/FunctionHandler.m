#import "Headers.h"

NSData *boolTrue() {
    uint8_t bytes[] = {0xB5, 0x75, 0x72, 0x99}; // boolTrue#997275b5
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

NSData *boolFalse() {
    uint8_t bytes[] = {0x37, 0x97, 0x79, 0xBC}; // boolFalse#bc799737
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

// Handlers
void handleOnlineStatus(MTRequest *request, NSData *payload) {
	
	NSData *isOfflineData = [payload subdataWithRange:NSMakeRange(payload.length - 4, 4)];
	uint32_t isOffline = 0;
	[isOfflineData getBytes:&isOffline length:4];
	
	if (isOffline == 3162085175) { // Online (BOOL false)
		if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableOnlineStatus]) {
			request.fakeData = boolTrue();
		}
	}
	
}

void read_Input_Peer(NSData *data, int *offset) {
	#define InputPeerEmpty 2134579434
	#define InputPeerSelf 2107670217
	#define InputPeerChat 900291769
	#define InputPeerUser -571955892
	#define InputPeerChannel 666680316
	#define InputPeerUserFromChannel -1468331492
	#define InputPeerChannelFromMessage -1121318848
	
	int32_t peerConstructorID = 0;
	[data getBytes:&peerConstructorID range:NSMakeRange(*offset, 4)];
	*offset += 4;
	
	switch (peerConstructorID) {
		case InputPeerEmpty:
		    return;
		case InputPeerSelf:
		    return;
		case InputPeerChat:
		    *offset += 8;
			return;
		case InputPeerUser:
		    *offset += 16;
			return;
		case InputPeerChannel:
		    *offset += 16;
			return;
		case InputPeerUserFromChannel:
		    read_Input_Peer(data, offset);
		    *offset += 12;
			return;
		case InputPeerChannelFromMessage:
		    read_Input_Peer(data, offset);
		    *offset += 12;
			return;
		default :
		    return;
	}
}

void handleSetTyping(MTRequest *request, NSData *payload) {
	
	int offset = 0; 
	offset += 4; // Skip First 4 Bytes of constructor id;
	int32_t flags = 0;
	[payload getBytes:&flags range:NSMakeRange(offset, 4)];
	offset += 4;
	
	read_Input_Peer(payload, &offset); // Read Peer
	
	if ((flags & (1 << 0)) != 0) {
		offset += 4; // Topic id
	}
	
	int32_t actionID = 0;
	[payload getBytes:&actionID range:NSMakeRange(offset, 4)];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	bool shouldBlockAction = false;
	
	//customLog(@"Handle Set Typing action : %d actionData:%@", actionID, [payload description]);
	switch (actionID) {
		case kActionIDTyping:
		shouldBlockAction = [defaults boolForKey:kDisableTypingStatus];
		  break;
		case kActionIDRecordingVideo:
		  shouldBlockAction = [defaults boolForKey:kDisableRecordingVideoStatus];
		  break;
		case kActionIDUploadingVideo:
		  shouldBlockAction = [defaults boolForKey:kDisableUploadingVideoStatus];
		  break;
		case kActionIDRecordingAudio:
		  shouldBlockAction = [defaults boolForKey:kDisableRecordingVoiceStatus];
		  break;
		case kActionIDUploadingVoice:
		  shouldBlockAction = [defaults boolForKey:kDisableUploadingVoiceStatus];
		  break;
		case kActionIDUploadingPhoto:
		  shouldBlockAction = [defaults boolForKey:kDisableUploadingPhotoStatus];
		  break;
		case kActionIDUploadingFile:
		  shouldBlockAction = [defaults boolForKey:kDisableUploadingFileStatus];
		  break;
		case kActionIDChoosingLocation:
		  shouldBlockAction = [defaults boolForKey:kDisableChoosingLocationStatus];
		  break;
		case kActionIDChoosingContact:
		  shouldBlockAction = [defaults boolForKey:kDisableChoosingContactStatus];
		  break;
		case kActionIDPlayingGame:
		  shouldBlockAction = [defaults boolForKey:kDisablePlayingGameStatus];
		  break;
		case kActionIDRecordingRoundVideo:
		  shouldBlockAction = [defaults boolForKey:kDisableRecordingRoundVideoStatus];
		  break;
		case kActionIDUploadingRoundVideo:
		  shouldBlockAction = [defaults boolForKey:kDisableUploadingRoundVideoStatus];
		  break;
		case kActionIDSpeakingInGroupCall:
		  shouldBlockAction = [defaults boolForKey:kDisableSpeakingInGroupCallStatus];
		  break;
		case kActionIDReserverHistoryImport:
		  shouldBlockAction = [defaults boolForKey:@"reserverHistroyImport"];
		  break;
		case kActionIDChoosingSticker:
		  shouldBlockAction = [defaults boolForKey:kDisableChoosingStickerStatus];
		  break;
		case kActionIDEmojiInteraction:
		  shouldBlockAction = [defaults boolForKey:kDisableEmojiInteractionStatus];
		  break;
		case kActionIDEmojiAcknowledgement:
		  shouldBlockAction = [defaults boolForKey:kDisableEmojiAcknowledgementStatus];
		  break;
	}
	
	if (shouldBlockAction) {
		request.fakeData = boolTrue();
	}
}

void handleMessageReadReceipt(MTRequest *request, NSData *payload) {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableMessageReadReceipt]) {
		
		 uint8_t header[] = {0x85, 0x91, 0xD1, 0x84}; // messages.affectedMessages#84d19185
		 int32_t pts = 0;
		 int32_t pts_count = 0;
		 
		 NSMutableData *data = [NSMutableData data];
		 [data appendBytes:&header length:sizeof(header)];
		 [data appendBytes:&pts length:sizeof(pts)];
		 [data appendBytes:&pts_count length:sizeof(pts_count)];
	
		request.fakeData = data;
	}
}

void handleStoriesReadReceipt(MTRequest *request, NSData *payload) {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableStoriesReadReceipt]) {
		
		uint8_t vectorID[] = {0x15, 0xC4, 0xB5, 0x1C}; // vector#1cb5c415
		int32_t count = 0;  
		
		NSMutableData *data = [NSMutableData data];
		[data appendBytes:&vectorID length:sizeof(vectorID)];
		[data appendBytes:&count length:sizeof(count)];
	
		request.fakeData = data;
	}
}

void handleGetSponsoredMessages(MTRequest *request, NSData *payload) {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableAllAds]) {
		
		uint8_t header[] = {0x0F, 0X49, 0X39, 0X18}; // messages.sponsoredMessagesEmpty#1839490f
		request.fakeData = [NSData dataWithBytes:header length:sizeof(header)];
	}
}

void handleChannelsReadReceipt(MTRequest *request, NSData *payload) {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kDisableMessageReadReceipt]) {
		request.fakeData = boolTrue();
	}
}

// Login codes on a re-signed build
//
// auth.sendCode advertises two things the app can only back up with a working
// APNs token: allow_firebase (flag 7) and the token itself (flag 8). When they
// are set, the server may answer with sentCodeTypeFirebaseSms, which expects the
// client to receive a silent push carrying a secret and hand it back through
// auth.requestFirebaseSms before any code is sent. A re-signed build never gets
// that push, so the code is never sent at all. Clearing both flags leaves the
// client reporting what it can actually do, and the server falls back to a plain
// SMS - the same request the app itself sends when iOS gives it no push token.

static BOOL tlReadInt32(NSData *data, NSUInteger *offset, int32_t *value) {
	if (*offset + 4 > data.length) {
		return NO;
	}

	[data getBytes:value range:NSMakeRange(*offset, 4)];
	*offset += 4;
	return YES;
}

// Skips one TL string/bytes field, including its length header and the padding
// that aligns it to a four byte boundary.
static BOOL tlSkipBytes(NSData *data, NSUInteger *offset) {
	if (*offset >= data.length) {
		return NO;
	}

	const uint8_t *bytes = (const uint8_t *)data.bytes;
	NSUInteger headerLength;
	NSUInteger valueLength;

	if (bytes[*offset] <= 253) {
		headerLength = 1;
		valueLength = bytes[*offset];
	} else {
		if (*offset + 4 > data.length) {
			return NO;
		}

		headerLength = 4;
		valueLength = (NSUInteger)bytes[*offset + 1] | ((NSUInteger)bytes[*offset + 2] << 8) | ((NSUInteger)bytes[*offset + 3] << 16);
	}

	NSUInteger total = headerLength + valueLength;
	if (total % 4 != 0) {
		total += 4 - (total % 4);
	}

	if (*offset + total > data.length) {
		return NO;
	}

	*offset += total;
	return YES;
}

// The API credentials registered by the user at my.telegram.org. Telegram's
// public configuration carries api_id 8, which is Telegram's own and is
// published in their repository; their build guide asks every other build to
// register its own, and the server treats requests accordingly.
int32_t customApiId(void) {
	NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:kCustomApiId];
	return (int32_t)value.integerValue;
}

static NSData *customApiHash(void) {
	NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:kCustomApiHash];
	value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	if (value.length == 0) {
		return nil;
	}

	return [value dataUsingEncoding:NSUTF8StringEncoding];
}

// A TL string: length header, bytes, then padding to a four byte boundary. The
// buffer is aligned before the call, so the padding follows from its length.
static void tlAppendBytes(NSMutableData *data, NSData *value) {
	NSUInteger length = value.length;

	if (length >= 254) {
		uint8_t header[4] = {254, (uint8_t)(length & 0xFF), (uint8_t)((length >> 8) & 0xFF), (uint8_t)((length >> 16) & 0xFF)};
		[data appendBytes:header length:4];
	} else {
		uint8_t header = (uint8_t)length;
		[data appendBytes:&header length:1];
	}

	[data appendData:value];

	NSUInteger padding = (4 - (data.length % 4)) % 4;
	if (padding > 0) {
		uint8_t zeros[4] = {0, 0, 0, 0};
		[data appendBytes:zeros length:padding];
	}
}

NSData *patchedSendCodePayload(NSData *payload) {
	BOOL stripPush = [[NSUserDefaults standardUserDefaults] boolForKey:kForceSmsLoginCode];
	int32_t apiId = customApiId();
	NSData *apiHash = customApiHash();

	NSUInteger offset = 0;
	int32_t scratch = 0;

	if (!tlReadInt32(payload, &offset, &scratch) || scratch != kAuthSendCode) {
		return nil;
	}

	if (!tlSkipBytes(payload, &offset)) { // phone_number
		return nil;
	}

	NSUInteger apiIdOffset = offset;
	int32_t currentApiId = 0;
	if (!tlReadInt32(payload, &offset, &currentApiId)) {
		return nil;
	}

	if (!tlSkipBytes(payload, &offset)) { // api_hash
		return nil;
	}

	NSUInteger settingsOffset = offset;

	if (!tlReadInt32(payload, &offset, &scratch) || scratch != kCodeSettings) {
		return nil;
	}

	NSUInteger flagsOffset = offset;
	int32_t flags = 0;
	if (!tlReadInt32(payload, &offset, &flags)) {
		return nil;
	}

	customLog2(@"auth.sendCode: api_id %d, codeSettings flags %d (allow_firebase %d, apns token %d)",
	           currentApiId, flags, (flags & (1 << 7)) ? 1 : 0, (flags & (1 << 8)) ? 1 : 0);

	if ((flags & (1 << 6)) != 0) { // logout_tokens
		int32_t count = 0;
		if (!tlReadInt32(payload, &offset, &scratch) || scratch != kTLVector) {
			return nil;
		}

		if (!tlReadInt32(payload, &offset, &count) || count < 0) {
			return nil;
		}

		for (int32_t i = 0; i < count; i++) {
			if (!tlSkipBytes(payload, &offset)) {
				return nil;
			}
		}
	}

	NSUInteger tokenOffset = offset;

	if ((flags & (1 << 8)) != 0) {
		if (!tlSkipBytes(payload, &offset)) { // token
			return nil;
		}

		if (!tlReadInt32(payload, &offset, &scratch)) { // app_sandbox
			return nil;
		}
	}

	// The push fields are the last of the request, so everything from them
	// onwards can be dropped. Anything trailing means this is not the layout
	// expected here, and a truncated request would be worse than an unchanged one.
	if (offset != payload.length) {
		customLog2(@"auth.sendCode: unexpected layout (%lu of %lu bytes parsed), request sent unchanged",
		           (unsigned long)offset, (unsigned long)payload.length);
		return nil;
	}

	BOOL replaceCredentials = (apiId > 0 && apiHash != nil);
	BOOL hasPushFields = (flags & ((1 << 7) | (1 << 8))) != 0;
	BOOL dropPushFields = (stripPush && hasPushFields);

	if (!replaceCredentials && !dropPushFields) {
		return nil;
	}

	// Rebuilt rather than patched in place: a different api_hash changes the
	// length of everything after it.
	NSMutableData *patched = [NSMutableData data];
	[patched appendData:[payload subdataWithRange:NSMakeRange(0, apiIdOffset)]];

	int32_t outgoingApiId = replaceCredentials ? apiId : currentApiId;
	[patched appendBytes:&outgoingApiId length:4];

	if (replaceCredentials) {
		tlAppendBytes(patched, apiHash);
	} else {
		NSUInteger hashOffset = apiIdOffset + 4;
		[patched appendData:[payload subdataWithRange:NSMakeRange(hashOffset, settingsOffset - hashOffset)]];
	}

	int32_t outgoingFlags = dropPushFields ? (flags & ~((1 << 7) | (1 << 8))) : flags;
	NSUInteger settingsEnd = dropPushFields ? tokenOffset : payload.length;

	NSMutableData *settings = [[payload subdataWithRange:NSMakeRange(settingsOffset, settingsEnd - settingsOffset)] mutableCopy];
	[settings replaceBytesInRange:NSMakeRange(flagsOffset - settingsOffset, 4) withBytes:&outgoingFlags];
	[patched appendData:settings];

	if (replaceCredentials) {
		customLog2(@"auth.sendCode: sending with api_id %d from the tweak settings", outgoingApiId);
	}

	if (dropPushFields) {
		customLog2(@"auth.sendCode: stripped push verification (flags %d -> %d)", flags, outgoingFlags);
	}

	return patched;
}

// What the server decided to do with the login code. Without this the client
// only shows a generic "code sent" screen, so there is no way to tell an app
// code from an SMS or from a push verification that cannot complete here.

static NSString *sentCodeTypeName(int32_t constructor) {
	switch (constructor) {
		case 1035688326:  return @"App: service message to another active session";
		case -1073693790: return @"SMS";
		case -1542017919: return @"SMS word";
		case -1284008785: return @"SMS phrase";
		case 10475318:    return @"Firebase SMS: needs a silent push first";
		case 1398007207:  return @"Voice call";
		case -1425815847: return @"Flash call";
		case -2113903484: return @"Missed call";
		case -648651719:  return @"Fragment SMS";
		case -196020837:  return @"Email code";
		case -1521934870: return @"Email setup required";
		default:          return nil;
	}
}

static NSString *authRequestName(int32_t functionID) {
	return functionID == kAuthSendCode ? @"auth.sendCode" : @"auth.resendCode";
}

void logAuthCodeResponse(int32_t functionID, NSData *response) {
	NSString *request = authRequestName(functionID);

	if (response.length < 4) {
		customLog2(@"%@ -> empty response", request);
		return;
	}

	int32_t constructor = 0;
	[response getBytes:&constructor length:4];

	if (constructor == kAuthSentCodeSuccess) {
		customLog2(@"%@ -> signed in without a code", request);
		return;
	}

	if (constructor != kAuthSentCode || response.length < 12) {
		customLog2(@"%@ -> response %d (%lu bytes)", request, constructor, (unsigned long)response.length);
		return;
	}

	// auth.sentCode: flags, then the boxed type
	int32_t type = 0;
	[response getBytes:&type range:NSMakeRange(8, 4)];

	NSString *name = sentCodeTypeName(type);
	customLog2(@"%@ -> delivery: %@ (%d)", request, name ?: @"unrecognised", type);
}

void logAuthCodeError(int32_t functionID, MTRpcError *error) {
	customLog2(@"%@ -> error %d %@", authRequestName(functionID), error.errorCode, error.errorDescription);
}

__attribute__((constructor))
static void registerTGExtraDefaults() {
	// Push verification cannot work in a re-signed build, so this is on unless
	// it is explicitly turned off in the menu.
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{ kForceSmsLoginCode: @YES }];
}