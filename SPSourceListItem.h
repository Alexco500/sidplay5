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
	enum SourceListItemType type;
	NSAttributedString* name;
	NSString* path;
	NSImage* icon;
	SPPlaylist* playlist;
	NSNetService* service;
	NSMutableArray* children;
	
	NSMutableData* playlistIndexDownloadData;
    NSURLSession* playlistIndexDownloadConnection;
	NSMutableData* playlistDownloadData;
    NSURLSession* playlistDownloadConnection;
    NSURLSession* updateRevisionConnection;
	NSMutableData* updateRevisionData;
	NSInteger currentRemoveUpdateRevision;
	
	BOOL isPlaylistShared;	
	BOOL isPathValid;
}

- (instancetype) initWithName:(NSAttributedString*)theName forPath:(NSString*)thePath withIcon:(NSImage*)theIcon NS_DESIGNATED_INITIALIZER;
- (void) addChild:(SPSourceListItem*)item;
- (void) insertChild:(SPSourceListItem*)item atIndex:(NSInteger)index;
- (SPSourceListItem*) childAtIndex:(int)index;

- (instancetype) initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;
- (void) encodeWithCoder:(NSCoder*)coder;

@property (NS_NONATOMIC_IOSONLY, copy) NSAttributedString *name;
- (void) setNameFromString:(NSString*)nameString;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *path;

@property (NS_NONATOMIC_IOSONLY, copy) NSImage *icon;

@property (NS_NONATOMIC_IOSONLY, strong) SPPlaylist *playlist;

@property (NS_NONATOMIC_IOSONLY, strong) NSNetService *service;

@property (NS_NONATOMIC_IOSONLY) enum SourceListItemType type;
@property (NS_NONATOMIC_IOSONLY, getter=isHeader, readonly) BOOL header;
@property (NS_NONATOMIC_IOSONLY, getter=isCollectionItem, readonly) BOOL collectionItem;
@property (NS_NONATOMIC_IOSONLY, getter=isPlaylistItem, readonly) BOOL playlistItem;
@property (NS_NONATOMIC_IOSONLY, getter=isSmartPlaylistItem, readonly) BOOL smartPlaylistItem;
@property (NS_NONATOMIC_IOSONLY, getter=isSharedCollectionItem, readonly) BOOL sharedCollectionItem;
@property (NS_NONATOMIC_IOSONLY, getter=isSharedPlaylistItem, readonly) BOOL sharedPlaylistItem;
@property (NS_NONATOMIC_IOSONLY, getter=isSharedSmartPlaylistItem, readonly) BOOL sharedSmartPlaylistItem;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL hasChildren;
@property (NS_NONATOMIC_IOSONLY, copy) NSMutableArray *children;

@property (NS_NONATOMIC_IOSONLY) BOOL isPathValid;

@property (NS_NONATOMIC_IOSONLY) BOOL isPlaylistShared;

- (void) downloadSharedPlaylists;
- (void) downloadSharedPlaylistFromUrl:(NSString*)urlString;
- (void) checkForRemoteUpdateRevisionChange;

- (NSComparisonResult) compare:(SPSourceListItem *)otherItem;

+ (NSImage*) playlistIcon;
+ (NSImage*) smartPlaylistIcon;
+ (NSImage*) sharedCollectionIcon;

@end
