#import "SongLengthDatabase.h"
#include "SongLength.h"
#include "SidTuneWrapper.h"
#import "SPPlayerWindow.h"

static NSString* SidplaySongLengthDataBaseRelativePath = @"DOCUMENTS/Songlengths.txt";

static SongLengthDatabase* sharedInstance = nil;

@implementation SongLengthDatabase

// ----------------------------------------------------------------------------
+ (SongLengthDatabase*) sharedInstance
// ----------------------------------------------------------------------------
{
	return sharedInstance;
}


// ----------------------------------------------------------------------------
+ (void) setSharedInstance:(SongLengthDatabase*)database;
// ----------------------------------------------------------------------------
{
	sharedInstance = database;
}


// ----------------------------------------------------------------------------
- (instancetype) initWithRootPath:(NSString*)rootPath
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		databaseAvailable = NO;
		collectionRootPath = rootPath;	
		
		if (rootPath == nil)
			return nil;
			
		databasePath = [rootPath stringByAppendingPathComponent:SidplaySongLengthDataBaseRelativePath];
		//NSLog(@"databasePath: %@\n", databasePath);

		bool success = SongLength::init([databasePath cStringUsingEncoding:NSUTF8StringEncoding]);

		if (!success)
			return nil;
			
		databaseAvailable = YES;
	}
	return self;
}


// ----------------------------------------------------------------------------
- (instancetype) initWithRootUrlString:(NSString*)urlString
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		databaseAvailable = NO;
		collectionRootPath = urlString;	
		
		if (urlString == nil)
			return nil;
		
		databasePath = [urlString stringByAppendingPathComponent:SidplaySongLengthDataBaseRelativePath];
		//NSLog(@"databasePath: %@\n", databasePath);
		
		NSURL* url = [NSURL URLWithString:databasePath];
		
		NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
		[request setValue:SPUrlRequestUserAgentString forHTTPHeaderField:@"User-Agent"];
		downloadData = [NSMutableData data];
		downloadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
		//NSLog(@"Songlength database downloading %@\n", databasePath);
	}
	return self;
}


// ----------------------------------------------------------------------------
- (void) connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
// ----------------------------------------------------------------------------
{
	downloadData.length = 0;
}


// ----------------------------------------------------------------------------
- (void) connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
// ----------------------------------------------------------------------------
{
	[downloadData appendData:data];
}


// ----------------------------------------------------------------------------
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
// ----------------------------------------------------------------------------
{
	char* dataBuffer = (char*) downloadData.bytes;
	int size = (int) downloadData.length;
	
	bool success = SongLength::init(dataBuffer, size);
	
	if (!success)
		return;
	
	databaseAvailable = YES;
	
	downloadData = nil;
	downloadConnection = nil;
}


// ----------------------------------------------------------------------------
- (void) finalize
// ----------------------------------------------------------------------------
{
	if (downloadConnection != nil)
	{
		[downloadConnection cancel];
		downloadConnection = nil;
	}
	
	[super finalize];
}


// ----------------------------------------------------------------------------
- (int) getSongLengthByPath:(NSString*)path andSubtune:(int)subtune
// ----------------------------------------------------------------------------
{
	if (!databaseAvailable)
		return 0;
	
	if (path == nil)
		return 0;
	
	SongLengthDBitem item;
	bool success = SongLength::getItem([collectionRootPath cStringUsingEncoding:NSUTF8StringEncoding], [path cStringUsingEncoding:NSUTF8StringEncoding], subtune, item);

	if (success)
		return item.playtime;

	return 0;
}


// ----------------------------------------------------------------------------
- (int) getSongLengthFromBuffer:(void*)buffer withBufferLength:(int)length andSubtune:(int)subtune
// ----------------------------------------------------------------------------
{
	SidTuneWrapper sidtune;
	sidtune.load(buffer, length);
	return [self getSongLengthFromSidTune:&sidtune andSubtune:subtune];
}


// ----------------------------------------------------------------------------
- (int) getSongLengthFromSidTune:(SidTuneWrapper*)sidtune andSubtune:(int)subtune
// ----------------------------------------------------------------------------
{
	if (!databaseAvailable)
		return 0;

	SongLengthDBitem item;
	bool success = SongLength::getItem(sidtune, subtune, item);

	if (success)
		return item.playtime;

	return 0;
}


// ----------------------------------------------------------------------------
- (NSString*) databasePath
// ----------------------------------------------------------------------------
{
	return databasePath;
}


@end
