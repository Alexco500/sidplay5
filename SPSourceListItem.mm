#import "SPSourceListItem.h"
#import "SPPlayerWindow.h"
#import "SPSourceListDataSource.h"
#import "SPSimplePlaylist.h"


@implementation SPSourceListItem

NSString* SPSharedPlaylistIndexDownloaded = @"SPSharedPlaylistIndexDownloaded";

static NSImage* sharedCollectionIcon = nil;
static NSImage* sPlaylistIcon = nil;
static NSImage* sSmartPlaylistIcon = nil;


// ----------------------------------------------------------------------------
- (id) initWithName:(NSAttributedString*)theName forPath:(NSString*)thePath withIcon:(NSImage*)theIcon
// ----------------------------------------------------------------------------
{
    if (self = [super init]) 
	{
		type = SOURCELIST_INVALID;
        name = theName;
		path = thePath;
		icon = theIcon;
		playlist = nil;
		service = nil;
		isPathValid = NO;
		isPlaylistShared = NO;
		children = nil;
		currentRemoveUpdateRevision = -1;
    }
    return self;
}


// ----------------------------------------------------------------------------
- (id) initWithCoder:(NSCoder*)coder
// ----------------------------------------------------------------------------
{
	if (self = [super init])
	{
		[self setType:(SourceListItemType)[coder decodeIntForKey:@"type"]];
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
- (void) finalize
// ----------------------------------------------------------------------------
{
	if (playlistIndexDownloadConnection != nil)
	{
		[playlistIndexDownloadConnection cancel];
		playlistIndexDownloadConnection = nil;
	}

	if (playlistDownloadConnection != nil)
	{
		[playlistDownloadConnection cancel];
		playlistDownloadConnection = nil;
	}
	
	[super finalize];
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
    [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingMiddle];

	NSDictionary* headerAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:11.0f], NSFontAttributeName, 
																			paragraphStyle, NSParagraphStyleAttributeName, nil];
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
- (NSNetService*) service
// ----------------------------------------------------------------------------
{
	return service;
}


// ----------------------------------------------------------------------------
- (void) setService:(NSNetService*)theService
// ----------------------------------------------------------------------------
{
	service = theService;
}


// ----------------------------------------------------------------------------
- (SourceListItemType) type
// ----------------------------------------------------------------------------
{
	return type;
}


// ----------------------------------------------------------------------------
- (void) setType:(SourceListItemType)theType
// ----------------------------------------------------------------------------
{
	type = theType;
	
	if (type == SOURCELIST_SHAREDCOLLECTION)
		[self downloadSharedPlaylists];
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
- (BOOL) isSharedCollectionItem
// ----------------------------------------------------------------------------
{
	return type == SOURCELIST_SHAREDCOLLECTION;
}


// ----------------------------------------------------------------------------
- (BOOL) isSharedPlaylistItem
// ----------------------------------------------------------------------------
{
	return type == SOURCELIST_SHAREDPLAYLIST;
}


// ----------------------------------------------------------------------------
- (BOOL) isSharedSmartPlaylistItem
// ----------------------------------------------------------------------------
{
	return type == SOURCELIST_SHAREDSMARTPLAYLIST;
}


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
	
	if (index < [children count])
		return [children objectAtIndex:index];
	else
		return nil;
}


// ----------------------------------------------------------------------------
- (BOOL) hasChildren
// ----------------------------------------------------------------------------
{
	if (children == nil)
		return NO;

	return ([children count] > 0);
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
- (BOOL) isPlaylistShared
// ----------------------------------------------------------------------------
{
	return isPlaylistShared;
}


// ----------------------------------------------------------------------------
- (void) setIsPlaylistShared:(BOOL)isShared
// ----------------------------------------------------------------------------
{
	isPlaylistShared = isShared;
}


// ----------------------------------------------------------------------------
- (void) checkForRemoteUpdateRevisionChange
// ----------------------------------------------------------------------------
{
	NSString* updateRevisionUrlString = [path stringByAppendingString:@"_UPDATE/"];
	
	NSURL* url = [NSURL URLWithString:updateRevisionUrlString];
	NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
	[request setValue:SPUrlRequestUserAgentString forHTTPHeaderField:@"User-Agent"];
	updateRevisionData = [NSMutableData data];
	updateRevisionConnection = [NSURLConnection connectionWithRequest:request delegate:self];
}


// ----------------------------------------------------------------------------
- (void) downloadSharedPlaylists
// ----------------------------------------------------------------------------
{
	children = [[NSMutableArray alloc] init];
	
	// get playlists from server
	if (path != nil)
	{
		NSString* urlString = path;
		NSString* playlistIndexURLString = [urlString stringByAppendingFormat:@"_PLAYLISTS/"];
		NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:playlistIndexURLString] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
		[request setValue:SPUrlRequestUserAgentString forHTTPHeaderField:@"User-Agent"];
		playlistIndexDownloadData = [NSMutableData data];
		playlistIndexDownloadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
		//NSLog(@"Downloading playlist index: %@\n", playlistIndexURLString);
	}
	
}


// ----------------------------------------------------------------------------
- (void) connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
// ----------------------------------------------------------------------------
{
	if (connection == playlistIndexDownloadConnection)
		[playlistIndexDownloadData setLength:0];
	else if (connection == playlistDownloadConnection)
		[playlistDownloadData setLength:0];
	else if (connection == updateRevisionConnection)
		[updateRevisionData setLength:0];
}


// ----------------------------------------------------------------------------
- (void) connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
// ----------------------------------------------------------------------------
{
	if (connection == playlistIndexDownloadConnection)
		[playlistIndexDownloadData appendData:data];
	else if (connection == playlistDownloadConnection)
		[playlistDownloadData appendData:data];
	else if (connection == updateRevisionConnection)
		[updateRevisionData appendData:data];
}


// ----------------------------------------------------------------------------
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
// ----------------------------------------------------------------------------
{
	if (connection == playlistIndexDownloadConnection)
	{
		NSString* playlistIndexString = [[NSString alloc] initWithData:playlistIndexDownloadData encoding:NSUTF8StringEncoding];
		NSArray* playlistIndexItems = [playlistIndexString componentsSeparatedByString:@"\n"];
		
		for (NSString* playlistIndexItem in playlistIndexItems)
		{
			NSArray* playlistIndexItemComponents = [playlistIndexItem componentsSeparatedByString:@":"];
			if ([playlistIndexItemComponents count] == 3)
			{
				NSString* playlistIndexSpecifier = [playlistIndexItemComponents objectAtIndex:0];
				NSInteger playlistIndex = [playlistIndexSpecifier integerValue];
				
				NSString* playlistTypeSpecifier = [playlistIndexItemComponents objectAtIndex:1];
				if ([playlistTypeSpecifier length] == 1)
				{
					BOOL isSmartPlaylist = [playlistTypeSpecifier isEqualToString:@"S"];
					NSString* playlistName = [playlistIndexItemComponents objectAtIndex:2];

					NSString* urlString = path;
					NSString* playlistURLString = [urlString stringByAppendingFormat:@"_PLAYLISTS/%ld", (long)playlistIndex];
					
					NSImage* sourceListIcon = isSmartPlaylist ? [SPSourceListItem smartPlaylistIcon] : [SPSourceListItem playlistIcon];
					SPSourceListItem* playlistItem = [SPSourceListDataSource addSourceListItemToItem:self atIndex:-1 forPath:playlistURLString withName:playlistName withImage:sourceListIcon];
					[playlistItem setType:(isSmartPlaylist ? SOURCELIST_SHAREDSMARTPLAYLIST : SOURCELIST_SHAREDPLAYLIST)];
					[playlistItem setService:service];
					[playlistItem setPlaylist:nil];
					[playlistItem downloadSharedPlaylistFromUrl:playlistURLString];
				}
			}
		}
		
		[[NSNotificationCenter defaultCenter] postNotificationName:SPSharedPlaylistIndexDownloaded object:self];
		
		playlistIndexDownloadData = nil;
		playlistIndexDownloadConnection = nil;
	}
	else if (connection == playlistDownloadConnection)
	{
		if (type == SOURCELIST_SHAREDSMARTPLAYLIST)
		{
			playlist = [SPSimplePlaylist playlistFromSharedSmartPlaylistData:playlistDownloadData];
			[playlist setName:[name string]];
		}
		else
			playlist = [SPSimplePlaylist playlistFromData:playlistDownloadData];

		playlistDownloadData = nil;
		playlistDownloadConnection = nil;
	}	
	else if (connection == updateRevisionConnection)
	{
		NSString* updateRevisionDataString = [[NSString alloc] initWithData:updateRevisionData encoding:NSUTF8StringEncoding];
		NSInteger remoteUpdateRevision = [updateRevisionDataString integerValue];
		//NSLog(@"update revision of %@: %d\n", [name string], remoteUpdateRevision);
		
		if (currentRemoveUpdateRevision == -1)
			currentRemoveUpdateRevision = remoteUpdateRevision;
		else if (currentRemoveUpdateRevision != remoteUpdateRevision)
		{
			currentRemoveUpdateRevision = remoteUpdateRevision;
			//NSLog(@"update revision of %@: changed, getting new playlists\n", [name string], remoteUpdateRevision);
			[self downloadSharedPlaylists];
		}
			
		updateRevisionData = nil;
		updateRevisionConnection = nil;
	}
}

// ----------------------------------------------------------------------------
- (void) downloadSharedPlaylistFromUrl:(NSString*)urlString
// ----------------------------------------------------------------------------
{
	NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
	[request setValue:SPUrlRequestUserAgentString forHTTPHeaderField:@"User-Agent"];
	playlistDownloadData = [NSMutableData data];
	playlistDownloadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	//NSLog(@"Downloading playlist: %@\n", urlString);
}


// ----------------------------------------------------------------------------
- (NSComparisonResult) compare:(SPSourceListItem *)otherItem;
// ----------------------------------------------------------------------------
{
	return [[name string] localizedCaseInsensitiveCompare:[[otherItem name] string]];
}


// ----------------------------------------------------------------------------
+ (NSImage*) sharedCollectionIcon
// ----------------------------------------------------------------------------
{
	if (sharedCollectionIcon == nil)
		sharedCollectionIcon = [NSImage imageNamed:@"shared_collection"];
	
	return sharedCollectionIcon;
}


// ----------------------------------------------------------------------------
+ (NSImage*) playlistIcon
// ----------------------------------------------------------------------------
{
	if (sPlaylistIcon == nil)
		sPlaylistIcon = [NSImage imageNamed:@"playlist"];

	return sPlaylistIcon;
}


// ----------------------------------------------------------------------------
+ (NSImage*) smartPlaylistIcon
// ----------------------------------------------------------------------------
{
	if (sSmartPlaylistIcon == nil)
		sSmartPlaylistIcon = [NSImage imageNamed:@"smart_playlist"];

	return sSmartPlaylistIcon;
}


@end
