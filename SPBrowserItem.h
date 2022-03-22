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

- (instancetype) initWithPath:(NSString*)thePath isFolder:(BOOL)folder forParent:(SPBrowserItem*)parentItem withDefaultSubtune:(NSInteger)subtuneIndex NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithMetaDataItem:(NSMetadataItem*)item NS_DESIGNATED_INITIALIZER;
- (void) addChild:(SPBrowserItem*)item;
- (id) childAtIndex:(int)index;

+ (void) fillArray:(NSMutableArray*)browserItems withDirectoryContentsAtPath:(NSString*)rootPath andParent:(SPBrowserItem*)parentItem;
+ (void) fillArray:(NSMutableArray*)browserItems withMetaDataQueryResults:(NSArray*)results;
+ (void) fillArray:(NSMutableArray*)browserItems withPlaylist:(SPPlaylist*)playlist;

@property (NS_NONATOMIC_IOSONLY) BOOL isFolder;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *title;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *author;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *releaseInfo;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *path;

@property (NS_NONATOMIC_IOSONLY) int playTimeInSeconds;
@property (NS_NONATOMIC_IOSONLY, readonly) int playTimeMinutes;
@property (NS_NONATOMIC_IOSONLY, readonly) int playTimeSeconds;

- (unsigned short) defaultSubTune;
- (void) setDefaultSubTune:(unsigned short)subtune;

@property (NS_NONATOMIC_IOSONLY) unsigned short subTuneCount;

@property (NS_NONATOMIC_IOSONLY) NSInteger playlistIndex;

@property (NS_NONATOMIC_IOSONLY) NSInteger loopCount;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL fileDoesNotExist;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL hasChildren;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMutableArray *children;

@property (NS_NONATOMIC_IOSONLY, readonly, strong) SPBrowserItem *parent;

@end
