//
//  AsyncSocket.m
//
//  Created by Dustin Voss on Wed Jan 29 2003.
//  This class is in the public domain.
//  If used, I'd appreciate it if you credit me.
//
//  E-Mail: d-j-v@earthlink.net
//

#import "AsyncSocket.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>

#pragma mark Declarations

#define READQUEUE_CAPACITY	5			/* Initial capacity. */
#define WRITEQUEUE_CAPACITY 5			/* Initial capacity. */
#define READALL_CHUNKSIZE	256			/* Incremental increase in buffer size. */ 
#define WRITE_CHUNKSIZE		(4*1024)	/* Limit on size of each write pass. */

NSString *const AsyncSocketException = @"AsyncSocketException";
NSString *const AsyncSocketErrorDomain = @"AsyncSocketErrorDomain";

// This is a mutex lock used by all instances of AsyncSocket, to protect getaddrinfo.
// The man page says it is not thread-safe.
NSString *getaddrinfoLock = @"lock";

enum AsyncSocketFlags
{
	kDidCallConnectDeleg = 0x01,	// If set, connect delegate has been called.
	kDidPassConnectMethod = 0x02,	// If set, disconnection results in delegate call.
	kForbidReadsWrites = 0x04,		// If set, no new reads or writes are allowed.
	kDisconnectSoon = 0x08			// If set, disconnect as soon as nothing is queued.
};

@interface AsyncSocket (Private)

// Socket Implementation
- (CFSocketRef) createAcceptSocketForAddress:(NSData *)addr error:(NSError **)errPtr;
- (BOOL) createSocketFromNative:(CFSocketNativeHandle)nativeSocket error:(NSError **)errPtr;
- (BOOL) attachSocketsToRunLoop:(NSRunLoop *)runLoop error:(NSError **)errPtr;
- (BOOL) configureSocketAndReturnError:(NSError **)errPtr;
- (BOOL) connectSocketToAddress:(struct sockaddr_in *)remoteAddr error:(NSError **)errPtr;
- (void) doAcceptWithSocket:(CFSocketNativeHandle)newSocket;
- (void) doSocketOpenWithCFSocketError:(CFSocketError)err;

// Stream Implementation
- (BOOL) createStreamsFromNative:(CFSocketNativeHandle)native error:(NSError **)errPtr;
- (BOOL) createStreamsToHost:(NSString *)hostname onPort:(UInt16)port error:(NSError **)errPtr;
- (BOOL) attachStreamsToRunLoop:(NSRunLoop *)runLoop error:(NSError **)errPtr;
- (BOOL) configureStreamsAndReturnError:(NSError **)errPtr;
- (BOOL) openStreamsAndReturnError:(NSError **)errPtr;
- (void) doStreamOpen;
- (BOOL) setSocketFromStreamsAndReturnError:(NSError **)errPtr;

// Disconnect Implementation
- (void) closeWithError:(NSError *)err;
- (void) recoverUnreadData;
- (void) emptyQueues;
- (void) close;

// Errors
- (NSError *) getErrnoError;
- (NSError *) getAbortError;
- (NSError *) getStreamError;
- (NSError *) getSocketError;
- (NSError *) getReadTimeoutError;
- (NSError *) getWriteTimeoutError;
- (NSError *) errorFromCFStreamError:(CFStreamError)err;

// Diagnostics
- (BOOL) isSocketConnected;
- (BOOL) areStreamsConnected;
- (NSString *) connectedHost: (CFSocketRef)socket;
- (UInt16) connectedPort: (CFSocketRef)socket;
- (NSString *) localHost: (CFSocketRef)socket;
- (UInt16) localPort: (CFSocketRef)socket;
- (NSString *) addressHost: (CFDataRef)cfaddr;
- (UInt16) addressPort: (CFDataRef)cfaddr;

// Reading
- (void) doBytesAvailable;
- (void) completeCurrentRead;
- (void) endCurrentRead;
- (void) scheduleDequeueRead;
- (void) maybeDequeueRead;
- (void) doReadTimeout:(NSTimer *)timer;

// Writing
- (void) doSendBytes;
- (void) completeCurrentWrite;
- (void) endCurrentWrite;
- (void) scheduleDequeueWrite;
- (void) maybeDequeueWrite;
- (void) maybeScheduleDisconnect;
- (void) doWriteTimeout:(NSTimer *)timer;

// Callbacks
- (void) doCFCallback:(CFSocketCallBackType)type forSocket:(CFSocketRef)sock withAddress:(NSData *)address withData:(const void *)pData;
- (void) doCFReadStreamCallback:(CFStreamEventType)type forStream:(CFReadStreamRef)stream;
- (void) doCFWriteStreamCallback:(CFStreamEventType)type forStream:(CFWriteStreamRef)stream;

@end

static void MyCFSocketCallback (CFSocketRef, CFSocketCallBackType, CFDataRef, const void *, void *);
static void MyCFReadStreamCallback (CFReadStreamRef stream, CFStreamEventType type, void *pInfo);
static void MyCFWriteStreamCallback (CFWriteStreamRef stream, CFStreamEventType type, void *pInfo);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The AsyncReadPacket encompasses the instructions for a current read.
 * The content of a read packet allows the code to determine if we're:
 * reading to a certain length, reading to a certain separator, or simply reading the first chunk of data.
**/
@interface AsyncReadPacket : NSObject
{
@public
	NSMutableData *buffer;
	CFIndex bytesDone;
	NSTimeInterval timeout;
	long tag;
	NSData *term;
	BOOL readAllAvailableData;
}
- (id)initWithData:(NSMutableData *)d timeout:(NSTimeInterval)t tag:(long)i readAllAvailable:(BOOL)a terminator:(NSData *)e bufferOffset:(CFIndex)b;
- (void)dealloc;
@end

@implementation AsyncReadPacket
- (id)initWithData:(NSMutableData *)d timeout:(NSTimeInterval)t tag:(long)i readAllAvailable:(BOOL)a terminator:(NSData *)e bufferOffset:(CFIndex)b
{
	if(self = [super init])
	{
		buffer = [d retain];
		timeout = t;
		tag = i;
		term = [e copy];
		bytesDone = b;
		readAllAvailableData = a;
	}
	return self;
}
- (void)dealloc
{
	[buffer release];
	[term release];
	[super dealloc];
}
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface AsyncWritePacket : NSObject
{
@public
	NSData *buffer;
	CFIndex bytesDone;
	long tag;
	NSTimeInterval timeout;
}
- (id)initWithData:(NSData *)d timeout:(NSTimeInterval)t tag:(long)i;
- (void)dealloc;
@end

@implementation AsyncWritePacket
- (id)initWithData:(NSData *)d timeout:(NSTimeInterval)t tag:(long)i;
{
	if(self = [super init])
	{
		buffer = [d retain];
		timeout = t;
		tag = i;
		bytesDone = 0;
	}
	return self;
}
- (void)dealloc
{
	[buffer release];
	[super dealloc];
}
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation AsyncSocket

- (id) init
{
	return [self initWithDelegate:nil userData:0];
}

- (id) initWithDelegate:(id)delegate
{
	return [self initWithDelegate:delegate userData:0];
}

// Designated initializer.
- (id) initWithDelegate:(id)delegate userData:(long)userData
{
	self = [super init];

	theFlags = 0x00;
	theDelegate = delegate;
	theUserData = userData;

	theSocket = NULL;
	theSource = NULL;
	theSocket6 = NULL;
	theSource6 = NULL;
	theRunLoop = NULL;
	theReadStream = NULL;
	theWriteStream = NULL;

	theReadQueue = [[NSMutableArray alloc] initWithCapacity:READQUEUE_CAPACITY];
	theCurrentRead = nil;
	theReadTimer = nil;
	
	partialReadBuffer = nil;
	
	theWriteQueue = [[NSMutableArray alloc] initWithCapacity:WRITEQUEUE_CAPACITY];
	theCurrentWrite = nil;
	theWriteTimer = nil;

	// Socket context
	NSAssert (sizeof(CFSocketContext) == sizeof(CFStreamClientContext), @"CFSocketContext and CFStreamClientContext aren't the same size anymore. Contact the developer.");
	theContext.version = 0;
	theContext.info = self;
	theContext.retain = nil;
	theContext.release = nil;
	theContext.copyDescription = nil;

	return self;
}

