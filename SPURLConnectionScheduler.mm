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
- (instancetype) init
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
		if (request.delegate == delegate)
			[pendingRequests removeObject:request];
	}

    NSURLConnection* connection = activeConnections[[delegate path]];
    [connection cancel];
	[activeConnections removeObjectForKey:[delegate path]]; 
	[self serviceNextRequests];

    [lock unlock];
}


// ----------------------------------------------------------------------------
- (void) serviceNextRequests
// ----------------------------------------------------------------------------
{
	while (activeConnections.count < maxConcurrentConnections && pendingRequests.count > 0)
	{
		SPScheduledURLRequest* scheduledRequest = pendingRequests[0];
		[pendingRequests removeObjectAtIndex:0];
		
		NSURLConnection* connection = [[NSURLConnection alloc] initWithRequest:scheduledRequest.request delegate:scheduledRequest.delegate];
		activeConnections[[scheduledRequest.delegate path]] = connection;
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
- (instancetype) init
// ----------------------------------------------------------------------------
{
    return [self initWithRequest:nil andDelegate:nil andPriority:nil];
}
// ----------------------------------------------------------------------------
- (instancetype) initWithRequest:(NSURLRequest*)theRequest andDelegate:(id)theDelegate andPriority:(NSInteger)thePriority
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
