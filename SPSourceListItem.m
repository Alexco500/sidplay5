#import "SPSourceListItem.h"
#import "SPPlayerWindow.h"
#import "SPSourceListDataSource.h"
#import "SPSimplePlaylist.h"


@implementation SPSourceListItem


static NSImage* sPlaylistIcon = nil;
static NSImage* sSmartPlaylistIcon = nil;

// ----------------------------------------------------------------------------
- (instancetype) init
// ----------------------------------------------------------------------------
{
    return [self initWithName:nil forPath:nil withIcon:nil];
}
// ----------------------------------------------------------------------------
- (instancetype) initWithName:(NSAttributedString*)theName forPath:(NSString*)thePath withIcon:(NSImage*)theIcon
// ----------------------------------------------------------------------------
{
    if (self = [super init]) 
	{
		type = SOURCELIST_INVALID;
        name = theName;
		path = thePath;
		icon = theIcon;
		playlist = nil;
		isPathValid = NO;
		children = nil;
    }
    return self;
}


// ----------------------------------------------------------------------------
- (instancetype) initWithCoder:(NSCoder*)coder
// ----------------------------------------------------------------------------
{
	if (self = [super init])
	{
		[self setType:(enum SourceListItemType)[coder decodeIntForKey:@"type"]];
		[self setName:[coder decodeObjectForKey:@"name"]];
		[self setPath:[coder decodeObjectForKey:@"path"]];
		[self setIcon:[coder decodeObjectForKey:@"icon"]];
		[self setChildren:[coder decodeObjectForKey:@"children"]];
	}
	return self;
}


// ----------------------------------------------------------------------------
- (void) encodeWithCoder:(NSCoder*)coder
// ----------------------------------------------------------------------------
{
	//[super encodeWithCoder:coder];
	
	[coder encodeInt:type forKey:@"type"];
	[coder encodeObject:name forKey:@"name"];
	[coder encodeObject:path forKey:@"path"];
	[coder encodeObject:icon forKey:@"icon"];
	[coder encodeObject:children forKey:@"children"];
}


// ----------------------------------------------------------------------------
- (NSAttributedString*) name
// ----------------------------------------------------------------------------
{
	return name;
}


// ----------------------------------------------------------------------------
- (void) setName:(NSAttributedString*)nameString
// ----------------------------------------------------------------------------
{
	name = nameString;
}


// ----------------------------------------------------------------------------
- (void) setNameFromString:(NSString*)nameString
// ----------------------------------------------------------------------------
{
	NSMutableParagraphStyle* paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;

	NSDictionary* headerAttrs = @{NSFontAttributeName: [NSFont systemFontOfSize:11.0f], 
																			NSParagraphStyleAttributeName: paragraphStyle};
	name = [[NSAttributedString alloc] initWithString:nameString attributes:headerAttrs];
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
- (NSImage*) icon
// ----------------------------------------------------------------------------
{
	return icon;
}


// ----------------------------------------------------------------------------
- (void) setIcon:(NSImage*)image
// ----------------------------------------------------------------------------
{
	icon = image;
}


// ----------------------------------------------------------------------------
- (SPPlaylist*) playlist
// ----------------------------------------------------------------------------
{
	return playlist;
}


// ----------------------------------------------------------------------------
- (void) setPlaylist:(SPPlaylist*)thePlaylist
// ----------------------------------------------------------------------------
{
	playlist = thePlaylist;
}


// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
- (enum SourceListItemType) type
// ----------------------------------------------------------------------------
{
	return type;
}


// ----------------------------------------------------------------------------
- (void) setType:(enum SourceListItemType)theType
// ----------------------------------------------------------------------------
{
	type = theType;
	
}

// ----------------------------------------------------------------------------
- (BOOL) isHeader
// ----------------------------------------------------------------------------
{
	return type == SOURCELIST_HEADER;
}


// ----------------------------------------------------------------------------
- (BOOL) isCollectionItem
// ----------------------------------------------------------------------------
{
	return type == SOURCELIST_COLLECTION;
}


// ----------------------------------------------------------------------------
- (BOOL) isPlaylistItem
// ----------------------------------------------------------------------------
{
	return type == SOURCELIST_PLAYLIST;
}


// ----------------------------------------------------------------------------
- (BOOL) isSmartPlaylistItem
// ----------------------------------------------------------------------------
{
	return type == SOURCELIST_SMARTPLAYLIST;
}


// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
- (void) addChild:(SPSourceListItem*)item
// ----------------------------------------------------------------------------
{
	if (children == nil)
		children = [[NSMutableArray alloc] init];
		
	[children addObject:item];
}


// ----------------------------------------------------------------------------
- (void) insertChild:(SPSourceListItem*)item atIndex:(NSInteger)index
// ----------------------------------------------------------------------------
{
	if (children == nil)
		children = [[NSMutableArray alloc] init];

	[children insertObject:item atIndex:index];
}


// ----------------------------------------------------------------------------
- (SPSourceListItem*) childAtIndex:(int)index
// ----------------------------------------------------------------------------
{
	if (children == nil)
		return nil;
	
	if (index < children.count)
		return children[index];
	else
		return nil;
}


// ----------------------------------------------------------------------------
- (BOOL) hasChildren
// ----------------------------------------------------------------------------
{
	if (children == nil)
		return NO;

	return (children.count > 0);
}


// ----------------------------------------------------------------------------
- (NSMutableArray*) children
// ----------------------------------------------------------------------------
{
	return children;
}


// ----------------------------------------------------------------------------
- (void) setChildren:(NSMutableArray*)array
// ----------------------------------------------------------------------------
{
	children = array;
}


// ----------------------------------------------------------------------------
- (BOOL) isPathValid
// ----------------------------------------------------------------------------
{
	return isPathValid;
}

// ----------------------------------------------------------------------------
- (void) setIsPathValid:(BOOL)valid
// ----------------------------------------------------------------------------
{
	isPathValid = valid;
}











// ----------------------------------------------------------------------------
- (NSComparisonResult) compare:(SPSourceListItem *)otherItem;
// ----------------------------------------------------------------------------
{
	return [name.string localizedCaseInsensitiveCompare:[otherItem name].string];
}


// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
+ (NSImage*) playlistIcon
// ----------------------------------------------------------------------------
{
    if (sPlaylistIcon == nil) {
        sPlaylistIcon = [NSImage imageNamed:@"SIDplaylist.music.note.list"];
    }
	return sPlaylistIcon;
}


// ----------------------------------------------------------------------------
+ (NSImage*) smartPlaylistIcon
// ----------------------------------------------------------------------------
{
	if (sSmartPlaylistIcon == nil)
		sSmartPlaylistIcon = [NSImage imageNamed:@"SIDsmart_playlist.gearshape"];

	return sSmartPlaylistIcon;
}


@end
