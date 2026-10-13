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

@interface MTRequest : NSObject
@property (nonatomic, strong) NSNumber *functionID;
@property (nonatomic, strong) NSData *fakeData;
@property (nonatomic, copy) void (^completed)(id boxedResponse, MTRequestResponseInfo *info, MTRpcError *error);
@property (nonatomic, strong, readonly) id (^responseParser)(NSData *);
@end

// Function Handlers
#ifdef __cplusplus
extern "C" {
#endif
void handleOnlineStatus(MTRequest *request, NSData *payload);
void handleSetTyping(MTRequest *request, NSData *payload);
void handleMessageReadReceipt(MTRequest *request, NSData *payload);
void handleStoriesReadReceipt(MTRequest *request, NSData *payload);
void handleGetSponsoredMessages(MTRequest *request, NSData *payload);
void handleChannelsReadReceipt(MTRequest *request, NSData *payload);
NSData *patchedSendCodePayload(NSData *payload);
int32_t customApiId(void);
NSData *scheduledSendPayload(NSData *payload);
void logAuthCodeResponse(int32_t functionID, NSData *response);
void logAuthCodeError(int32_t functionID, MTRpcError *error);
#ifdef __cplusplus
}
#endif
