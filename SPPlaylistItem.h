#import <Cocoa/Cocoa.h>


@interface SPPlaylistItem : NSObject
{
	NSString* path;
	NSInteger subtune;
	NSInteger loopCount;
}

- (instancetype) initWithPath:(NSString*)relativePath andSubtuneIndex:(NSInteger)subtuneIndex andLoopCount:(NSInteger)loops NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;
- (void) encodeWithCoder:(NSCoder*)coder;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *path;

@property (NS_NONATOMIC_IOSONLY) NSInteger subtune;

@property (NS_NONATOMIC_IOSONLY) NSInteger loopCount;

@end


