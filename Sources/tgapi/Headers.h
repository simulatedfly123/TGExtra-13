#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Logger/Logger.h"
#import "Constants.h"

@interface TLParser : NSObject
+ (NSData *)handleResponse:(NSData *)data functionID:(NSNumber *)ios;
@end

@interface MTRpcError : NSObject
@property (nonatomic, readonly) int32_t errorCode;
@property (nonatomic, strong, readonly) NSString *errorDescription;
- (id)initWithErrorCode:(int)code errorDescription:(id)desc;
@end

@interface MTApiEnvironment : NSObject
@property (nonatomic) int32_t apiId;
@end

@interface MTRequestResponseInfo : NSObject
- (id)initWithNetworkType:(int)a  timestamp:(CGFloat)b  duration:(CGFloat)c;
@end

// Enough of MtProtoKit to find out which account a request belongs to: the
// service that sends it is attached to one MTProto connection, whose auth key
// is unique to that account.
typedef NS_ENUM(int64_t, MTDatacenterAuthInfoSelector) {
	MTDatacenterAuthInfoSelectorPersistentKey = 0
};

@interface MTDatacenterAuthInfo : NSObject
@property (nonatomic, readonly) int64_t authKeyId;
@end

@interface MTContext : NSObject
- (MTDatacenterAuthInfo *)authInfoForDatacenterWithId:(NSInteger)datacenterId selector:(MTDatacenterAuthInfoSelector)selector;
@end

@interface MTProto : NSObject
@property (nonatomic, strong, readonly) MTContext *context;
@property (nonatomic) NSInteger datacenterId;
@end

// Hooked below with properties of our own; Logos only forward declares the
// class, so the additions have to be visible here.
@interface MTRequestMessageService : NSObject
@property (nonatomic, strong) id tgextraMtProtoBox;
@property (nonatomic, strong) NSString *tgextraAccountKey;
- (NSString *)__tgextra_accountKey;
@end

@interface MTRequest : NSObject
@property (nonatomic, strong) NSNumber *functionID;
@property (nonatomic, strong) NSData *fakeData;
@property (nonatomic, strong, readonly) NSData *payload;
@property (nonatomic, strong, readonly) id metadata;
@property (nonatomic, strong, readonly) id shortMetadata;
- (void)setPayload:(NSData *)payload metadata:(id)metadata shortMetadata:(id)shortMetadata responseParser:(id (^)(NSData *))responseParser;
@property (nonatomic, copy) void (^completed)(id boxedResponse, MTRequestResponseInfo *info, MTRpcError *error);
@property (nonatomic, strong, readonly) id (^responseParser)(NSData *);
@end

// Function Handlers
#ifdef __cplusplus
extern "C" {
#endif
void handleOnlineStatus(MTRequest *request, NSData *payload, NSString *account);
void handleSetTyping(MTRequest *request, NSData *payload, NSString *account);
void handleMessageReadReceipt(MTRequest *request, NSData *payload, NSString *account);
void handleStoriesReadReceipt(MTRequest *request, NSData *payload, NSString *account);
void handleGetSponsoredMessages(MTRequest *request, NSData *payload, NSString *account);
void handleChannelsReadReceipt(MTRequest *request, NSData *payload, NSString *account);
NSData *patchedSendCodePayload(NSData *payload);
int32_t customApiId(void);
NSData *scheduledSendPayload(NSData *payload, NSString *account);

// Settings are stored per account: a value saved for an account wins, and the
// plain key is the fallback, so anything set before stays in effect.
BOOL accountBoolForKey(NSString *key, NSString *account);
NSInteger accountIntegerForKey(NSString *key, NSString *account);
NSInteger accountSlot(NSString *account);
void noteActiveAccount(NSString *account);
NSString *activeAccountKey(void);
void logAuthCodeResponse(int32_t functionID, NSData *response);
void logAuthCodeError(int32_t functionID, MTRpcError *error);
#ifdef __cplusplus
}
#endif
