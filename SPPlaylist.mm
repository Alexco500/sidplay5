#import "SPPlaylist.h"
#import	"SPCollectionUtilities.h"
#import "SPBrowserItem.h"
#import "SPPlaylistItem.h"


@implementation SPPlaylist

@synthesize  lastPlayedItemIndex;

// ----------------------------------------------------------------------------
- (instancetype) init
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil) 
	{
		name = nil;
		path = nil;
		
		CFUUIDRef uuid = CFUUIDCreate(NULL);
		identifier = (NSString *) CFBridgingRelease(CFUUIDCreateString(NULL, uuid));
		CFRelease(uuid);
	}
	return self;
}


// ----------------------------------------------------------------------------
- (instancetype) initWithCoder:(NSCoder*)coder
// ----------------------------------------------------------------------------
{
	if (self = [super init])
	{
		if (coder.allowsKeyedCoding)
		{
			[self setName:[coder decodeObjectForKey:@"SPKeyName"]];
			[self setIdentifier:[coder decodeObjectForKey:@"SPKeyIdentifier"]];
		}
		else
		{
			[self setName:[coder decodeObject]];
			[self setIdentifier:[coder decodeObject]];
		}
	}
	return self;
}


// ----------------------------------------------------------------------------
- (void) encodeWithCoder:(NSCoder*)coder
// ----------------------------------------------------------------------------
{
    if (coder.allowsKeyedCoding)
	{
        [coder encodeObject:name forKey:@"SPKeyName"];
        [coder encodeObject:identifier forKey:@"SPKeyIdentifier"];
	}
	else
	{
		[coder encodeObject:name];
		[coder encodeObject:identifier];
	}
}


// ----------------------------------------------------------------------------
- (NSData*) dataRepresentation
// ----------------------------------------------------------------------------
{
	return nil;
}


// ----------------------------------------------------------------------------
- (BOOL) saveToFile
// ----------------------------------------------------------------------------
{
	return NO;
}


// ----------------------------------------------------------------------------
- (BOOL) saveToM3U:(NSString*)filename withRelativePaths:(BOOL)exportRelativePaths andPathPrefix:(NSString*)pathPrefix
// ----------------------------------------------------------------------------
{
	NSString* m3uOutput = @"#EXTM3U\n";
	for (SPPlaylistItem* item in [self items])
	{
		NSString* relativePath = [item path];
		NSString* absolutePath = [[SPCollectionUtilities sharedInstance] absolutePathFromRelativePath:relativePath];
		SPBrowserItem* browserItem = [[SPBrowserItem alloc] initWithPath:absolutePath isFolder:NO forParent:nil withDefaultSubtune:[item subtune]];
		if (exportRelativePaths)
		{
			NSString* prefixedRelativePath = [pathPrefix stringByAppendingPathComponent:relativePath];
			m3uOutput = [m3uOutput stringByAppendingFormat:@"#EXTINF:%d,%@ - %@\n%@\n", [browserItem playTimeInSeconds], [browserItem author], [browserItem title], prefixedRelativePath];
		}
		else
		{
			m3uOutput = [m3uOutput stringByAppendingFormat:@"#EXTINF:%d,%@ - %@\n%@\n", [browserItem playTimeInSeconds], [browserItem author], [browserItem title], absolutePath];
		}
	}

	BOOL success = [m3uOutput writeToFile:filename atomically:YES encoding:NSISOLatin1StringEncoding error:NULL];
	return success;
}


// ----------------------------------------------------------------------------
- (NSInteger) count
// ----------------------------------------------------------------------------
{
	return 0;
}


// ----------------------------------------------------------------------------
- (SPPlaylistItem*) itemAtIndex:(NSInteger)index
// ----------------------------------------------------------------------------
{
	return nil;
}


// ----------------------------------------------------------------------------
- (NSMutableArray*) items
// ----------------------------------------------------------------------------
{
	return nil;
}


// ----------------------------------------------------------------------------
- (NSString*) name
// ----------------------------------------------------------------------------
{
	return name;
}


// ----------------------------------------------------------------------------
- (void) setName:(NSString*)nameString
// ----------------------------------------------------------------------------
{
	name = nameString;
}


// ----------------------------------------------------------------------------
- (NSString*) identifier
// ----------------------------------------------------------------------------
{
	return identifier;
}


// ----------------------------------------------------------------------------
- (void) setIdentifier:(NSString*)idString
// ----------------------------------------------------------------------------
{
	identifier = idString;
}


// ----------------------------------------------------------------------------
- (NSString*) path
// ----------------------------------------------------------------------------
{
	return path;
}

@end





