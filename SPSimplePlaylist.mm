#import "SPSimplePlaylist.h"
#import "SPPlaylistItem.h"
#import "SPApplicationStorageController.h"


@implementation SPSimplePlaylist


// ----------------------------------------------------------------------------
- (id) init
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		items = [NSMutableArray arrayWithCapacity:16];
	}
	return self;
}


// ----------------------------------------------------------------------------
- (id) initWithCoder:(NSCoder*)coder
// ----------------------------------------------------------------------------
{
	if (self = [super initWithCoder:coder])
	{
		if ([coder allowsKeyedCoding])
			[self setItems:[coder decodeObjectForKey:@"SPKeyItems"]];
		else
			[self setItems:[coder decodeObject]];
	}
	return self;
}


// ----------------------------------------------------------------------------
- (void) encodeWithCoder:(NSCoder*)coder
// ----------------------------------------------------------------------------
{
	[super encodeWithCoder:coder];
    if ([coder allowsKeyedCoding])
        [coder encodeObject:items forKey:@"SPKeyItems"];
	else
		[coder encodeObject:items];
}


// ----------------------------------------------------------------------------
- (void) addItem:(SPPlaylistItem*)newItem
// ----------------------------------------------------------------------------
{
	[items addObject:newItem];
}


// ----------------------------------------------------------------------------
- (void) removeItemsAtIndices:(NSIndexSet*)indices
// ----------------------------------------------------------------------------
{
	[items removeObjectsAtIndexes:indices];
}


// ----------------------------------------------------------------------------
- (NSInteger) moveItemsAtIndices:(NSIndexSet*)indices toIndex:(NSInteger)index
// ----------------------------------------------------------------------------
{
	NSInteger newBaseIndex = index;
	
	if (index < [items count])
	{
		SPPlaylistItem* itemAtIndex = [items objectAtIndex:index];
		
		NSArray* movedItems = [items objectsAtIndexes:indices];
		[items removeObjectsAtIndexes:indices];

		NSInteger newIndex = [items indexOfObjectIdenticalTo:itemAtIndex];
		newBaseIndex = newIndex;
		
		for (SPPlaylistItem* item in movedItems)
		{
			[items insertObject:item atIndex:newIndex];
			newIndex++;
		}
	}
	else
	{
		NSArray* movedItems = [items objectsAtIndexes:indices];
		[items removeObjectsAtIndexes:indices];

		newBaseIndex = [items count];
		
		for (SPPlaylistItem* item in movedItems)
			[items addObject:item];
	}
	
	return newBaseIndex;
}


// ----------------------------------------------------------------------------
- (NSMutableArray*) items
// ----------------------------------------------------------------------------
{
	return items;
}


// ----------------------------------------------------------------------------
- (void) setItems:(NSMutableArray*)itemsArray
// ----------------------------------------------------------------------------
{
	items = itemsArray;
}


// ----------------------------------------------------------------------------
- (NSInteger) count
// ----------------------------------------------------------------------------
{
	return [items count];
}


// ----------------------------------------------------------------------------
- (SPPlaylistItem*) itemAtIndex:(NSInteger)index
// ----------------------------------------------------------------------------
{
	return [items objectAtIndex:index];
}


// ----------------------------------------------------------------------------
- (NSData*) dataRepresentation
// ----------------------------------------------------------------------------
{
	return [NSKeyedArchiver archivedDataWithRootObject:self];
}


// ----------------------------------------------------------------------------
- (BOOL) saveToFile
// ----------------------------------------------------------------------------
{
	NSString* filename = [identifier stringByAppendingPathExtension:[SPSimplePlaylist fileExtension]];
	path = [[SPApplicationStorageController playlistPath] stringByAppendingPathComponent:filename];
	
	NSData* data = [self dataRepresentation];
	BOOL success = [data writeToFile:path atomically:YES];
	return success;
}


// ----------------------------------------------------------------------------
+ (NSString*) fileExtension
// ----------------------------------------------------------------------------
{
	static NSString* extension = @"sidplaylist";

	return extension;
}


// ----------------------------------------------------------------------------
+ (SPSimplePlaylist*) playlistFromData:(NSData*)data
// ----------------------------------------------------------------------------
{
	return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}


// ----------------------------------------------------------------------------
+ (SPSimplePlaylist*) playlistFromSharedSmartPlaylistData:(NSData*)data
// ----------------------------------------------------------------------------
{
	// Shared smart playlist data is just a list of relative path strings
	
	NSString* playlistString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSArray* playlistPaths = [playlistString componentsSeparatedByString:@"\n"];

	SPSimplePlaylist* playlist = [[SPSimplePlaylist alloc] init];
	
	for (NSString* playlistPath in playlistPaths)
	{
		if ([playlistPath length] > 1)
		{
			SPPlaylistItem* item = [[SPPlaylistItem alloc] initWithPath:playlistPath andSubtuneIndex:0 andLoopCount:1];
			[playlist addItem:item];
		}
	}
	
	return playlist;
}

// ----------------------------------------------------------------------------
+ (SPSimplePlaylist*) playlistFromFile:(NSString*)path
// ----------------------------------------------------------------------------
{
	NSData* data = [NSData dataWithContentsOfFile:path];
	SPSimplePlaylist* playlist = [SPSimplePlaylist playlistFromData:data];

	return playlist;
}


// ----------------------------------------------------------------------------
+ (SPSimplePlaylist*) playlistFromSidplay3File:(NSString*)path
// ----------------------------------------------------------------------------
{
	FILE* fp = fopen([path cStringUsingEncoding:NSASCIIStringEncoding], "r");
	if (fp == NULL)
		return nil;

	SPSimplePlaylist* playlist = [[SPSimplePlaylist alloc] init];
	[playlist setName:[path lastPathComponent]];	
	
	const int lineBufferSize = 256;
	char lineBuffer[lineBufferSize];
	
	while (fgets(lineBuffer, lineBufferSize - 1, fp) != NULL)
	{
		NSString* line = [NSString stringWithCString:lineBuffer encoding:NSASCIIStringEncoding];
		NSString* file = nil;
		int subtune = 0;

		line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if ([line length] == 0)
			continue;
		
		NSRange range = [line rangeOfString:@":"];
		if (range.location == NSNotFound)
		{
			file = line;
			subtune = 0;
		}
		else
		{
			file = [line substringToIndex:range.location];
			NSString* subtuneString = [line substringFromIndex:range.location + 2];
			subtune = (int)[subtuneString integerValue];
		}

		if ([file characterAtIndex:0] != '/')
			file = [NSString stringWithFormat:@"/%@", file];

		SPPlaylistItem* item = [[SPPlaylistItem alloc] initWithPath:file andSubtuneIndex:subtune andLoopCount:1];
		[playlist addItem:item];
	}
	
	return playlist;
}


@end
