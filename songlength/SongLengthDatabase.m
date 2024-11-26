#import "SongLengthDatabase.h"
#include "SongLength.h"
#include "SidTuneWrapper.h"
#import "SPPlayerWindow.h"

static NSString* SidplaySongLengthDataBaseRelativePath = @"DOCUMENTS/Songlengths.txt";
static NSString* SidplaySongLengthDataBaseRelativePathNewMD5 = @"DOCUMENTS/Songlengths.md5";

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
- (instancetype) init
// ----------------------------------------------------------------------------
{
    self = [super init];
    if (self != nil)
    {
        databaseAvailable = NO;
        newMD5FormatUsed = NO;
    }
    return self;
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
        bool success;
		if (rootPath == nil)
			return nil;
        newMD5FormatUsed = NO;
        // check for new MD5 DB
        databasePath = [rootPath stringByAppendingPathComponent:SidplaySongLengthDataBaseRelativePathNewMD5];
        //NSLog(@"databasePath: %@\n", databasePath);
        newMD5db = [[NewMD5SongLengthDatabase alloc] initWithPath:databasePath];
        success = [newMD5db validDatabase];
        if (success) {
            newMD5FormatUsed = YES;
            databaseAvailable = YES;
            return self;
        } else {
            // failed, check for old DB
            databasePath = [rootPath stringByAppendingPathComponent:SidplaySongLengthDataBaseRelativePath];
            //NSLog(@"databasePath: %@\n", databasePath);
            
            success = SongLength::init([databasePath cStringUsingEncoding:NSUTF8StringEncoding]);
            if (success) {
                databaseAvailable = YES;
                return self;
            }
        }
	}
    return nil;
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
	
    if (!success) {
        newMD5db = [[NewMD5SongLengthDatabase alloc] initWithData:downloadData];
        if (![newMD5db validDatabase])
            return;
        newMD5FormatUsed = YES;
    }
	
	databaseAvailable = YES;
	
	downloadData = nil;
	downloadConnection = nil;
}


// ----------------------------------------------------------------------------
- (void) dealloc
// ----------------------------------------------------------------------------
{
    // changed finalize back to dealloc
	if (downloadConnection != nil)
	{
		[downloadConnection cancel];
		downloadConnection = nil;
	}
	
	//[super finalize];
}


// ----------------------------------------------------------------------------
- (int) getSongLengthByPath:(NSString*)path andSubtune:(int)subtune
// ----------------------------------------------------------------------------
{
	if (!databaseAvailable)
		return 0;
	
	if (path == nil)
		return 0;
    if (!newMD5FormatUsed) {
        SongLengthDBitem item;
        bool success = SongLength::getItem([collectionRootPath cStringUsingEncoding:NSUTF8StringEncoding], [path cStringUsingEncoding:NSUTF8StringEncoding], subtune, item);

        if (success)
            return item.playtime;
    } else {
        return [newMD5db getSongLengthByPath:path andSubtune:subtune];
    }
    return 0;
}


// ----------------------------------------------------------------------------
- (int) getSongLengthFromBuffer:(void*)buffer withBufferLength:(int)length andSubtune:(int)subtune
// ----------------------------------------------------------------------------
{
    if (!newMD5FormatUsed) {
        SidTuneWrapper sidtune;
        sidtune.load(buffer, length);
        return [self getSongLengthFromSidTune:&sidtune andSubtune:subtune];
    } else {
        return [newMD5db getSongLengthFromBuffer:buffer withBufferLength:length andSubtune:subtune];
    }
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
