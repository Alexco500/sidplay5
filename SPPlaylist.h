#import <Cocoa/Cocoa.h>

@class SPPlaylistItem;


@interface SPPlaylist : NSObject
{
	NSString* name;
	NSString* identifier;
	NSString* path;
}

- (id) initWithCoder:(NSCoder*)coder;
- (void) encodeWithCoder:(NSCoder*)coder;

- (NSInteger) count;
- (SPPlaylistItem*) itemAtIndex:(NSInteger)index;
- (NSMutableArray*) items;

- (NSString*) name;
- (void) setName:(NSString*)nameString;

- (NSString*) identifier;
- (void) setIdentifier:(NSString*)idString;

- (NSString*) path;
- (NSData*) dataRepresentation;
- (BOOL) saveToFile;
- (BOOL) saveToM3U:(NSString*)filename withRelativePaths:(BOOL)exportRelativePaths andPathPrefix:(NSString*)pathPrefix;

@end
