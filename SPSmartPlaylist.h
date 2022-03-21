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

- (id) init;
- (id) initWithCoder:(NSCoder*)coder;
- (void) encodeWithCoder:(NSCoder*)coder;

- (NSPredicate*) predicate;
- (void) setPredicate:(NSPredicate*)thePredicate;

- (NSMutableArray*) items;
- (NSInteger) count;
- (SPPlaylistItem*) itemAtIndex:(NSInteger)index;

- (void) startSpotlightQuery:(NSString*)rootPath;
- (void) spotlightResultNotification:(NSNotification *)notification;
- (void) spotlightResultConsumerThread:(id)object;
- (NSPredicate*) convertPredicate:(NSPredicate*)originalPredicate;

- (BOOL) isCachingItems;

- (BOOL) saveToFile;

+ (NSString*) fileExtension;
+ (SPSmartPlaylist*) playlistFromFile:(NSString*)path;

@end

