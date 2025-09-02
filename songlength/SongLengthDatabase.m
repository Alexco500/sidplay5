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
