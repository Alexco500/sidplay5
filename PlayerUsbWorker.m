#import "PlayerUsbWorker.h"

@interface PlayerUsbWorker ()
@property (atomic) BOOL running;
@property (atomic) BOOL paused;
@property (nonatomic, strong) NSThread *thread;
@property (nonatomic, strong) NSCondition *cond;
@end

@implementation PlayerUsbWorker

- (instancetype)init {
    self = [super init];
    if (self) {
        _cond = [[NSCondition alloc] init];
    }
    isPlaying = false;
    return self;
}

- (void)start {
    if (self.thread && !self.thread.isFinished)
        return;
    else {
        self.running = YES;
        self.paused = NO;
        
        self.thread = [[NSThread alloc] initWithTarget:self
                                              selector:@selector(workerMain)
                                                object:nil];
        [self.thread start];
        isPlaying = true;
    }
}

- (void)pause {
    [self.cond lock];
    self.paused = YES;
    [self.cond unlock];
}

- (void)resume {
    [self.cond lock];
    self.paused = NO;
    [self.cond signal];
    [self.cond unlock];
}

- (void)stop {
    [self.cond lock];
    self.running = NO;
    self.paused = NO;
    isPlaying = false;
    [self.cond signal];
    [self.cond unlock];
    
    [self.thread cancel];
    
    while (![self.thread isFinished]) {
        [NSThread sleepForTimeInterval:0.01];
    }
}
- (BOOL)isPlaying {
    return isPlaying;
}

- (void)workerMain {
    @autoreleasepool {
        while (self.running && ![NSThread currentThread].isCancelled) {

            [self.cond lock];
            while (self.paused && self.running) {
                [self.cond wait];
            }
            [self.cond unlock];

            if (!self.running)
                break;

            if (self.iterationBlock)
                self.iterationBlock();
        }
    }
}

@end
