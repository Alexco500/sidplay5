#import <Cocoa/Cocoa.h>
#import "SPPlaylist.h"


@interface SPSimplePlaylist : SPPlaylist
{
	NSMutableArray* items;
}

- (id) init;
- (id) initWithCoder:(NSCoder*)coder;
- (void) encodeWithCoder:(NSCoder*)coder;

- (void) addItem:(SPPlaylistItem*)newItem;
- (void) removeItemsAtIndices:(NSIndexSet*)indices;
- (NSInteger) moveItemsAtIndices:(NSIndexSet*)indices toIndex:(NSInteger)index;

- (NSMutableArray*) items;
- (void) setItems:(NSMutableArray*)itemsArray;

- (NSData*) dataRepresentation;
- (BOOL) saveToFile;

+ (NSString*) fileExtension;
+ (SPSimplePlaylist*) playlistFromData:(NSData*)data;
+ (SPSimplePlaylist*) playlistFromSharedSmartPlaylistData:(NSData*)data;
+ (SPSimplePlaylist*) playlistFromFile:(NSString*)path;
+ (SPSimplePlaylist*) playlistFromSidplay3File:(NSString*)path;

@end
