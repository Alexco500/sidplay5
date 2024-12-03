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
		service = nil;
		isPathValid = NO;
		isPlaylistShared = NO;
		children = nil;
		currentRemoveUpdateRevision = -1;
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
- (void) dealloc
// ----------------------------------------------------------------------------
{
    // changed finalize back to dealloc
	if (playlistIndexDownloadConnection != nil)
	{
        [playlistIndexDownloadConnection invalidateAndCancel];
		playlistIndexDownloadConnection = nil;
	}

	if (playlistDownloadConnection != nil)
	{
        [playlistDownloadConnection invalidateAndCancel];
		playlistDownloadConnection = nil;
	}
	
	//[super finalize];
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

    /*
    // moved from NSURLConnection to NSURLSession, according to
    // https://www.objc.io/issues/5-ios7/from-nsurlconnection-to-nsurlsession/
     */
    updateRevisionConnection = [NSURLSession sharedSession];
    NSURLSessionDataTask *dwnTask = [updateRevisionConnection dataTaskWithRequest:request
                                                               completionHandler:
                                     ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
        } else {
            [self->updateRevisionData appendData:data];
            [self connectionDidFinishLoading:self->updateRevisionConnection];
        }
    }];
    
    [dwnTask resume];
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

		//NSLog(@"Downloading playlist index: %@\n", playlistIndexURLString);
        
        /*
        // moved from NSURLConnection to NSURLSession, according to
        // https://www.objc.io/issues/5-ios7/from-nsurlconnection-to-nsurlsession/
         */
        playlistIndexDownloadConnection = [NSURLSession sharedSession];
        NSURLSessionDataTask *dwnTask = [playlistIndexDownloadConnection dataTaskWithRequest:request
                                                                   completionHandler:
                                         ^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"Error: %@", error.localizedDescription);
            } else {
                [self->updateRevisionData appendData:data];
                [self connectionDidFinishLoading:self->playlistIndexDownloadConnection];
            }
        }];
        
        [dwnTask resume];
	}
	
}
// ----------------------------------------------------------------------------
- (void)connectionDidFinishLoading:(NSURLSession *)connection
// ----------------------------------------------------------------------------
{
	if (connection == playlistIndexDownloadConnection)
	{
		NSString* playlistIndexString = [[NSString alloc] initWithData:playlistIndexDownloadData encoding:NSUTF8StringEncoding];
		NSArray* playlistIndexItems = [playlistIndexString componentsSeparatedByString:@"\n"];
		
		for (NSString* playlistIndexItem in playlistIndexItems)
		{
			NSArray* playlistIndexItemComponents = [playlistIndexItem componentsSeparatedByString:@":"];
			if (playlistIndexItemComponents.count == 3)
			{
				NSString* playlistIndexSpecifier = playlistIndexItemComponents[0];
				NSInteger playlistIndex = playlistIndexSpecifier.integerValue;
				
				NSString* playlistTypeSpecifier = playlistIndexItemComponents[1];
				if (playlistTypeSpecifier.length == 1)
				{
					BOOL isSmartPlaylist = [playlistTypeSpecifier isEqualToString:@"S"];
					NSString* playlistName = playlistIndexItemComponents[2];

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
			[playlist setName:name.string];
		}
		else
			playlist = [SPSimplePlaylist playlistFromData:playlistDownloadData];

		playlistDownloadData = nil;
		playlistDownloadConnection = nil;
	}	
	else if (connection == updateRevisionConnection)
	{
		NSString* updateRevisionDataString = [[NSString alloc] initWithData:updateRevisionData encoding:NSUTF8StringEncoding];
		NSInteger remoteUpdateRevision = updateRevisionDataString.integerValue;
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

	//NSLog(@"Downloading playlist: %@\n", urlString);
    /*
    // moved from NSURLConnection to NSURLSession, according to
    // https://www.objc.io/issues/5-ios7/from-nsurlconnection-to-nsurlsession/
     */
    playlistDownloadConnection = [NSURLSession sharedSession];
    NSURLSessionDataTask *dwnTask = [playlistDownloadConnection dataTaskWithRequest:request
                                                               completionHandler:
                                     ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
        } else {
            [self->updateRevisionData appendData:data];
            [self connectionDidFinishLoading:self->playlistDownloadConnection];
        }
    }];
    
    [dwnTask resume];
}


// ----------------------------------------------------------------------------
- (NSComparisonResult) compare:(SPSourceListItem *)otherItem;
// ----------------------------------------------------------------------------
{
	return [name.string localizedCaseInsensitiveCompare:[otherItem name].string];
}


// ----------------------------------------------------------------------------
+ (NSImage*) sharedCollectionIcon
// ----------------------------------------------------------------------------
{
	if (sharedCollectionIcon == nil)
		sharedCollectionIcon = [NSImage imageNamed:@"SIDshared_collection.rectangle.stack.badge.person.crop"];
	
	return sharedCollectionIcon;
}


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
