#import <Foundation/Foundation.h>

@interface PlayerUsbWorker : NSObject
{
    BOOL isPlaying;
}
@property (nonatomic, copy) void (^iterationBlock)(void);

- (void)start;
- (void)pause;
- (void)resume;
- (void)stop;
- (BOOL)isPlaying;

@end
