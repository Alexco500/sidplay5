#import <Cocoa/Cocoa.h>

@class SPPlaylist;

@interface SPBrowserItem : NSObject
{
	BOOL isFolder;

	NSString* title;
	NSString* author;
	NSString* releaseInfo;
	NSString* path;

	int playTimeInSeconds;
	int playTimeMinutes;
	int playTimeSeconds;
	unsigned short defaultSubTune;
	unsigned short subTuneCount;
	NSInteger playlistIndex;
	NSInteger loopCount;
	
	BOOL fileDoesNotExist;

	NSMutableArray* children;
	SPBrowserItem* parent;
}

- (id) initWithPath:(NSString*)thePath isFolder:(BOOL)folder forParent:(SPBrowserItem*)parentItem withDefaultSubtune:(NSInteger)subtuneIndex;
- (id) initWithMetaDataItem:(NSMetadataItem*)item;
- (void) addChild:(SPBrowserItem*)item;
- (id) childAtIndex:(int)index;

+ (void) fillArray:(NSMutableArray*)browserItems withDirectoryContentsAtPath:(NSString*)rootPath andParent:(SPBrowserItem*)parentItem;
+ (void) fillArray:(NSMutableArray*)browserItems withMetaDataQueryResults:(NSArray*)results;
+ (void) fillArray:(NSMutableArray*)browserItems withPlaylist:(SPPlaylist*)playlist;

- (BOOL) isFolder;
- (void) setIsFolder:(BOOL)flag;

- (NSString*) title;
- (void) setTitle:(NSString*)newTitle;

- (NSString*) author;
- (void) setAuthor:(NSString*)newAuthor;

- (NSString*) releaseInfo;
- (void) setReleaseInfo:(NSString*)newReleaseInfo;

- (NSString*) path;
- (void) setPath:(NSString*)newPath;

- (int) playTimeInSeconds;
- (void) setPlayTimeInSeconds:(int)seconds;
- (int) playTimeMinutes;
- (int) playTimeSeconds;

- (unsigned short) defaultSubTune;
- (void) setDefaultSubTune:(unsigned short)subtune;

- (unsigned short) subTuneCount;
- (void) setSubTuneCount:(unsigned short)count;

- (NSInteger) playlistIndex;
- (void) setPlaylistIndex:(NSInteger)indexValue;

- (NSInteger) loopCount;
- (void) setLoopCount:(NSInteger)count;

- (BOOL) fileDoesNotExist;

- (BOOL) hasChildren;
- (NSMutableArray*) children;

- (SPBrowserItem*) parent;

@end
