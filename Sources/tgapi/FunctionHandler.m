#import "Headers.h"

// Which settings belong to which account
//
// Requests carry no account, but the service that sends them belongs to one, and
// its MTProto connection has the account's own auth key. That key is the account
// identity here; it is mapped to a small slot number so settings keys stay short
// and the menu can name the account.

NSInteger accountSlot(NSString *account) {
	if (account.length == 0) {
		return 0;
	}

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *slots = [defaults dictionaryForKey:kAccountSlots] ?: @{};

	NSNumber *existing = slots[account];
	if (existing) {
		return existing.integerValue;
	}

	NSInteger next = 1;
	for (NSNumber *slot in slots.allValues) {
		next = MAX(next, slot.integerValue + 1);
	}

	NSMutableDictionary *updated = [slots mutableCopy];
	updated[account] = @(next);
	[defaults setObject:updated forKey:kAccountSlots];

	return next;
}

static NSString *scopedKey(NSString *key, NSString *account) {
	NSInteger slot = accountSlot(account);
	return slot > 0 ? [NSString stringWithFormat:@"%@#%ld", key, (long)slot] : key;
}

BOOL accountBoolForKey(NSString *key, NSString *account) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *scoped = scopedKey(key, account);

	if (![scoped isEqualToString:key] && [defaults objectForKey:scoped] != nil) {
		return [defaults boolForKey:scoped];
	}

	return [defaults boolForKey:key];
}

NSInteger accountIntegerForKey(NSString *key, NSString *account) {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *scoped = scopedKey(key, account);

	if (![scoped isEqualToString:key] && [defaults objectForKey:scoped] != nil) {
		return [defaults integerForKey:scoped];
	}

	return [defaults integerForKey:key];
}

// The account the menu edits. Presence is reported for the account in the
// foreground, which is the one the user is looking at.
void noteActiveAccount(NSString *account) {
	if (account.length == 0) {
		return;
	}

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (![[defaults stringForKey:kActiveAccount] isEqualToString:account]) {
		[defaults setObject:account forKey:kActiveAccount];
	}
}

NSString *activeAccountKey(void) {
	return [[NSUserDefaults standardUserDefaults] stringForKey:kActiveAccount];
}

