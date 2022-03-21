#import <Cocoa/Cocoa.h>


@class SPPlaylist;

extern NSString* SPSharedPlaylistIndexDownloaded;

enum SourceListItemType
{
	SOURCELIST_INVALID = 0,
	SOURCELIST_HEADER,
	SOURCELIST_COLLECTION,
	SOURCELIST_PLAYLIST,
	SOURCELIST_SMARTPLAYLIST,
	SOURCELIST_SHAREDCOLLECTION,
	SOURCELIST_SHAREDPLAYLIST,
	SOURCELIST_SHAREDSMARTPLAYLIST
};


@interface SPSourceListItem : NSObject
{
	SourceListItemType type;
	NSAttributedString* name;
	NSString* path;
	NSImage* icon;
	SPPlaylist* playlist;
	NSNetService* service;
	NSMutableArray* children;
	
	NSMutableData* playlistIndexDownloadData;
	NSURLConnection* playlistIndexDownloadConnection;
	NSMutableData* playlistDownloadData;
	NSURLConnection* playlistDownloadConnection;
	NSURLConnection* updateRevisionConnection;
	NSMutableData* updateRevisionData;
	NSInteger currentRemoveUpdateRevision;
	
	BOOL isPlaylistShared;	
	BOOL isPathValid;
}

- (id) initWithName:(NSAttributedString*)theName forPath:(NSString*)thePath withIcon:(NSImage*)theIcon;
- (void) addChild:(SPSourceListItem*)item;
- (void) insertChild:(SPSourceListItem*)item atIndex:(NSInteger)index;
- (SPSourceListItem*) childAtIndex:(int)index;

- (id) initWithCoder:(NSCoder*)coder;
- (void) encodeWithCoder:(NSCoder*)coder;

- (NSAttributedString*)name;
- (void) setName:(NSAttributedString*)nameString;
- (void) setNameFromString:(NSString*)nameString;

- (NSString*) path;
- (void) setPath:(NSString*)pathString;

- (NSImage*) icon;
- (void) setIcon:(NSImage*)image;

- (SPPlaylist*) playlist;
- (void) setPlaylist:(SPPlaylist*)thePlaylist;

- (NSNetService*) service;
- (void) setService:(NSNetService*)theService;

- (SourceListItemType) type;
- (void) setType:(SourceListItemType)theType;
- (BOOL) isHeader;
- (BOOL) isCollectionItem;
- (BOOL) isPlaylistItem;
- (BOOL) isSmartPlaylistItem;
- (BOOL) isSharedCollectionItem;
- (BOOL) isSharedPlaylistItem;
- (BOOL) isSharedSmartPlaylistItem;

- (BOOL) hasChildren;
- (NSMutableArray*) children;
- (void) setChildren:(NSMutableArray*)array;

- (BOOL) isPathValid;
- (void) setIsPathValid:(BOOL)valid;

- (BOOL) isPlaylistShared;
- (void) setIsPlaylistShared:(BOOL)isShared;

- (void) downloadSharedPlaylists;
- (void) downloadSharedPlaylistFromUrl:(NSString*)urlString;
- (void) checkForRemoteUpdateRevisionChange;

- (NSComparisonResult) compare:(SPSourceListItem *)otherItem;

+ (NSImage*) playlistIcon;
+ (NSImage*) smartPlaylistIcon;
+ (NSImage*) sharedCollectionIcon;

@end
