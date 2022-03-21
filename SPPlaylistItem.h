#import <Cocoa/Cocoa.h>


@interface SPPlaylistItem : NSObject
{
	NSString* path;
	NSInteger subtune;
	NSInteger loopCount;
}

- (id) initWithPath:(NSString*)relativePath andSubtuneIndex:(NSInteger)subtuneIndex andLoopCount:(NSInteger)loops;
- (id) initWithCoder:(NSCoder*)coder;
- (void) encodeWithCoder:(NSCoder*)coder;

- (NSString*) path;
- (void) setPath:(NSString*)pathString;

- (NSInteger) subtune;
- (void) setSubtune:(NSInteger)subtuneIndex;

- (NSInteger) loopCount;
- (void) setLoopCount:(NSInteger)loops;

@end


