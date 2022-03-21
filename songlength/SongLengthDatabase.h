#import <Cocoa/Cocoa.h>

class SidTuneWrapper;

@interface SongLengthDatabase : NSObject
{
	BOOL databaseAvailable;
	NSString* collectionRootPath;
	NSString* databasePath;
	
	NSMutableData* downloadData;
    NSURLConnection* downloadConnection;
}

+ (SongLengthDatabase*) sharedInstance;
+ (void) setSharedInstance:(SongLengthDatabase*)database;

- (id) initWithRootPath:(NSString*)rootPath;
- (id) initWithRootUrlString:(NSString*)urlString;

- (int) getSongLengthByPath:(NSString*)path andSubtune:(int)subtune;
- (int) getSongLengthFromBuffer:(void*)buffer withBufferLength:(int)length andSubtune:(int)subtune;
- (int) getSongLengthFromSidTune:(SidTuneWrapper*)sidtune andSubtune:(int)subtune;

- (NSString*) databasePath;

@end
