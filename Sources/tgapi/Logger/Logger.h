#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
void customLog(NSString *format, ...);
void customLog2(NSString *format, ...);
NSString *customLogPath(void);
void customLogClear(void);
#ifdef __cplusplus
}
#endif
