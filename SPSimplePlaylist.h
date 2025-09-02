#import <Cocoa/Cocoa.h>
#import "SPPlaylist.h"


@interface SPSimplePlaylist : SPPlaylist
{
	NSMutableArray* items;
}

- (instancetype) init NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;
- (void) encodeWithCoder:(NSCoder*)coder;

- (void) addItem:(SPPlaylistItem*)newItem;
- (void) removeItemsAtIndices:(NSIndexSet*)indices;
- (NSInteger) moveItemsAtIndices:(NSIndexSet*)indices toIndex:(NSInteger)index;
- (void) shuffleMe;

@property (NS_NONATOMIC_IOSONLY, copy) NSMutableArray *items;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSData *dataRepresentation;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL saveToFile;

+ (NSString*) fileExtension;
+ (SPSimplePlaylist*) playlistFromData:(NSData*)data;
+ (SPSimplePlaylist*) playlistFromFile:(NSString*)path;
+ (SPSimplePlaylist*) playlistFromSidplay3File:(NSString*)path;

@end
