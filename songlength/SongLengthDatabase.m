#import "SongLengthDatabase.h"
#import "SidTuneWrapper.h"
#import "SPPlayerWindow.h"

#include "SongLength.h"
#include "Item.h"

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
        songLength = nil;
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
            
            songLength =  [[SongLength alloc] initWithFile:[databasePath cStringUsingEncoding:NSUTF8StringEncoding]];
            if ([songLength isAvailable]) {
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

		//NSLog(@"Songlength database downloading %@\n", databasePath);
        /*
        // moved from NSURLConnection to NSURLSession, according to
        // https://www.objc.io/issues/5-ios7/from-nsurlconnection-to-nsurlsession/
         */
        downloadConnection = [NSURLSession sharedSession];
        NSURLSessionDataTask *dwnTask = [downloadConnection dataTaskWithRequest:request
                                                                   completionHandler:
                                         ^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"Error: %@", error.localizedDescription);
            } else {
                [self->downloadData appendData:data];
                [self connectionDidFinishLoading:self->downloadConnection];
            }
        }];
        
        [dwnTask resume];
	}
	return self;
}

// ----------------------------------------------------------------------------
- (void)connectionDidFinishLoading:(NSURLSession *)connection
// ----------------------------------------------------------------------------
{
	char* dataBuffer = (char*) downloadData.bytes;
	int size = (int) downloadData.length;
	
    SongLength *dummy =  [[SongLength alloc] initWithDB:dataBuffer andSize:size];
   
    bool success = [dummy isAvailable];
	
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
        [downloadConnection invalidateAndCancel];
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
        struct SongLengthDBitem item;
        item.playtime = 0;
       
 
        if ([songLength isAvailable]) {
            bool success = [songLength getItem:[collectionRootPath cStringUsingEncoding:NSUTF8StringEncoding]
                                          file:[path cStringUsingEncoding:NSUTF8StringEncoding]
                                          song:subtune item:&item];
            
            if (success)
                return item.playtime;
        }
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
        SidTuneWrapper* sidtune = [[SidTuneWrapper alloc] init];
        [sidtune load:buffer withLength:length];
        return [self getSongLengthFromSidTune:sidtune andSubtune:subtune];
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

    struct SongLengthDBitem item;
    bool success = [songLength getItem:sidtune number:subtune item:&item];

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
