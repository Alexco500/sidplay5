#import <Cocoa/Cocoa.h>
#import "NewMD5SongLengthDatabase.h"
#import "SidTuneWrapper.h"


@interface SongLengthDatabase : NSObject
{
	BOOL databaseAvailable;
    BOOL newMD5FormatUsed;
	NSString* collectionRootPath;
	NSString* databasePath;
    NewMD5SongLengthDatabase* newMD5db;
	
	NSMutableData* downloadData;
    NSURLConnection* downloadConnection;
}

+ (SongLengthDatabase*) sharedInstance;
+ (void) setSharedInstance:(SongLengthDatabase*)database;
- (instancetype) init NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithRootPath:(NSString*)rootPath NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithRootUrlString:(NSString*)urlString NS_DESIGNATED_INITIALIZER;

- (int) getSongLengthByPath:(NSString*)path andSubtune:(int)subtune;
- (int) getSongLengthFromBuffer:(void*)buffer withBufferLength:(int)length andSubtune:(int)subtune;
- (int) getSongLengthFromSidTune:(SidTuneWrapper*)sidtune andSubtune:(int)subtune;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *databasePath;

@end
