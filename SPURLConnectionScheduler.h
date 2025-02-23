#import <Cocoa/Cocoa.h>


@interface SPURLConnectionScheduler : NSObject
{
    NSInteger maxConcurrentConnections;
    NSMutableDictionary* activeConnections;
    NSMutableArray* pendingRequests;
    NSLock* lock;
}

+ (SPURLConnectionScheduler*) sharedInstance;


- (instancetype) init;

- (BOOL) scheduleRequest:(NSURLRequest*)request withDelegate:(id)delegate andPriority:(NSInteger)priority;
- (void) cancelRequestsForDelegate:(id)delegate;
- (void) serviceNextRequests;
- (void) connectionDidFinish:(NSURLConnection*)connection ofSender:(id)sender;

@property (NS_NONATOMIC_IOSONLY) NSInteger maxConcurrentConnections;

@end


@interface SPScheduledURLRequest : NSObject
{
    NSURLRequest* request;
    id delegate;
    NSInteger priority;
}

@property (nonatomic, retain) NSURLRequest* request;
@property (nonatomic, retain) id delegate;
@property (nonatomic) NSInteger priority;

- (instancetype) initWithRequest:(NSURLRequest*)theRequest andDelegate:(id)theDelegate andPriority:(NSInteger)thePriority NS_DESIGNATED_INITIALIZER;

@end
