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

- (instancetype) initWithRootPath:(NSString*)rootPath NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithRootUrlString:(NSString*)urlString NS_DESIGNATED_INITIALIZER;

- (int) getSongLengthByPath:(NSString*)path andSubtune:(int)subtune;
- (int) getSongLengthFromBuffer:(void*)buffer withBufferLength:(int)length andSubtune:(int)subtune;
- (int) getSongLengthFromSidTune:(SidTuneWrapper*)sidtune andSubtune:(int)subtune;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *databasePath;

@end
