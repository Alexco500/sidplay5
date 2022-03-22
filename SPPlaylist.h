#import <Cocoa/Cocoa.h>

@class SPPlaylistItem;


@interface SPPlaylist : NSObject
{
	NSString* name;
	NSString* identifier;
	NSString* path;
}

- (instancetype) initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;
- (void) encodeWithCoder:(NSCoder*)coder;

@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger count;
- (SPPlaylistItem*) itemAtIndex:(NSInteger)index;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMutableArray *items;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *name;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *identifier;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *path;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSData *dataRepresentation;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL saveToFile;
- (BOOL) saveToM3U:(NSString*)filename withRelativePaths:(BOOL)exportRelativePaths andPathPrefix:(NSString*)pathPrefix;

@end
