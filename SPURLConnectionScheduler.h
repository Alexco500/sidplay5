#import <Cocoa/Cocoa.h>


@interface SPURLConnectionScheduler : NSObject
{
	NSInteger maxConcurrentConnections;
	NSMutableDictionary* activeConnections;
	NSMutableArray* pendingRequests;
    NSLock* lock;
}

+ (SPURLConnectionScheduler*) sharedInstance;


- (id) init;

- (BOOL) scheduleRequest:(NSURLRequest*)request withDelegate:(id)delegate andPriority:(NSInteger)priority;
- (void) cancelRequestsForDelegate:(id)delegate;
- (void) serviceNextRequests;
- (void) connectionDidFinish:(NSURLConnection*)connection ofSender:(id)sender;

- (NSInteger) maxConcurrentConnections;
- (void) setMaxConcurrentConnections:(NSInteger)numConnections;

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

- (id) initWithRequest:(NSURLRequest*)theRequest andDelegate:(id)theDelegate andPriority:(NSInteger)thePriority;

@end
