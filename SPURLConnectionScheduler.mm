#import "SPURLConnectionScheduler.h"


@implementation SPURLConnectionScheduler

static SPURLConnectionScheduler* sharedInstance = nil;

static NSInteger sDefaultMaxConcurrentConnections = 8;


// ----------------------------------------------------------------------------
+ (SPURLConnectionScheduler*) sharedInstance
// ----------------------------------------------------------------------------
{
	if (sharedInstance == nil)
		sharedInstance = [[SPURLConnectionScheduler alloc] init];
	
	return sharedInstance;
}


// ----------------------------------------------------------------------------
- (id) init
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		maxConcurrentConnections = sDefaultMaxConcurrentConnections;
		activeConnections = [[NSMutableDictionary alloc] initWithCapacity:maxConcurrentConnections];
		pendingRequests = [[NSMutableArray alloc] initWithCapacity:maxConcurrentConnections * 10];
        lock = [[NSLock alloc] init];
	}
	return self;
}


// ----------------------------------------------------------------------------
- (BOOL) scheduleRequest:(NSURLRequest*)request withDelegate:(id)delegate andPriority:(NSInteger)priority;
// ----------------------------------------------------------------------------
{
	SPScheduledURLRequest* scheduledRequest = [[SPScheduledURLRequest alloc] initWithRequest:request andDelegate:delegate andPriority:priority];

    [lock lock];
	[pendingRequests addObject:scheduledRequest];
	[self serviceNextRequests];
    [lock unlock];

	return YES;
}


// ----------------------------------------------------------------------------
- (void) cancelRequestsForDelegate:(id)delegate
// ----------------------------------------------------------------------------
{
    [lock lock];

	NSArray* pendingRequestsCopy = [pendingRequests copy];
	for (SPScheduledURLRequest* request in pendingRequestsCopy)
	{
		if ([request delegate] == delegate)
			[pendingRequests removeObject:request];
	}

    NSURLConnection* connection = [activeConnections objectForKey:[delegate path]];
    [connection cancel];
	[activeConnections removeObjectForKey:[delegate path]]; 
	[self serviceNextRequests];

    [lock unlock];
}


// ----------------------------------------------------------------------------
- (void) serviceNextRequests
// ----------------------------------------------------------------------------
{
	while ([activeConnections count] < maxConcurrentConnections && [pendingRequests count] > 0)
	{
		SPScheduledURLRequest* scheduledRequest = [pendingRequests objectAtIndex:0];
		[pendingRequests removeObjectAtIndex:0];
		
		NSURLConnection* connection = [[NSURLConnection alloc] initWithRequest:[scheduledRequest request] delegate:[scheduledRequest delegate]];
		[activeConnections setObject:connection forKey:[[scheduledRequest delegate] path]];
	}
}


// ----------------------------------------------------------------------------
- (void) connectionDidFinish:(NSURLConnection*)connection ofSender:(id)sender
// ----------------------------------------------------------------------------
{
    [lock lock];
	[activeConnections removeObjectForKey:[sender path]]; 
	[self serviceNextRequests];
    
    [lock unlock];
}


// ----------------------------------------------------------------------------
- (NSInteger) maxConcurrentConnections
// ----------------------------------------------------------------------------
{
	return maxConcurrentConnections;
}


// ----------------------------------------------------------------------------
- (void) setMaxConcurrentConnections:(NSInteger)numConnections
// ----------------------------------------------------------------------------
{
	maxConcurrentConnections = numConnections;
}


@end


@implementation SPScheduledURLRequest

@synthesize request;
@synthesize delegate;
@synthesize priority;


// ----------------------------------------------------------------------------
- (id) initWithRequest:(NSURLRequest*)theRequest andDelegate:(id)theDelegate andPriority:(NSInteger)thePriority
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		request = theRequest;
		delegate = theDelegate;
		priority = thePriority;
	}
	return self;
}



@end