NSData *boolTrue() {
    uint8_t bytes[] = {0xB5, 0x75, 0x72, 0x99}; // boolTrue#997275b5
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

NSData *boolFalse() {
    uint8_t bytes[] = {0x37, 0x97, 0x79, 0xBC}; // boolFalse#bc799737
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

// Handlers
void handleOnlineStatus(MTRequest *request, NSData *payload, NSString *account) {
	
	NSData *isOfflineData = [payload subdataWithRange:NSMakeRange(payload.length - 4, 4)];
	uint32_t isOffline = 0;
	[isOfflineData getBytes:&isOffline length:4];
	
	if (isOffline == 3162085175) { // Online (BOOL false)
		if (accountBoolForKey(kDisableOnlineStatus, account)) {
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

void handleSetTyping(MTRequest *request, NSData *payload, NSString *account) {
	
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
	
	bool shouldBlockAction = false;
	
	//customLog(@"Handle Set Typing action : %d actionData:%@", actionID, [payload description]);
	switch (actionID) {
		case kActionIDTyping:
		shouldBlockAction = accountBoolForKey(kDisableTypingStatus, account);
		  break;
		case kActionIDRecordingVideo:
		  shouldBlockAction = accountBoolForKey(kDisableRecordingVideoStatus, account);
		  break;
		case kActionIDUploadingVideo:
		  shouldBlockAction = accountBoolForKey(kDisableUploadingVideoStatus, account);
		  break;
		case kActionIDRecordingAudio:
		  shouldBlockAction = accountBoolForKey(kDisableRecordingVoiceStatus, account);
		  break;
		case kActionIDUploadingVoice:
		  shouldBlockAction = accountBoolForKey(kDisableUploadingVoiceStatus, account);
		  break;
		case kActionIDUploadingPhoto:
		  shouldBlockAction = accountBoolForKey(kDisableUploadingPhotoStatus, account);
		  break;
		case kActionIDUploadingFile:
		  shouldBlockAction = accountBoolForKey(kDisableUploadingFileStatus, account);
		  break;
		case kActionIDChoosingLocation:
		  shouldBlockAction = accountBoolForKey(kDisableChoosingLocationStatus, account);
		  break;
		case kActionIDChoosingContact:
		  shouldBlockAction = accountBoolForKey(kDisableChoosingContactStatus, account);
		  break;
		case kActionIDPlayingGame:
		  shouldBlockAction = accountBoolForKey(kDisablePlayingGameStatus, account);
		  break;
		case kActionIDRecordingRoundVideo:
		  shouldBlockAction = accountBoolForKey(kDisableRecordingRoundVideoStatus, account);
		  break;
		case kActionIDUploadingRoundVideo:
		  shouldBlockAction = accountBoolForKey(kDisableUploadingRoundVideoStatus, account);
		  break;
		case kActionIDSpeakingInGroupCall:
		  shouldBlockAction = accountBoolForKey(kDisableSpeakingInGroupCallStatus, account);
		  break;
		case kActionIDReserverHistoryImport:
		  shouldBlockAction = accountBoolForKey(@"reserverHistroyImport", account);
		  break;
		case kActionIDChoosingSticker:
		  shouldBlockAction = accountBoolForKey(kDisableChoosingStickerStatus, account);
		  break;
		case kActionIDEmojiInteraction:
		  shouldBlockAction = accountBoolForKey(kDisableEmojiInteractionStatus, account);
		  break;
		case kActionIDEmojiAcknowledgement:
		  shouldBlockAction = accountBoolForKey(kDisableEmojiAcknowledgementStatus, account);
		  break;
	}
	
	if (shouldBlockAction) {
		request.fakeData = boolTrue();
	}
}

void handleMessageReadReceipt(MTRequest *request, NSData *payload, NSString *account) {
	if (accountBoolForKey(kDisableMessageReadReceipt, account)) {
		
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

void handleStoriesReadReceipt(MTRequest *request, NSData *payload, NSString *account) {
	if (accountBoolForKey(kDisableStoriesReadReceipt, account)) {
		
		uint8_t vectorID[] = {0x15, 0xC4, 0xB5, 0x1C}; // vector#1cb5c415
		int32_t count = 0;  
		
		NSMutableData *data = [NSMutableData data];
		[data appendBytes:&vectorID length:sizeof(vectorID)];
		[data appendBytes:&count length:sizeof(count)];
	
		request.fakeData = data;
	}
}

void handleGetSponsoredMessages(MTRequest *request, NSData *payload, NSString *account) {
	if (accountBoolForKey(kDisableAllAds, account)) {
		
		uint8_t header[] = {0x0F, 0X49, 0X39, 0X18}; // messages.sponsoredMessagesEmpty#1839490f
		request.fakeData = [NSData dataWithBytes:header length:sizeof(header)];
	}
}

void handleChannelsReadReceipt(MTRequest *request, NSData *payload, NSString *account) {
	if (accountBoolForKey(kDisableMessageReadReceipt, account)) {
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

// Sending through Telegram's own scheduled messages
//
// A message handed to the server with a schedule_date is delivered by the
// server, not by this session, which is what keeps the account from being
// marked online just for sending. This is the same field the app's own
// "send later" uses; only the schedule_date is added.
//
// schedule_date is serialized before several rarely used fields, so when none
// of those are present it belongs at the very end of the request and the rest
// of the payload needs no parsing. When any of them is present the request is
// left alone.

// Every request that can carry a schedule_date, with the flags of the fields
// serialized after it. Taken from the generated serializers of this layer: with
// none of those flags set, schedule_date belongs at the very end of the request.
typedef struct {
	int32_t constructor;
	int32_t fieldsAfterScheduleDate;
	const char *name;
} TGExtraSchedulableRequest;

static const TGExtraSchedulableRequest schedulableRequests[] = {
	{kMessagesSendMessage,     0x1E62000, "messages.sendMessage"},
	{kMessagesSendMedia,       0x1662000, "messages.sendMedia"},
	{kMessagesSendMultiMedia,  0x0262000, "messages.sendMultiMedia"},
	{kMessagesForwardMessages, 0x1B62000, "messages.forwardMessages"}
};

static const TGExtraSchedulableRequest *schedulableRequest(int32_t constructor) {
	for (size_t i = 0; i < sizeof(schedulableRequests) / sizeof(schedulableRequests[0]); i++) {
		if (schedulableRequests[i].constructor == constructor) {
			return &schedulableRequests[i];
		}
	}

	return NULL;
}

NSData *scheduledSendPayload(NSData *payload, NSString *account) {
	NSInteger delay = accountIntegerForKey(kScheduleSendDelay, account);
	if (delay <= 0) {
		return nil;
	}

	// The server rejects a date that is not far enough ahead.
	delay = MAX(15, MIN(600, delay));

	NSUInteger offset = 0;
	int32_t constructor = 0;
	if (!tlReadInt32(payload, &offset, &constructor)) {
		return nil;
	}

	const TGExtraSchedulableRequest *request = schedulableRequest(constructor);
	if (!request) {
		return nil;
	}

	NSUInteger flagsOffset = offset;
	int32_t flags = 0;
	if (!tlReadInt32(payload, &offset, &flags)) {
		return nil;
	}

	if ((flags & (1 << 10)) != 0) {
		return nil; // already scheduled from the app's own menu
	}

	if ((flags & request->fieldsAfterScheduleDate) != 0) {
		customLog2(@"%s: flags %d carry fields after schedule_date, sent immediately", request->name, flags);
		return nil;
	}

	int32_t scheduleDate = (int32_t)([[NSDate date] timeIntervalSince1970] + (double)delay);
	int32_t patchedFlags = flags | (1 << 10);

	NSMutableData *patched = [payload mutableCopy];
	[patched replaceBytesInRange:NSMakeRange(flagsOffset, 4) withBytes:&patchedFlags];
	[patched appendBytes:&scheduleDate length:4];

	customLog2(@"%s: handed to the server to send in %ld s", request->name, (long)delay);
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
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{
		kForceSmsLoginCode: @YES,
		kShowLauncherButton: @YES
	}];
}