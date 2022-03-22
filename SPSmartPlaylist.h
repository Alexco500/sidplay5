#import <Cocoa/Cocoa.h>
#import "SPPlaylist.h"


extern NSString* SPSmartPlaylistChangedNotification;


@interface SPSmartPlaylist : SPPlaylist <NSMetadataQueryDelegate>
{
	NSPredicate* predicate;
	NSMutableArray* cachedItems;
	BOOL isCachingItems;
	BOOL abortCaching;
	NSMetadataQuery* smartPlaylistQuery;
}

- (instancetype) init NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;
- (void) encodeWithCoder:(NSCoder*)coder;

@property (NS_NONATOMIC_IOSONLY, copy) NSPredicate *predicate;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMutableArray *items;
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger count;
- (SPPlaylistItem*) itemAtIndex:(NSInteger)index;

- (void) startSpotlightQuery:(NSString*)rootPath;
- (void) spotlightResultNotification:(NSNotification *)notification;
- (void) spotlightResultConsumerThread:(id)object;
- (NSPredicate*) convertPredicate:(NSPredicate*)originalPredicate;

@property (NS_NONATOMIC_IOSONLY, getter=isCachingItems, readonly) BOOL cachingItems;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL saveToFile;

+ (NSString*) fileExtension;
+ (SPSmartPlaylist*) playlistFromFile:(NSString*)path;

@end