// The socket may been initialized in a connected state and auto-released, so this should close it down cleanly.
- (void) dealloc
{
	[self close];
	[theReadQueue release];
	[theWriteQueue release];
	[NSObject cancelPreviousPerformRequestsWithTarget:theDelegate selector:@selector(onSocketDidDisconnect:) object:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[super dealloc];
}


- (void) finalize
{
	theDelegate = nil;
	[self close];
	//[NSObject cancelPreviousPerformRequestsWithTarget:theDelegate selector:@selector(onSocketDidDisconnect:) object:self];
	//[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[super finalize];
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Accessors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (long) userData
{
	return theUserData;
}

- (void) setUserData:(long)userData
{
	theUserData = userData;
}

- (id) delegate
{
	return theDelegate;
}

- (void) setDelegate:(id)delegate
{
	theDelegate = delegate;
}

- (BOOL) canSafelySetDelegate
{
	return ([theReadQueue count] == 0 && [theWriteQueue count] == 0 && theCurrentRead == nil && theCurrentWrite == nil);
}

- (CFSocketRef) getCFSocket
{
	return theSocket;
}

- (CFReadStreamRef) getCFReadStream
{
	return theReadStream;
}

- (CFWriteStreamRef) getCFWriteStream
{
	return theWriteStream;
}

- (float) progressOfReadReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total
{
	// Check to make sure we're actually reading something right now
	if (!theCurrentRead) return NAN;
	
	// It's only possible to know the progress of our read if we're reading to a certain length
	// If we're reading to data, we of course have no idea when the data will arrive
	// If we're reading to timeout, then we have no idea when the next chunk of data will arrive.
	BOOL hasTotal = (theCurrentRead->readAllAvailableData == NO && theCurrentRead->term == nil);
	
	CFIndex d = theCurrentRead->bytesDone;
	CFIndex t = hasTotal ? [theCurrentRead->buffer length] : 0;
	if (tag != NULL)   *tag = theCurrentRead->tag;
	if (done != NULL)  *done = d;
	if (total != NULL) *total = t;
	float ratio = (float)d/(float)t;
	return isnan(ratio) ? 1.0 : ratio; // 0 of 0 bytes is 100% done.
}

- (float) progressOfWriteReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total
{
	if (!theCurrentWrite) return NAN;
	CFIndex d = theCurrentWrite->bytesDone;
	CFIndex t = [theCurrentWrite->buffer length];
	if (tag != NULL)   *tag = theCurrentWrite->tag;
	if (done != NULL)  *done = d;
	if (total != NULL) *total = t;
	return (float)d/(float)t;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Class Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Return line separators.
+ (NSData *) CRLFData
{ return [NSData dataWithBytes:"\x0D\x0A" length:2]; }

+ (NSData *) CRData
{ return [NSData dataWithBytes:"\x0D" length:1]; }

+ (NSData *) LFData
{ return [NSData dataWithBytes:"\x0A" length:1]; }

+ (NSData *) ZeroData
{ return [NSData dataWithBytes:"" length:1]; }

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connection
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)acceptOnPort:(UInt16)port error:(NSError **)errPtr
{
	return [self acceptOnAddress:nil port:port error:errPtr];
}
	
// Setting up IPv4 and IPv6 accepting sockets.
- (BOOL)acceptOnAddress:(NSString *)hostaddr port:(UInt16)port error:(NSError **)errPtr
{
	if (theDelegate == NULL)
		[NSException raise:AsyncSocketException format:@"Attempting to accept without a delegate. Set a delegate first."];
	
	if (theSocket != NULL || theSocket6 != NULL)
		[NSException raise:AsyncSocketException format:@"Attempting to accept while connected or accepting connections. Disconnect first."];

	// Set up the listen sockaddr structs if needed.

	NSData *address = nil, *address6 = nil;
	if(hostaddr && ([hostaddr length] != 0))
	{
		NSString *portStr = [NSString stringWithFormat:@"%hu", port];
		
		@synchronized (getaddrinfoLock)
		{
			struct addrinfo hints, *res, *res0;
			
			memset(&hints, 0, sizeof(hints));
			hints.ai_family   = PF_UNSPEC;
			hints.ai_socktype = SOCK_STREAM;
			hints.ai_protocol = IPPROTO_TCP;
			hints.ai_flags    = AI_PASSIVE;
			
			int error = getaddrinfo([hostaddr UTF8String], [portStr UTF8String], &hints, &res0);
			
			if(error)
			{
				NSString *errMsg = [NSString stringWithCString:gai_strerror(error) encoding:NSASCIIStringEncoding];
				NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
				
				*errPtr = [NSError errorWithDomain:@"kCFStreamErrorDomainNetDB" code:error userInfo:info];
			}
			
			for(res = res0; res; res = res->ai_next)
			{
				if(!address && (res->ai_family == AF_INET))
				{
					// Found IPv4 address
					// Wrap the native address structures for CFSocketSetAddress.
					address = [NSData dataWithBytes:res->ai_addr length:res->ai_addrlen];
				}
				else if(!address6 && (res->ai_family == AF_INET6))
				{
					// Found IPv6 address
					// Wrap the native address structures for CFSocketSetAddress.
					address6 = [NSData dataWithBytes:res->ai_addr length:res->ai_addrlen];
				}
			}
			freeaddrinfo(res0);
		}
		
		if(!address && !address6) return NO;
	}
	else
	{
		// Set up the addresses.
		struct sockaddr_in nativeAddr;
		nativeAddr.sin_len         = sizeof(struct sockaddr_in);
		nativeAddr.sin_family      = AF_INET;
		nativeAddr.sin_port        = htons(port);
		nativeAddr.sin_addr.s_addr = htonl(INADDR_ANY);
		memset(&(nativeAddr.sin_zero), 0, sizeof(nativeAddr.sin_zero));
		
		struct sockaddr_in6 nativeAddr6;
		nativeAddr6.sin6_len       = sizeof(struct sockaddr_in6);
		nativeAddr6.sin6_family    = AF_INET6;
		nativeAddr6.sin6_port      = htons(port);
		nativeAddr6.sin6_flowinfo  = 0;
		nativeAddr6.sin6_addr      = in6addr_any;
		nativeAddr6.sin6_scope_id  = 0;

		// Wrap the native address structures for CFSocketSetAddress.
		address = [NSData dataWithBytes:&nativeAddr length:sizeof(nativeAddr)];
		address6 = [NSData dataWithBytes:&nativeAddr6 length:sizeof(nativeAddr6)];
	}

	// Create the sockets.

	if (address)
	{
		theSocket = [self createAcceptSocketForAddress:address error:errPtr];
		if (theSocket == NULL) goto Failed;
	}
	
	if (address6)
	{
		theSocket6 = [self createAcceptSocketForAddress:address6 error:errPtr];
		if (theSocket6 == NULL) goto Failed;
	}
	
	// Attach the sockets to the run loop so that callback methods work
	
	[self attachSocketsToRunLoop:nil error:nil];
	
	// Set the SO_REUSEADDR flags.

	int reuseOn = 1;
	if (theSocket)	setsockopt(CFSocketGetNative(theSocket), SOL_SOCKET, SO_REUSEADDR, &reuseOn, sizeof(reuseOn));
	if (theSocket6)	setsockopt(CFSocketGetNative(theSocket6), SOL_SOCKET, SO_REUSEADDR, &reuseOn, sizeof(reuseOn));

	// Set the local bindings which causes the sockets to start listening.

	CFSocketError err;
	if (theSocket)
	{
		err = CFSocketSetAddress (theSocket, (CFDataRef)address);
		if (err != kCFSocketSuccess) goto Failed;
		
		//NSLog(@"theSocket4: %hu", [self localPort:theSocket]);
	}
	
	if(port == 0 && theSocket && theSocket6)
	{
		// The user has passed in port 0, which means he wants to allow the kernel to choose the port for them
		// However, the kernel will choose a different port for both theSocket and theSocket6
		// So we grab the port the kernel choose for theSocket, and set it as the port for theSocket6
		UInt16 chosenPort = [self localPort:theSocket];
		
		struct sockaddr_in6 *pSockAddr6 = (struct sockaddr_in6 *)[address6 bytes];
		pSockAddr6->sin6_port = chosenPort;
    }
	
	if (theSocket6)
	{
		err = CFSocketSetAddress (theSocket6, (CFDataRef)address6);
		if (err != kCFSocketSuccess) goto Failed;
		
		//NSLog(@"theSocket6: %hu", [self localPort:theSocket6]);
	}

	theFlags |= kDidPassConnectMethod;
	return YES;
	
Failed:;
	if (errPtr) *errPtr = [self getSocketError];
	return NO;
}

/**
 * This method creates an initial CFReadStream and CFWriteStream to the given host on the given port.
 * The connection is then opened, and the corresponding CFSocket will be extracted after the connection succeeds.
 *
 * Thus the delegate will only have access to the CFReadStream and CFWriteStream prior to connection,
 * specifically in the onSocketWillConnect: method.
**/
- (BOOL)connectToHost:(NSString*)hostname onPort:(UInt16)port error:(NSError **)errPtr
{
	if(theDelegate == NULL)
		[NSException raise:AsyncSocketException format:@"Attempting to connect without a delegate. Set a delegate first."];

	if(theSocket != NULL || theSocket6 != NULL)
		[NSException raise:AsyncSocketException format:@"Attempting to connect while connected or accepting connections. Disconnect first."];
	
	BOOL pass = YES;
	
	if(pass && ![self createStreamsToHost:hostname onPort:port error:errPtr]) pass = NO;
	if(pass && ![self attachStreamsToRunLoop:nil error:errPtr])               pass = NO;
	if(pass && ![self configureStreamsAndReturnError:errPtr])                 pass = NO;
	if(pass && ![self openStreamsAndReturnError:errPtr])                      pass = NO;
	
	if(pass)
		theFlags |= kDidPassConnectMethod;
	else
		[self close];
	
	return pass;
}

/**
 * This method creates an initial CFSocket from a BSD socket to the given address.
 * The connection is then opened, and the corresponding CFReadStream and CFWriteStream will be
 * created from the low-level sockets after the connection succeeds.
 *
 * Thus the delegate will only have access to the CFSocket and CFSocketNativeHandle (BSD socket) prior to connection,
 * specifically in the onSocketWillConnect: method.
**/
- (BOOL)connectToAddress:(struct sockaddr_in *)remoteAddr error:(NSError **)errPtr
{
	if (theDelegate == NULL)
		[NSException raise:AsyncSocketException format:@"Attempting to connect without a delegate. Set a delegate first."];
	
	if (theSocket != NULL || theSocket6 != NULL)
		[NSException raise:AsyncSocketException format:@"Attempting to connect while connected or accepting connections. Disconnect first."];
	
	int nativeSocket = socket(remoteAddr->sin_family, SOCK_STREAM, 0);
	if(nativeSocket == -1)
	{
		if (errPtr) *errPtr = [self getErrnoError];
		return NO;
	}
	
	BOOL pass = YES;
	
	if(pass && ![self createSocketFromNative:nativeSocket error:errPtr]) pass = NO;
	if(pass && ![self attachSocketsToRunLoop:nil error:errPtr])          pass = NO;
	if(pass && ![self configureSocketAndReturnError:errPtr])             pass = NO;
	if(pass && ![self connectSocketToAddress:remoteAddr error:errPtr])   pass = NO;
	
	if(!pass)
	{
		// Something went wrong somewhere, and we need to cleanup.
		// If we at least created theSocket, then the close method can do everything for us.
		// Otherwise, we'll need to close our native socket.
		
		if(theSocket)
			[self close];
		else
			close(nativeSocket);
	}
	
	return pass;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Socket Implementation:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Creates the accept sockets.
 * Returns true if either IPv4 or IPv6 is created.
 * If either is missing, an error is returned (even though the method may return true).
**/
- (CFSocketRef)createAcceptSocketForAddress:(NSData *)addr error:(NSError **)errPtr
{
	struct sockaddr *pSockAddr = (struct sockaddr *)[addr bytes];
	int addressFamily = pSockAddr->sa_family;
	
	CFSocketRef socket = CFSocketCreate(kCFAllocatorDefault,
										addressFamily,
										SOCK_STREAM,
										0,
										kCFSocketAcceptCallBack,                // Callback flags
										(CFSocketCallBack)&MyCFSocketCallback,  // Callback method
										&theContext);

	if (socket == NULL && errPtr)
		*errPtr = [self getSocketError];
	
	return socket;
}

- (BOOL)createSocketFromNative:(CFSocketNativeHandle)nativeSocket error:(NSError **)errPtr
{
	theSocket = CFSocketCreateWithNative(NULL,                                   // Default allocator
										 nativeSocket,                           // CFSocketNativeHandle
										 kCFSocketConnectCallBack,               // Callback flags
										 (CFSocketCallBack)&MyCFSocketCallback,  // Callback method
										 &theContext);                           // Socket Context
	if(theSocket == NULL)
	{
		NSError *err1 = [self getSocketError];
		if (errPtr) *errPtr = err1;
		return NO;
	}
	
	// By default the underlying native socket will be closed when the CFSocket is invalidated
	
	return YES;
}

/**
 * Adds the CFSocket's to the run-loop so that callbacks will work properly.
**/
- (BOOL)attachSocketsToRunLoop:(NSRunLoop *)runLoop error:(NSError **)errPtr
{
	// Get the CFRunLoop to which the socket should be attached.
	theRunLoop = (runLoop == nil) ? CFRunLoopGetCurrent() : [runLoop getCFRunLoop];
	
	if(theSocket)
	{
		theSource  = CFSocketCreateRunLoopSource (kCFAllocatorDefault, theSocket, 0);
		CFRunLoopAddSource (theRunLoop, theSource, kCFRunLoopDefaultMode);
	}
	
	if(theSocket6)
	{
		theSource6 = CFSocketCreateRunLoopSource (kCFAllocatorDefault, theSocket6, 0);
		CFRunLoopAddSource (theRunLoop, theSource6, kCFRunLoopDefaultMode);
	}
	
	return YES;
}

/**
 * Allows the delegate method to configure the CFSocket or CFNativeSocket as desired before we connect.
 * Note that the CFReadStream and CFWriteStream will not be available until after the connection is opened.
**/
- (BOOL)configureSocketAndReturnError:(NSError **)errPtr
{
	// Call the delegate method for further configuration.
	if([theDelegate respondsToSelector:@selector(onSocketWillConnect:)])
	{
		if([theDelegate onSocketWillConnect:self] == NO)
		{
			if (errPtr) *errPtr = [self getAbortError];
			return NO;
		}
	}
	return YES;
}

- (BOOL)connectSocketToAddress:(struct sockaddr_in *)remoteAddr error:(NSError **)errPtr
{
	// In order to call the CFSocketConnectToAddress method we have to wrap our struct sockaddr_in into a CFDataRef
	
	CFDataRef remoteAddrData;
	remoteAddrData = CFDataCreate(NULL, (UInt8 *)remoteAddr, sizeof(struct sockaddr_in));
	if(remoteAddrData == NULL)
	{
		if (errPtr) *errPtr = [self getSocketError];
		return NO;
	}
	
	// Start connecting to the given address in the background
	// The MyCFSocketCallback method will be called when the connection succeeds or fails.
	CFSocketError err = CFSocketConnectToAddress(theSocket, remoteAddrData, -1);
	if(err != kCFSocketSuccess)
	{
		if (errPtr) *errPtr = [self getSocketError];
		return NO;
	}
	
	return YES;
}

/**
 * Attempt to make the new socket.
 * If an error occurs, ignore this event.
**/
- (void)doAcceptWithSocket:(CFSocketNativeHandle)newNative
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AsyncSocket *newSocket = [[[AsyncSocket alloc] initWithDelegate:theDelegate] autorelease];
	if(newSocket)
	{
		NSRunLoop *runLoop = nil;
		if ([theDelegate respondsToSelector:@selector(onSocket:didAcceptNewSocket:)])
			[theDelegate onSocket:self didAcceptNewSocket:newSocket];
		
		if ([theDelegate respondsToSelector:@selector(onSocket:wantsRunLoopForNewSocket:)])
			runLoop = [theDelegate onSocket:self wantsRunLoopForNewSocket:newSocket];
		
		BOOL pass = YES;
		
		if(pass && ![newSocket createStreamsFromNative:newNative error:nil]) pass = NO;
		if(pass && ![newSocket attachStreamsToRunLoop:runLoop error:nil]) pass = NO;
		if(pass && ![newSocket configureStreamsAndReturnError:nil]) pass = NO;
		if(pass && ![newSocket openStreamsAndReturnError:nil]) pass = NO;
		
		if(pass)
			newSocket->theFlags |= kDidPassConnectMethod;
		else {
			// No NSError, but errors will still get logged from the above functions.
			[newSocket close];
		}
		
	}
	[pool release];
}

/**
 * Description forthcoming...
**/
- (void)doSocketOpenWithCFSocketError:(CFSocketError)socketError
{
	// Update the flags to indicate we've made a connection
	// We do this even if we never actually made a successful connection.
	// This way the delegate properly receives a onSocket:didDisconnectWithError: message.
	theFlags |= kDidPassConnectMethod;
	
	if(socketError == kCFSocketTimeout || socketError == kCFSocketError)
	{
		[self closeWithError:[self getSocketError]];
		return;
	}
	
	// Get the underlying native (BSD) socket
	CFSocketNativeHandle nativeSocket = CFSocketGetNative(theSocket);
	
	// Setup the socket so that invalidating the socket will not close the native socket
	CFSocketSetSocketFlags(theSocket, 0);
	
	// Invalidate and release the CFSocket - All we need from here on out is the nativeSocket
	// Note: If we don't invalidate the socket (leaving the native socket open)
	// then theReadStream and theWriteStream won't function properly.
	// Specifically, their callbacks won't work, with the expection of kCFStreamEventOpenCompleted.
	// I'm not entirely sure why this is, but I'm guessing that events on the socket fire to the CFSocket we created,
	// as opposed to the CFReadStream/CFWriteStream.
	
	CFSocketInvalidate(theSocket);
	CFRelease(theSocket);
	theSocket = NULL;
	
	NSError *err;
	BOOL pass = YES;
	
	if(pass && ![self createStreamsFromNative:nativeSocket error:&err]) pass = NO;
	if(pass && ![self attachStreamsToRunLoop:nil error:&err])           pass = NO;
	if(pass && ![self openStreamsAndReturnError:&err])                  pass = NO;
	
	if(!pass)
	{
		[self closeWithError:err];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Stream Implementation:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Creates the CFReadStream and CFWriteStream from the given native socket.
 * The CFSocket may be extracted from either stream after the streams have been opened.
 * 
 * Note: The given native socket must already be connected!
**/
- (BOOL)createStreamsFromNative:(CFSocketNativeHandle)native error:(NSError **)errPtr
{
	// Create the socket & streams.
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, native, &theReadStream, &theWriteStream);
	if (theReadStream == NULL || theWriteStream == NULL)
	{
		NSError *err = [self getStreamError];
		NSLog (@"AsyncSocket %p couldn't create streams from accepted socket, %@", self, err);
		if (errPtr) *errPtr = err;
		return NO;
	}
	
	// Ensure the CF & BSD socket is closed when the streams are closed.
	CFReadStreamSetProperty(theReadStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	CFWriteStreamSetProperty(theWriteStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	
	return YES;
}

/**
 * Creates the CFReadStream and CFWriteStream from the given hostname and port number.
 * The CFSocket may be extracted from either stream after the streams have been opened.
**/
- (BOOL)createStreamsToHost:(NSString *)hostname onPort:(UInt16)port error:(NSError **)errPtr
{
	// Create the socket & streams.
	CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef)hostname, port, &theReadStream, &theWriteStream);
	if (theReadStream == NULL || theWriteStream == NULL)
	{
		if (errPtr) *errPtr = [self getStreamError];
		return NO;
	}
	
	// Ensure the CF & BSD socket is closed when the streams are closed.
	CFReadStreamSetProperty(theReadStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	CFWriteStreamSetProperty(theWriteStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	
	return YES;
}

- (BOOL)attachStreamsToRunLoop:(NSRunLoop *)runLoop error:(NSError **)errPtr
{
	// Get the CFRunLoop to which the socket should be attached.
	theRunLoop = (runLoop == nil) ? CFRunLoopGetCurrent() : [runLoop getCFRunLoop];

	// Make read stream non-blocking.
	if (!CFReadStreamSetClient (theReadStream,
		kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered | kCFStreamEventOpenCompleted,
		(CFReadStreamClientCallBack)&MyCFReadStreamCallback,
		(CFStreamClientContext *)(&theContext) ))
	{
		NSLog (@"AsyncSocket %p couldn't attach read stream to run-loop,", self);
		goto Failed;
	}
	CFReadStreamScheduleWithRunLoop (theReadStream, theRunLoop, kCFRunLoopDefaultMode);

	// Make write stream non-blocking.
	if (!CFWriteStreamSetClient (theWriteStream,
		kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered | kCFStreamEventOpenCompleted,
		(CFWriteStreamClientCallBack)&MyCFWriteStreamCallback,
		(CFStreamClientContext *)(&theContext) ))
	{
		NSLog (@"AsyncSocket %p couldn't attach write stream to run-loop,", self);
		goto Failed;
	}
	CFWriteStreamScheduleWithRunLoop (theWriteStream, theRunLoop, kCFRunLoopDefaultMode);
	
	return YES;

Failed:;
	NSError *err = [self getStreamError];
	NSLog (@"%@", err);
	if (errPtr) *errPtr = err;
	return NO;
}

/**
 * Allows the delegate method to configure the CFReadStream and/or CFWriteStream as desired before we connect.
 * Note that the CFSocket and CFNativeSocket will not be available until after the connection is opened.
**/
- (BOOL)configureStreamsAndReturnError:(NSError **)errPtr
{
	// Call the delegate method for further configuration.
	if([theDelegate respondsToSelector:@selector(onSocketWillConnect:)])
	{
		if([theDelegate onSocketWillConnect:self] == NO)
		{
			NSError *err = [self getAbortError];
			if (errPtr) *errPtr = err;
			return NO;
		}
	}
	return YES;
}

- (BOOL)openStreamsAndReturnError:(NSError **)errPtr
{
	BOOL pass = YES;
	
	if(pass && !CFReadStreamOpen (theReadStream))
	{
		NSLog (@"AsyncSocket %p couldn't open read stream,", self);
		pass = NO;
	}
	
	if(pass && !CFWriteStreamOpen (theWriteStream))
	{
		NSLog (@"AsyncSocket %p couldn't open write stream,", self);
		pass = NO;
	}
	
	if(!pass)
	{
		NSError *err = [self getStreamError];
		NSLog (@"%@", err);
		if (errPtr) *errPtr = err;
	}
	
	return pass;
}

/**
 * Called when read or write streams open.
 * When the socket is connected and both streams are open, consider the AsyncSocket instance to be ready.
**/
- (void)doStreamOpen
{
	NSError *err = nil;
	if ([self areStreamsConnected] && !(theFlags & kDidCallConnectDeleg))
	{
		// Get the socket.
		if (![self setSocketFromStreamsAndReturnError: &err])
		{
			NSLog (@"AsyncSocket %p couldn't get socket from streams, %@. Disconnecting.", self, err);
			[self closeWithError:err];
		}
		
		// Call the delegate.
		theFlags |= kDidCallConnectDeleg;
		if ([theDelegate respondsToSelector:@selector(onSocket:didConnectToHost:port:)])
		{
			[theDelegate onSocket:self didConnectToHost:[self connectedHost] port:[self connectedPort]];
		}
		
		// Immediately deal with any already-queued requests.
		[self maybeDequeueRead];
		[self maybeDequeueWrite];
	}
}

- (BOOL)setSocketFromStreamsAndReturnError:(NSError **)errPtr
{
	CFSocketNativeHandle native;
	CFDataRef nativeProp = CFReadStreamCopyProperty(theReadStream, kCFStreamPropertySocketNativeHandle);
	if(nativeProp == NULL)
	{
		if (errPtr) *errPtr = [self getStreamError];
		return NO;
	}
	
	CFDataGetBytes(nativeProp, CFRangeMake(0, CFDataGetLength(nativeProp)), (UInt8 *)&native);
	CFRelease(nativeProp);
	
	theSocket = CFSocketCreateWithNative(kCFAllocatorDefault, native, 0, NULL, NULL);
	if(theSocket == NULL)
	{
		if (errPtr) *errPtr = [self getSocketError];
		return NO;
	}

	return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Disconnect Implementation:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Sends error message and disconnects.
- (void) closeWithError:(NSError *)err
{
	if (theFlags & kDidPassConnectMethod)
	{
		// Try to salvage what data we can.
		[self recoverUnreadData];
		
		// Let the delegate know, so it can try to recover if it likes.
		if ([theDelegate respondsToSelector:@selector(onSocket:willDisconnectWithError:)])
			[theDelegate onSocket:self willDisconnectWithError:err];
	}
	[self close];
}

// Prepare partially read data for recovery.
- (void) recoverUnreadData
{
	if (theCurrentRead) [theCurrentRead->buffer setLength: theCurrentRead->bytesDone];
	partialReadBuffer = (theCurrentRead ? [theCurrentRead->buffer copy] : nil);
	[self emptyQueues];
}

- (void) emptyQueues
{
	if (theCurrentRead != nil)	[self endCurrentRead];
	if (theCurrentWrite != nil)	[self endCurrentWrite];
	[theReadQueue removeAllObjects];
	[theWriteQueue removeAllObjects];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(maybeDequeueRead) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(maybeDequeueWrite) object:nil];
}

// Disconnects. This is called for both error and clean disconnections.
- (void) close
{
	// Empty queues.
	[self emptyQueues];
	[partialReadBuffer release];
	partialReadBuffer = nil;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(disconnect) object:nil];	

	// Close streams.
	if (theReadStream != NULL)
	{
		CFReadStreamUnscheduleFromRunLoop (theReadStream, theRunLoop, kCFRunLoopDefaultMode);
		CFReadStreamClose (theReadStream);
		CFRelease (theReadStream);
		theReadStream = NULL;
	}
	if (theWriteStream != NULL)
	{
		CFWriteStreamUnscheduleFromRunLoop (theWriteStream, theRunLoop, kCFRunLoopDefaultMode);
		CFWriteStreamClose (theWriteStream);
		CFRelease (theWriteStream);
		theWriteStream = NULL;
	}

	// Close sockets.
	if (theSocket != NULL)
	{
		CFSocketInvalidate (theSocket);
		CFRelease (theSocket);
		theSocket = NULL;
	}
	if (theSocket6 != NULL)
	{
		CFSocketInvalidate (theSocket6);
		CFRelease (theSocket6);
		theSocket6 = NULL;
	}
	if (theSource != NULL)
	{
		CFRunLoopRemoveSource (theRunLoop, theSource, kCFRunLoopDefaultMode);
		CFRelease (theSource);
		theSource = NULL;
	}
	if (theSource6 != NULL)
	{
		CFRunLoopRemoveSource (theRunLoop, theSource6, kCFRunLoopDefaultMode);
		CFRelease (theSource6);
		theSource6 = NULL;
	}
	theRunLoop = NULL;

	// If the client has passed the connect/accept method, then the connection has at least begun.
	// Notify delegate that it is now ending.
	if (theFlags & kDidPassConnectMethod && theDelegate != nil)
	{
		// Delay notification to give him freedom to release without returning here and core-dumping.
		if ([theDelegate respondsToSelector: @selector(onSocketDidDisconnect:)])
			[theDelegate performSelector:@selector(onSocketDidDisconnect:) withObject:self afterDelay:0];
	}

	// Clear flags.
	theFlags = 0x00;
}

/**
 * Disconnects immediately. Any pending reads or writes are dropped.
**/
- (void) disconnect
{
	[self close];
}

/**
 * Disconnects after all pending writes have completed.
 * After calling this, the read and write methods (including "readDataWithTimeout:tag:") will do nothing.
 * The socket will disconnect even if there are still pending reads.
**/
- (void) disconnectAfterWriting
{
	theFlags |= kForbidReadsWrites;
	theFlags |= kDisconnectSoon;
	[self maybeScheduleDisconnect];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Errors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns a standard error object for the current errno value.
 * Errno is used for low-level BSD socket errors.
**/
- (NSError *)getErrnoError
{
	NSString *errorMsg = [NSString stringWithUTF8String:strerror(errno)];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:userInfo];
}

/**
 * Returns a standard error message for a CFSocket error.
 * Unfortunately, CFSocket offers no feedback on its errors.
**/
- (NSError *)getSocketError
{
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketCFSocketError",
														 @"AsyncSocket", [NSBundle mainBundle],
														 @"General CFSocket error", nil);
	
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AsyncSocketErrorDomain code:AsyncSocketCFSocketError userInfo:info];
}

- (NSError *) getStreamError
{
	CFStreamError err;
	if (theReadStream != NULL)
	{
		err = CFReadStreamGetError (theReadStream);
		if (err.error != 0) return [self errorFromCFStreamError: err];
	}
	
	if (theWriteStream != NULL)
	{
		err = CFWriteStreamGetError (theWriteStream);
		if (err.error != 0) return [self errorFromCFStreamError: err];
	}
	
	return nil;
}

/**
 * Returns a standard AsyncSocket abort error.
**/
- (NSError *)getAbortError
{
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketCanceledError",
														 @"AsyncSocket", [NSBundle mainBundle],
														 @"Connection canceled", nil);
	
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AsyncSocketErrorDomain code:AsyncSocketCanceledError userInfo:info];
}

