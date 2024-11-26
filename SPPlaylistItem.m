#import "SPPlaylistItem.h"


@implementation SPPlaylistItem

// ----------------------------------------------------------------------------
- (instancetype) init
// ----------------------------------------------------------------------------
{
    return [self initWithPath:nil andSubtuneIndex:NULL andLoopCount:NULL];
}

// ----------------------------------------------------------------------------
- (instancetype) initWithPath:(NSString*)relativePath andSubtuneIndex:(NSInteger)subtuneIndex andLoopCount:(NSInteger)loops
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		path = relativePath;
		subtune = subtuneIndex;
		loopCount = loops;
	}
	return self;
}


// ----------------------------------------------------------------------------
- (instancetype) initWithCoder:(NSCoder*)coder
// ----------------------------------------------------------------------------
{
	if (self = [super init])
	{
        [self setPath:[coder decodeObject]];
        [coder decodeValueOfObjCType:@encode(int) at:&subtune];
        [coder decodeValueOfObjCType:@encode(int) at:&loopCount];
	}
	return self;
}


// ----------------------------------------------------------------------------
- (void) encodeWithCoder:(NSCoder*)coder
// ----------------------------------------------------------------------------
{
    [coder encodeObject:path];
    [coder encodeValueOfObjCType:@encode(int) at:&subtune];
    [coder encodeValueOfObjCType:@encode(int) at:&loopCount];
}


// ----------------------------------------------------------------------------
- (NSString*) path
// ----------------------------------------------------------------------------
{
	return path;
}


// ----------------------------------------------------------------------------
- (void) setPath:(NSString*)pathString
// ----------------------------------------------------------------------------
{
	path = pathString;
}


// ----------------------------------------------------------------------------
- (NSInteger) subtune
// ----------------------------------------------------------------------------
{
	return subtune;
}


// ----------------------------------------------------------------------------
- (void) setSubtune:(NSInteger)subtuneIndex
// ----------------------------------------------------------------------------
{
	subtune = subtuneIndex;
}


// ----------------------------------------------------------------------------
- (NSInteger) loopCount
// ----------------------------------------------------------------------------
{
	return loopCount;
}


// ----------------------------------------------------------------------------
- (void) setLoopCount:(NSInteger)loops
// ----------------------------------------------------------------------------
{
	loopCount = loops;
}


@end