/**
 * Returns a standard AsyncSocket read timeout error.
**/
- (NSError *)getReadTimeoutError
{
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketReadTimeoutError",
														 @"AsyncSocket", [NSBundle mainBundle],
														 @"Read operation timed out", nil);
	
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AsyncSocketErrorDomain code:AsyncSocketReadTimeoutError userInfo:info];
}

/**
 * Returns a standard AsyncSocket write timeout error.
**/
- (NSError *)getWriteTimeoutError
{
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketWriteTimeoutError",
														 @"AsyncSocket", [NSBundle mainBundle],
														 @"Write operation timed out", nil);
	
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AsyncSocketErrorDomain code:AsyncSocketWriteTimeoutError userInfo:info];
}

- (NSError *)errorFromCFStreamError:(CFStreamError)err
{
	if (err.domain == 0 && err.error == 0) return nil;
	
	// Can't use switch; these constants aren't int literals.
	NSString *domain = @"CFStreamError (unlisted domain)";
	NSString *message = nil;
	
	if(err.domain == kCFStreamErrorDomainPOSIX) {
		domain = NSPOSIXErrorDomain;
	}
	else if(err.domain == kCFStreamErrorDomainMacOSStatus) {
		domain = NSOSStatusErrorDomain;
	}
	else if(err.domain == kCFStreamErrorDomainMach) {
		domain = NSMachErrorDomain;
	}
	else if(err.domain == kCFStreamErrorDomainNetDB)
	{
		domain = @"kCFStreamErrorDomainNetDB";
		message = [NSString stringWithCString:gai_strerror(err.error) encoding:NSASCIIStringEncoding];
	}
	else if(err.domain == kCFStreamErrorDomainNetServices) {
		domain = @"kCFStreamErrorDomainNetServices";
	}
	else if(err.domain == kCFStreamErrorDomainSOCKS) {
		domain = @"kCFStreamErrorDomainSOCKS";
	}
	else if(err.domain == kCFStreamErrorDomainSystemConfiguration) {
		domain = @"kCFStreamErrorDomainSystemConfiguration";
	}
	else if(err.domain == kCFStreamErrorDomainSSL) {
		domain = @"kCFStreamErrorDomainSSL";
	}
	
	NSDictionary *info = nil;
	if(message != nil)
	{
		info = [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
	}
	return [NSError errorWithDomain:domain code:err.error userInfo:info];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Diagnostics
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL) isConnected
{
	return [self isSocketConnected] && [self areStreamsConnected];
}

- (NSString *) connectedHost
{
	if(theSocket)
		return [self connectedHost:theSocket];
	else
		return [self connectedHost:theSocket6];
}

- (UInt16) connectedPort
{
	if(theSocket)
		return [self connectedPort:theSocket];
	else
		return [self connectedPort:theSocket6];
}

- (NSString *)localHost
{
	if(theSocket)
		return [self localHost:theSocket];
	else
		return [self localHost:theSocket6];
}

- (UInt16)localPort
{
	if(theSocket)
		return [self localPort:theSocket];
	else
		return [self localPort:theSocket6];
}

- (NSString *)connectedHost:(CFSocketRef)socket
{
	if (socket == NULL) return nil;
	CFDataRef peeraddr;
	NSString *peerstr = nil;

	if(socket && (peeraddr = CFSocketCopyPeerAddress(socket)))
	{
		peerstr = [self addressHost:peeraddr];
		CFRelease (peeraddr);
	}

	return peerstr;
}

- (UInt16)connectedPort:(CFSocketRef)socket
{
	if (socket == NULL) return 0;
	CFDataRef peeraddr;
	UInt16 peerport = 0;

	if(socket && (peeraddr = CFSocketCopyPeerAddress(socket)))
	{
		peerport = [self addressPort:peeraddr];
		CFRelease (peeraddr);
	}

	return peerport;
}

- (NSString *)localHost:(CFSocketRef)socket
{
	if (socket == NULL) return nil;
	CFDataRef selfaddr;
	NSString *selfstr = nil;

	if(socket && (selfaddr = CFSocketCopyAddress(socket)))
	{
		selfstr = [self addressHost:selfaddr];
		CFRelease (selfaddr);
	}

	return selfstr;
}

- (UInt16)localPort:(CFSocketRef)socket
{
	if (socket == NULL) return 0;
	CFDataRef selfaddr;
	UInt16 selfport = 0;

	if (socket && (selfaddr = CFSocketCopyAddress(socket)))
	{
		selfport = [self addressPort:selfaddr];
		CFRelease (selfaddr);
	}

	return selfport;
}

- (BOOL)isSocketConnected
{
	if (theSocket == NULL && theSocket6 == NULL) return NO;
	return CFSocketIsValid(theSocket) || CFSocketIsValid(theSocket6);
}

- (BOOL) areStreamsConnected
{
	CFStreamStatus s;

	if (theReadStream != NULL)
	{
		s = CFReadStreamGetStatus (theReadStream);
		if ( !(s == kCFStreamStatusOpen || s == kCFStreamStatusReading || s == kCFStreamStatusError) )
			return NO;
	}
	else return NO;

	if (theWriteStream != NULL)
	{
		s = CFWriteStreamGetStatus (theWriteStream);
		if ( !(s == kCFStreamStatusOpen || s == kCFStreamStatusWriting || s == kCFStreamStatusError) )
			return NO;
	}
	else return NO;

	return YES;
}

- (NSString *) addressHost: (CFDataRef)cfaddr
{
	if (cfaddr == NULL) return nil;
	char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
	struct sockaddr *pSockAddr = (struct sockaddr *) CFDataGetBytePtr (cfaddr);
	struct sockaddr_in  *pSockAddrV4 = (struct sockaddr_in *) pSockAddr;
	struct sockaddr_in6 *pSockAddrV6 = (struct sockaddr_in6 *)pSockAddr;

	const void *pAddr = (pSockAddr->sa_family == AF_INET) ?
							(void *)(&(pSockAddrV4->sin_addr)) :
							(void *)(&(pSockAddrV6->sin6_addr));

	const char *pStr = inet_ntop (pSockAddr->sa_family, pAddr, addrBuf, sizeof(addrBuf));
	if (pStr == NULL) [NSException raise: NSInternalInconsistencyException
								  format: @"Cannot convert address to string."];

	return [NSString stringWithCString:pStr encoding:NSASCIIStringEncoding];
}

- (UInt16)addressPort:(CFDataRef)cfaddr
{
	if (cfaddr == NULL) return 0;
	struct sockaddr_in *pAddr = (struct sockaddr_in *) CFDataGetBytePtr (cfaddr);
	return ntohs (pAddr->sin_port);
}

- (NSString *) description
{
	static const char *statstr[] = { "not open", "opening", "open", "reading", "writing", "at end", "closed", "has error" };
	CFStreamStatus rs = (theReadStream != NULL) ? CFReadStreamGetStatus (theReadStream) : 0;
	CFStreamStatus ws = (theWriteStream != NULL) ? CFWriteStreamGetStatus (theWriteStream) : 0;
	NSString *peerstr, *selfstr;
	CFDataRef peeraddr, selfaddr = NULL, selfaddr6 = NULL;

	if (theSocket && (peeraddr = CFSocketCopyPeerAddress (theSocket)))
	{
		peerstr = [NSString stringWithFormat: @"%@ %u", [self addressHost:peeraddr], [self addressPort:peeraddr]];
		CFRelease (peeraddr);
		peeraddr = NULL;
	}
	else peerstr = @"nowhere";

	if (theSocket)  selfaddr  = CFSocketCopyAddress (theSocket);
	if (theSocket6) selfaddr6 = CFSocketCopyAddress (theSocket6);
	if (theSocket || theSocket6)
	{
		if (theSocket6)
		{
			selfstr = [NSString stringWithFormat: @"%@/%@ %u", [self addressHost:selfaddr], [self addressHost:selfaddr6], [self addressPort:selfaddr]];
		}
		else
		{
			selfstr = [NSString stringWithFormat: @"%@ %u", [self addressHost:selfaddr], [self addressPort:selfaddr]];
		}

		if (selfaddr)  CFRelease (selfaddr);
		if (selfaddr6) CFRelease (selfaddr6);
		selfaddr = NULL;
		selfaddr6 = NULL;
	}
	else selfstr = @"nowhere";
	
	NSMutableString *ms = [[NSMutableString alloc] init];
	[ms appendString: [NSString stringWithFormat:@"<AsyncSocket %p #%lu: Socket %p", self, (unsigned long)[self hash], theSocket]];
	[ms appendString: [NSString stringWithFormat:@" local %@ remote %@ ", selfstr, peerstr ]];
	[ms appendString: [NSString stringWithFormat:@"has queued %lu reads %lu writes, ", (unsigned long)[theReadQueue count], (unsigned long)[theWriteQueue count] ]];

	if (theCurrentRead == nil)
		[ms appendString: @"no current read, "];
	else
	{
		int percentDone;
		if ([theCurrentRead->buffer length] != 0)
			percentDone = (float)theCurrentRead->bytesDone /
						  (float)[theCurrentRead->buffer length] * 100.0;
		else
			percentDone = 100;

		[ms appendString: [NSString stringWithFormat:@"currently read %lu bytes (%d%% done), ",
			(unsigned long)[theCurrentRead->buffer length],
			theCurrentRead->bytesDone ? percentDone : 0]];
	}

	if (theCurrentWrite == nil)
		[ms appendString: @"no current write, "];
	else
	{
		int percentDone;
		if ([theCurrentWrite->buffer length] != 0)
			percentDone = (float)theCurrentWrite->bytesDone /
						  (float)[theCurrentWrite->buffer length] * 100.0;
		else
			percentDone = 100;

		[ms appendString: [NSString stringWithFormat:@"currently written %lu (%d%%), ",
			(unsigned long)[theCurrentWrite->buffer length],
			theCurrentWrite->bytesDone ? percentDone : 0]];
	}
	
	[ms appendString: [NSString stringWithFormat:@"read stream %p %s, write stream %p %s", theReadStream, statstr [rs], theWriteStream, statstr [ws] ]];
	if (theFlags & kDisconnectSoon) [ms appendString: @", will disconnect soon"];
	if (![self isConnected]) [ms appendString: @", not connected"];

	 [ms appendString: @">"];

	return [ms autorelease];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Reading
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)readDataToLength:(CFIndex)length withTimeout:(NSTimeInterval)timeout tag:(long)tag;
{
	if (length == 0) return;
	if (theFlags & kForbidReadsWrites) return;
	
	NSMutableData *buffer = [[NSMutableData alloc] initWithLength:length];
	AsyncReadPacket *packet = [[AsyncReadPacket alloc] initWithData:buffer
															timeout:timeout
																tag:tag
												   readAllAvailable:NO
														 terminator:nil
													   bufferOffset:0];

	[theReadQueue addObject:packet];
	[self maybeDequeueRead];

	[packet release];
	[buffer release];
}

- (void)readDataToData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag
{
	if (data == nil || [data length] == 0) return;
	if (theFlags & kForbidReadsWrites) return;
	
	NSMutableData *buffer = [[NSMutableData alloc] initWithLength:0];
	AsyncReadPacket *packet = [[AsyncReadPacket alloc] initWithData:buffer
															timeout:timeout
																tag:tag 
												   readAllAvailable:NO 
														 terminator:data
													   bufferOffset:0];

	[theReadQueue addObject:packet];
	[self maybeDequeueRead];

	[packet release];
	[buffer release];
}

- (void)readDataWithTimeout:(NSTimeInterval)timeout tag:(long)tag
{
	if (theFlags & kForbidReadsWrites) return;
	
	// The partialReadBuffer is used when recovering data from a broken connection.
	NSMutableData *buffer;
	if(partialReadBuffer) {
		buffer = [partialReadBuffer mutableCopy];
	}
	else {
		buffer = [[NSMutableData alloc] initWithLength:0];
	}

	AsyncReadPacket *packet = [[AsyncReadPacket alloc] initWithData:buffer
															timeout:timeout
																tag:tag
												   readAllAvailable:YES
														 terminator:nil
													   bufferOffset:[buffer length]];
	
	[theReadQueue addObject:packet];
	[self maybeDequeueRead];
	
	[packet release];
	[buffer release];
}

/**
 * Puts a maybeDequeueRead on the run loop. 
 * An assumption here is that selectors will be performed consecutively within their priority.
**/
- (void)scheduleDequeueRead
{
	[self performSelector:@selector(maybeDequeueRead) withObject:nil afterDelay:0];
}

/**
 * This method starts a new read, if needed.
 * It is called when a user requests a read,
 * or when a stream opens that may have requested reads sitting in the queue, etc.
**/
- (void)maybeDequeueRead
{
	// If we're not currently processing a read AND
	// we have read requests sitting in the queue AND we have actually have a read stream
	if(theCurrentRead == nil && [theReadQueue count] != 0 && theReadStream != NULL)
	{
		// Get new current read AsyncReadPacket.
		AsyncReadPacket *newPacket = [theReadQueue objectAtIndex:0];
		theCurrentRead = [newPacket retain];
		[theReadQueue removeObjectAtIndex:0];

		// Start time-out timer.
		if(theCurrentRead->timeout >= 0.0)
		{
			theReadTimer = [NSTimer scheduledTimerWithTimeInterval:theCurrentRead->timeout
															target:self 
														  selector:@selector(doReadTimeout:)
														  userInfo:nil
														   repeats:NO];
		}

		// Immediately read, if possible.
		[self doBytesAvailable];
	}
}

/**
 * This method is called when a new read is taken from the read queue or when new data becomes available on the stream.
**/
- (void)doBytesAvailable
{
	// If data is available on the stream, but there is no read request, then we don't need to process the data yet.
	// Also, if there is a read request, but no read stream setup yet, we can't process any data yet.
	if(theCurrentRead != nil && theReadStream != NULL)
	{
		CFIndex totalBytesRead = 0;
		BOOL error = NO, done = NO;
		while(!done && !error && CFReadStreamHasBytesAvailable(theReadStream))
		{
			// If reading all available data, make sure there's room in the packet buffer.
			if(theCurrentRead->readAllAvailableData == YES)
				[theCurrentRead->buffer increaseLengthBy:READALL_CHUNKSIZE];

			// If reading until data, just do one byte.
			if(theCurrentRead->term != nil)
				[theCurrentRead->buffer increaseLengthBy:1];
			
			// Number of bytes to read is space left in packet buffer.
			CFIndex bytesToRead = [theCurrentRead->buffer length] - theCurrentRead->bytesDone;

			// Read stuff into start of unfilled packet buffer space.
			UInt8 *packetbuf = (UInt8 *)( [theCurrentRead->buffer mutableBytes] + theCurrentRead->bytesDone );
			CFIndex bytesRead = CFReadStreamRead (theReadStream, packetbuf, bytesToRead);
			totalBytesRead += bytesRead;

			// Check results.
			if(bytesRead < 0)
			{
				bytesRead = 0;
				error = YES;
			}

			// Is packet done?
			theCurrentRead->bytesDone += bytesRead;
			if(theCurrentRead->readAllAvailableData != YES)
			{
				if(theCurrentRead->term != nil)
				{
					// Search for the terminating sequence in the buffer.
					int termlen = [theCurrentRead->term length];
					if(theCurrentRead->bytesDone >= termlen)
					{
						const void *buf = [theCurrentRead->buffer bytes] + (theCurrentRead->bytesDone - termlen);
						const void *seq = [theCurrentRead->term bytes];
						done = (memcmp (buf, seq, termlen) == 0);
					}
				}
				else
				{
					// Done when (sized) buffer is full.
					done = ([theCurrentRead->buffer length] == theCurrentRead->bytesDone);
				}
			}
			// else readAllAvailable doesn't end until all readable is read.
		}

		if (theCurrentRead->readAllAvailableData && theCurrentRead->bytesDone > 0)
			done = YES;	// Ran out of bytes, so the "read-all-data" type packet is done.

		if(done)
		{
			[self completeCurrentRead];
			if (!error) [self scheduleDequeueRead];
		}
		else if(theCurrentRead->readAllAvailableData == NO)
		{
			// We're not done with the readToLength or readToData yet, but we have read in some bytes
			if ([theDelegate respondsToSelector:@selector(onSocket:didReadPartialDataOfLength:tag:)])
			{
				[theDelegate onSocket:self didReadPartialDataOfLength:totalBytesRead tag:theCurrentRead->tag];
			}
		}

		if(error)
		{
			CFStreamError err = CFReadStreamGetError (theReadStream);
			[self closeWithError: [self errorFromCFStreamError:err]];
			return;
		}
	}
}

// Ends current read and calls delegate.
- (void) completeCurrentRead
{
	NSAssert (theCurrentRead, @"Trying to complete current read when there is no current read.");
	[theCurrentRead->buffer setLength:theCurrentRead->bytesDone];
	if ([theDelegate respondsToSelector:@selector(onSocket:didReadData:withTag:)])
	{
		[theDelegate onSocket:self didReadData:theCurrentRead->buffer withTag:theCurrentRead->tag];
	}
	if (theCurrentRead != nil) [self endCurrentRead]; // Caller may have disconnected.
}

// Ends current read.
- (void) endCurrentRead
{
	NSAssert (theCurrentRead, @"Trying to end current read when there is no current read.");
	[theReadTimer invalidate];
	theReadTimer = nil;
	[theCurrentRead release];
	theCurrentRead = nil;
}

- (void) doReadTimeout:(NSTimer *)timer
{
	if (timer != theReadTimer) return; // Old timer. Ignore it.
	if (theCurrentRead != nil)
	{
		// Send what we got.
		[self endCurrentRead];
	}
	[self closeWithError: [self getReadTimeoutError]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Writing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void) writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag;
{
	if (data == nil || [data length] == 0) return;
	if (theFlags & kForbidReadsWrites) return;
	
	AsyncWritePacket *packet = [[AsyncWritePacket alloc] initWithData:data timeout:timeout tag:tag];
	
	[theWriteQueue addObject:packet];
	[self maybeDequeueWrite];
	
	[packet release];
}

- (void) scheduleDequeueWrite
{
	[self performSelector:@selector(maybeDequeueWrite) withObject:nil afterDelay:0];
}

// Start a new write.
- (void) maybeDequeueWrite
{
	if (theCurrentWrite == nil && [theWriteQueue count] != 0 && theWriteStream != NULL)
	{
		// Get new current write AsyncWritePacket.
		AsyncWritePacket *newPacket = [theWriteQueue objectAtIndex:0];
		theCurrentWrite = [newPacket retain];
		[theWriteQueue removeObjectAtIndex:0];
		
		// Start time-out timer.
		if (theCurrentWrite->timeout >= 0.0)
		{
			theWriteTimer = [NSTimer scheduledTimerWithTimeInterval:theCurrentWrite->timeout
			                                                 target:self
			                                               selector:@selector(doWriteTimeout:)
			                                               userInfo:nil
			                                                repeats:NO];
		}

		// Immediately write, if possible.
		[self doSendBytes];
	}
}

- (void) doSendBytes
{
	if (theCurrentWrite != nil && theWriteStream != NULL)
	{
		BOOL done = NO, error = NO;
		while (!done && !error && CFWriteStreamCanAcceptBytes (theWriteStream))
		{
			// Figure out what to write.
			CFIndex bytesRemaining = [theCurrentWrite->buffer length] - theCurrentWrite->bytesDone;
			CFIndex bytesToWrite = (bytesRemaining < WRITE_CHUNKSIZE) ? bytesRemaining : WRITE_CHUNKSIZE;
			UInt8 *writestart = (UInt8 *)([theCurrentWrite->buffer bytes] + theCurrentWrite->bytesDone);

			// Write.
			CFIndex bytesWritten = CFWriteStreamWrite (theWriteStream, writestart, bytesToWrite);

			// Check results.
			if (bytesWritten < 0)
			{
				bytesWritten = 0;
				error = YES;
			}

			// Is packet done?
			theCurrentWrite->bytesDone += bytesWritten;
			done = ([theCurrentWrite->buffer length] == theCurrentWrite->bytesDone);
		}

		if (done)
		{
			[self completeCurrentWrite];
			if (!error) [self scheduleDequeueWrite];
		}

		if (error)
		{
			CFStreamError err = CFWriteStreamGetError (theWriteStream);
			[self closeWithError: [self errorFromCFStreamError:err]];
			return;
		}
	}
}

// Ends current write and calls delegate.
- (void) completeCurrentWrite
{
	NSAssert (theCurrentWrite, @"Trying to complete current write when there is no current write.");
	if ([theDelegate respondsToSelector:@selector(onSocket:didWriteDataWithTag:)])
	{
		[theDelegate onSocket:self didWriteDataWithTag:theCurrentWrite->tag];
	}
	if (theCurrentWrite != nil) [self endCurrentWrite]; // Caller may have disconnected.
}

// Ends current write.
- (void) endCurrentWrite
{
	NSAssert (theCurrentWrite, @"Trying to complete current write when there is no current write.");
	[theWriteTimer invalidate];
	theWriteTimer = nil;
	[theCurrentWrite release];
	theCurrentWrite = nil;
	[self maybeScheduleDisconnect];
}

// Checks to see if all writes have been completed for disconnectAfterWriting.
- (void) maybeScheduleDisconnect
{
	if (theFlags & kDisconnectSoon)
		if ([theWriteQueue count] == 0 && theCurrentWrite == nil)
			[self performSelector:@selector(disconnect) withObject:nil afterDelay:0];
}

- (void) doWriteTimeout:(NSTimer *)timer
{
	if (timer != theWriteTimer) return; // Old timer. Ignore it.
	if (theCurrentWrite != nil)
	{
		// Send what we got.
		[self endCurrentWrite];
	}
	[self closeWithError: [self getWriteTimeoutError]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark CF Callbacks
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)doCFSocketCallback:(CFSocketCallBackType)type forSocket:(CFSocketRef)sock withAddress:(NSData *)address withData:(const void *)pData
{
	NSParameterAssert ((sock == theSocket) || (sock == theSocket6));
	switch (type)
	{
		case kCFSocketConnectCallBack:
			// The data argument is either NULL or a pointer to an SInt32 error code, if the connect failed.
			if(pData)
				[self doSocketOpenWithCFSocketError:kCFSocketError];
			else
				[self doSocketOpenWithCFSocketError:kCFSocketSuccess];
			break;
		case kCFSocketAcceptCallBack:
			[self doAcceptWithSocket: *((CFSocketNativeHandle *)pData)];
			break;
		default:
			NSLog (@"AsyncSocket %p received unexpected CFSocketCallBackType %lu.", self, type);
			break;
	}
}

- (void)doCFReadStreamCallback:(CFStreamEventType)type forStream:(CFReadStreamRef)stream
{
	CFStreamError err;
	switch (type)
	{
		case kCFStreamEventOpenCompleted:
			[self doStreamOpen];
			break;
		case kCFStreamEventHasBytesAvailable:
			[self doBytesAvailable];
			break;
		case kCFStreamEventErrorOccurred:
		case kCFStreamEventEndEncountered:
			err = CFReadStreamGetError (theReadStream);
			[self closeWithError: [self errorFromCFStreamError:err]];
			break;
		default:
			NSLog (@"AsyncSocket %p received unexpected CFReadStream callback, CFStreamEventType %lu.", self, type);
	}
}

- (void)doCFWriteStreamCallback:(CFStreamEventType)type forStream:(CFWriteStreamRef)stream
{
	CFStreamError err;
	switch (type)
	{
		case kCFStreamEventOpenCompleted:
			[self doStreamOpen];
			break;
		case kCFStreamEventCanAcceptBytes:
			[self doSendBytes];
			break;
		case kCFStreamEventErrorOccurred:
		case kCFStreamEventEndEncountered:
			err = CFWriteStreamGetError (theWriteStream);
			[self closeWithError: [self errorFromCFStreamError:err]];
			break;
		default:
			NSLog (@"AsyncSocket %p received unexpected CFWriteStream callback, CFStreamEventType %lu.", self, type);
	}
}

/**
 * This is the callback we set up for CFSocket.
 * This method does nothing but forward the call to it's Objective-C counterpart
**/
static void MyCFSocketCallback (CFSocketRef sref, CFSocketCallBackType type, CFDataRef address, const void *pData, void *pInfo)
{
	AsyncSocket *socket = (__bridge AsyncSocket *)pInfo;
	[socket doCFSocketCallback:type forSocket:sref withAddress:(__bridge NSData *)address withData:pData];
}

/**
 * This is the callback we set up for CFReadStream.
 * This method does nothing but forward the call to it's Objective-C counterpart
**/
static void MyCFReadStreamCallback (CFReadStreamRef stream, CFStreamEventType type, void *pInfo)
{
	AsyncSocket *socket = (__bridge AsyncSocket *)pInfo;
	
//	NSLog(@"MyCFReadStreamCallback of socket: %@ (0x%08x)\n", socket, (int) socket);
	
	[socket doCFReadStreamCallback:type forStream:stream];
}

/**
 * This is the callback we set up for CFWriteStream.
 * This method does nothing but forward the call to it's Objective-C counterpart
**/
static void MyCFWriteStreamCallback (CFWriteStreamRef stream, CFStreamEventType type, void *pInfo)
{
	AsyncSocket *socket = (__bridge AsyncSocket *)pInfo;
	[socket doCFWriteStreamCallback:type forStream:stream];
}

@end
