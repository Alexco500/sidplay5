#import "SPSourceListDataSource.h"
#import "SPSourceListItem.h"
#import "SPSourceListCell.h"
#import "SPBrowserDataSource.h"
#import "SPPreferencesController.h"
#import "SPCollectionUtilities.h"
#import "SPApplicationStorageController.h"
#import "SPPlaylist.h"
#import "SPPlaylistItem.h"
#import "SPSimplePlaylist.h"
#import "SPSmartPlaylist.h"
#import "SPPlayerWindow.h"
#import "SPBrowserItem.h"


@implementation SPSourceListDataSource

NSString* SPSourceListCollectionItemPBoardType = @"SPSourceListCollectionItemPBoardType";

static NSString* SPDefaultKeyDontShowDeletePlaylistAlert = @"SPDefaultKeyDontShowDeletePlaylistAlert";

static NSString* SPSharedCollectionServiceType = @"_sidmusic._tcp";


// ----------------------------------------------------------------------------
- (instancetype) init
// ----------------------------------------------------------------------------
{
	if (self = [super init])
	{
		rootItems = [[NSMutableArray alloc] init];
		collectionsContainerItem = nil;
		playlistsContainerItem = nil;
		currentCollection = nil;
		draggedItems = nil;
		rsyncTask = nil;
		rsyncMirrorsListDownloaded = NO;
		
		httpServer = nil;
		serviceBrowser = [[NSNetServiceBrowser alloc] init];
        serviceBrowser.delegate = self;
		currentSharedCollectionService = nil;
		serviceBeingResolved = nil;
	}
	
	return self;
}


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[[SPPreferencesController sharedInstance] load];
	
	[sourceListView registerForDraggedTypes:@[NSFilenamesPboardType, NSStringPboardType, SPSourceListCollectionItemPBoardType, SPBrowserItemPBoardType]];
	[sourceListView setVerticalMotionCanBeginDrag:YES];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sharedPlaylistsIndexDownloaded:) name:SPSharedPlaylistIndexDownloaded object:nil];	
	
	NSRect frame = syncProgressDialog.frame;
	frame.size.height = syncProgressDialog.minSize.height;
	[syncProgressDialog setFrame:frame display:YES];
	
	[rootItems removeAllObjects];
	
	// Add the container headers
	collectionsContainerItem = [self addHeaderItemWithName:@"COLLECTIONS" atIndex:0];
	playlistsContainerItem = [self addHeaderItemWithName:@"PLAYLISTS" atIndex:1];
	sharedCollectionsContainerItem = nil;

	// download mirror list to get up-to-date default mirror
	rsyncMirrorsListDownloaded = NO;
	SPCollectionUtilities* collectionUtilities = [SPCollectionUtilities sharedInstance];
	[collectionUtilities downloadRsyncMirrorsListAndNotify:@selector(setupDefaultRsyncMirror) ofTarget:self];

	[setupCollectionWindow setExcludedFromWindowsMenu:YES];
	
	if (gPreferences.mCollections.count == 0)
	{
		[self setupInitialCollection];
	}
	else
		setupCollectionWindow = nil;

	if (gPreferences.mCollections.count > 0)
	{
		NSString* firstCollectionPath = (NSString*) gPreferences.mCollections[0];
		[browserDataSource setRootPath:firstCollectionPath];
	}


	[self initSourceListItems];
	[sourceListView reloadData];
	
	[self checkForAutoSync];
	
	/*
	if (gPreferences.mPublishSharedCollection)
		[self publishSharedCollectionWithPath:gPreferences.mSharedCollectionPath];
	
	[self searchForSharedCollections:gPreferences.mSearchForSharedCollections];
	*/
}


// ----------------------------------------------------------------------------
- (void) setupDefaultRsyncMirror
// ----------------------------------------------------------------------------
{
	SPCollectionUtilities* collectionUtilities = [SPCollectionUtilities sharedInstance];
	
	BOOL selectedRsyncMirrorExists = NO;
	for (NSString* rsyncMirror in [collectionUtilities rsyncMirrorList])
	{
		if ([rsyncMirror caseInsensitiveCompare:gPreferences.mSyncUrl] == NSOrderedSame)
		{
			selectedRsyncMirrorExists = YES;
			break;
		}
	}
	
	if (!selectedRsyncMirrorExists && [collectionUtilities rsyncMirrorList].count > 0)
		gPreferences.mSyncUrl = [[collectionUtilities rsyncMirrorList][0] mutableCopy];
		
	rsyncMirrorsListDownloaded = YES;	
}


// ----------------------------------------------------------------------------
- (void) setupInitialCollection
// ----------------------------------------------------------------------------
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults addSuiteNamed:@"com.mrsid.sidplay"];
	NSString* oldSidplayHvscPath = [defaults stringForKey:@"HVSC Basepath"];
	[defaults removeSuiteNamed:@"com.mrsid.sidplay"];

	if (oldSidplayHvscPath != nil)
	{
		// Old SIDPLAY 3.x preferences found, check if HVSC folder exists and use it
		BOOL folder = NO;
		BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:oldSidplayHvscPath isDirectory:&folder];
		
		if (exists && folder)
			[gPreferences.mCollections addObject:oldSidplayHvscPath];
	}
	else
	{
		NSInteger result = [NSApp runModalForWindow:setupCollectionWindow];
		
		[setupCollectionWindow close];
		setupCollectionWindow = nil;
		
		if (result == 1)
		{
			NSOpenPanel* openPanel = [NSOpenPanel openPanel];
			//NSArray* fileTypes = @[@""];
			[openPanel setCanChooseDirectories:YES];
			[openPanel setCanChooseFiles:NO];
			[openPanel setAllowsMultipleSelection:NO];
			openPanel.title = @"Select HVSC collection folder (usually called C64Music) or other folder containing .sid music files";
			openPanel.prompt = @"Choose";
			
			//long result2 = [openPanel runModalForDirectory:nil file:nil types:fileTypes];
            long result2 = [openPanel runModal];

			if (result2 == NSModalResponseOK)
			{
                NSArray* filesToOpen = [openPanel URLs];
				NSString* path = [filesToOpen[0] path];
				[gPreferences.mCollections addObject:path];
			}
		}
		else if (result == 2)
		{
			// sync with collection
			
			// wait for rsync mirror list download to finish
			while (!rsyncMirrorsListDownloaded)
				[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];
			
			// create folder to hold collection
			NSString* musicPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Music"];
			NSString* collectionPath = [musicPath stringByAppendingPathComponent:@"C64music"];
			
			BOOL createSucceeded = NO;
			BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:collectionPath isDirectory:NULL];
			if (!exists)
                createSucceeded = [[NSFileManager defaultManager] createDirectoryAtPath:collectionPath withIntermediateDirectories:YES attributes:nil error:NULL];
				
			if (exists || createSucceeded)
			{
				[gPreferences.mCollections addObject:collectionPath];
				[self addCollectionItemForPath:collectionPath atIndex:-1 withImage:nil];
				
				[self performSyncOperationAutomatically:YES showWarningDialog:NO];

				[[collectionsContainerItem children] removeObject:currentCollection];
			}
		}
	}
}


// ----------------------------------------------------------------------------
- (IBAction) clickInitialCollectionChoiceButton:(id)sender
// ----------------------------------------------------------------------------
{
	[NSApp stopModalWithCode:[sender tag]];
}


// ----------------------------------------------------------------------------
- (void) initSourceListItems
// ----------------------------------------------------------------------------
{
	for (NSString* path in gPreferences.mCollections)
		[self addCollectionItemForPath:path atIndex:-1 withImage:nil];

	NSMutableArray* playlistsToMigrate = [[NSMutableArray alloc] init];
	
	// Iterate files in ~/Application Support/SIDPLAY/Playlists/
	NSArray* playlistFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[SPApplicationStorageController playlistPath] error:nil];
	for (NSString* playlistFile in playlistFiles)
	{
		if ([playlistFile characterAtIndex:0] == '.')
			continue;

		if ([playlistFile caseInsensitiveCompare:@"Best of VARIOUS"] == NSOrderedSame)
			continue;

		if ([playlistFile caseInsensitiveCompare:@"HVSC Top100"] == NSOrderedSame)
			continue;
	
		NSString* playlistPath = [[SPApplicationStorageController playlistPath] stringByAppendingPathComponent:playlistFile];

		SPPlaylist* playlist = nil;
		BOOL isSmartPlaylist = NO;
		
		if ([playlistPath.pathExtension isEqualToString:@""] && !gPreferences.mLegacyPlaylistsMigrated)
		{
			// Migrate the existing old playlist file from SIDPLAY 3.x
			[playlistsToMigrate addObject:playlistPath];
		}
		else if ([playlistPath.pathExtension caseInsensitiveCompare:[SPSimplePlaylist fileExtension]] == NSOrderedSame)
		{
			playlist = [SPSimplePlaylist playlistFromFile:playlistPath];
			isSmartPlaylist = NO;
		}
		else if ([playlistPath.pathExtension caseInsensitiveCompare:[SPSmartPlaylist fileExtension]] == NSOrderedSame)
		{
			playlist = [SPSmartPlaylist playlistFromFile:playlistPath];
			isSmartPlaylist = YES;
		}
		
		[self addPlaylistItemForPath:playlistPath toContainerItem:playlistsContainerItem atIndex:-1 withPlaylist:playlist isSmart:isSmartPlaylist];
	}
	
	// Migrate old SIDPLAY 3.x playlists
	for (NSString* playlistPath in playlistsToMigrate)
	{
		SPPlaylist* playlist = [SPSimplePlaylist playlistFromSidplay3File:playlistPath];

		// Check if we already have a playlist of this name, don't migrate in this case
		BOOL found = NO;
		NSMutableArray* playlistItems = [playlistsContainerItem children];
		for (SPSourceListItem* item in playlistItems)
		{
			if ([[item name].string isEqualToString:[playlist name]])
			{
				found = YES;
				break;
			}
		}
		
		if (!found)
		{
			[playlist saveToFile];
			[self addPlaylistItemForPath:playlistPath toContainerItem:playlistsContainerItem atIndex:-1 withPlaylist:playlist isSmart:NO];
		}
	}
	
	// check for Favorites playlist and create if not found
	NSString* favoritesPlaylistName = @"Favorites";
	BOOL foundFavorites = NO;
	NSMutableArray* playlistItems = [playlistsContainerItem children];
	for (SPSourceListItem* item in playlistItems)
	{
		if ([[item name].string caseInsensitiveCompare:favoritesPlaylistName] == NSOrderedSame)
		{
			foundFavorites = YES;
			break;
		}
	}
	
	if (!foundFavorites)
		[self createNewPlaylistWithName:favoritesPlaylistName andSelectInSourceList:NO];
	else
		[self sortPlaylists];
	
	gPreferences.mLegacyPlaylistsMigrated = YES;
}


// ----------------------------------------------------------------------------
+ (SPSourceListItem*) addSourceListItemToItem:(SPSourceListItem*)containerItem atIndex:(NSInteger)index forPath:(NSString*)path withName:(NSString*)name withImage:(NSImage*)image
// ----------------------------------------------------------------------------
{
	BOOL exists = YES;
	
	// If no image is passed, find the icon of the path
	if (image == nil)
	{
		exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL];
		if (exists)
			image = [[NSWorkspace sharedWorkspace] iconForFile:path];
		else
			image = [NSImage imageNamed:@"notfound"];
	}

	NSMutableParagraphStyle* paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;

	NSDictionary* headerAttrs = @{NSFontAttributeName: [NSFont systemFontOfSize:12.0f],
																			NSParagraphStyleAttributeName: paragraphStyle};
	NSAttributedString* listItemName = [[NSAttributedString alloc] initWithString:name attributes:headerAttrs];

	SPSourceListItem* item = [[SPSourceListItem alloc] initWithName:listItemName forPath:path withIcon:image];
	[item setIsPathValid:exists];
	
	if (index == -1)
		[containerItem addChild:item];
	else
		[containerItem insertChild:item atIndex:index];
	
	return item;
}


// ----------------------------------------------------------------------------
+ (SPSourceListItem*) addSourceListItemToItem:(SPSourceListItem*)containerItem atIndex:(NSInteger)index forPath:(NSString*)path withName:(NSString*)name
// ----------------------------------------------------------------------------
{
	return [SPSourceListDataSource addSourceListItemToItem:containerItem atIndex:index forPath:path withName:name withImage:nil];
}


// ----------------------------------------------------------------------------
- (SPSourceListItem*) addHeaderItemWithName:(NSString*)name atIndex:(NSInteger)index
// ----------------------------------------------------------------------------
{
	NSMutableParagraphStyle* paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;

	NSDictionary* headerAttrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:12.0f],
																			NSParagraphStyleAttributeName: paragraphStyle};
	NSAttributedString* headerName = [[NSAttributedString alloc] initWithString:name attributes:headerAttrs];
	
	SPSourceListItem* headerItem = [[SPSourceListItem alloc] initWithName:headerName forPath:@"" withIcon:nil];
	[headerItem setType:SOURCELIST_HEADER];

	[rootItems insertObject:headerItem atIndex:index];
	
	return headerItem;
}


// ----------------------------------------------------------------------------
- (SPSourceListItem*) addCollectionItemForPath:(NSString*)path atIndex:(NSInteger)index withImage:(NSImage*)image
// ----------------------------------------------------------------------------
{
	NSString* name = [[SPCollectionUtilities sharedInstance] collectionNameOfPath:path];
	SPSourceListItem* item = [SPSourceListDataSource addSourceListItemToItem:collectionsContainerItem atIndex:index forPath:path withName:name withImage:image];
	[item setType:SOURCELIST_COLLECTION];
	if ([collectionsContainerItem children].count == 1)
		currentCollection = item;
	
	return item;	
}


// ----------------------------------------------------------------------------
- (SPSourceListItem*) addSharedCollectionItemForService:(NSNetService*)service atIndex:(NSInteger)index
// ----------------------------------------------------------------------------
{
	if (service == nil)
		return nil;
	
	if (sharedCollectionsContainerItem == nil)
	{
		sharedCollectionsContainerItem = [self addHeaderItemWithName:@"SHARED" atIndex:1];
		//NSLog(@"Added sharedCollectionsContainerItem: %@\n", sharedCollectionsContainerItem);
	}
	
	NSString* host = service.hostName;
	NSInteger port = service.port;
	NSString* urlString = nil;
	if (port != -1)
		urlString = [NSString stringWithFormat:@"http://%@:%d/", host, (int)port];
		
	SPSourceListItem* item = [SPSourceListDataSource addSourceListItemToItem:sharedCollectionsContainerItem atIndex:index forPath:urlString withName:service.name withImage:[SPSourceListItem sharedCollectionIcon]];
	[item setType:SOURCELIST_SHAREDCOLLECTION];
	[item setService:service];

	//NSLog(@"Added item: %@\n", item);

	return item;
}


// ----------------------------------------------------------------------------
- (SPSourceListItem*) addPlaylistItemForPath:(NSString*)path toContainerItem:(SPSourceListItem*)containerItem atIndex:(NSInteger)index withPlaylist:(SPPlaylist*)playlist isSmart:(BOOL)isSmartPlaylist
// ----------------------------------------------------------------------------
{
	if (playlist == nil)
		return nil;

	NSImage* icon = isSmartPlaylist ? [SPSourceListItem smartPlaylistIcon] : [SPSourceListItem playlistIcon];
	SPSourceListItem* item = [SPSourceListDataSource addSourceListItemToItem:containerItem atIndex:index forPath:path withName:[playlist name] withImage:icon];
	[item setType:(isSmartPlaylist ? SOURCELIST_SMARTPLAYLIST : SOURCELIST_PLAYLIST)];
	[item setPlaylist:playlist];
	
	return item;
}


// ----------------------------------------------------------------------------
- (SPSourceListItem*) findItemWithPath:(NSString*)path
// ----------------------------------------------------------------------------
{
	return [self findItemWithPath:path inParentItem:nil];
}


// ----------------------------------------------------------------------------
- (SPSourceListItem*) findItemWithPath:(NSString*)path inParentItem:(SPSourceListItem*)parentItem
// ----------------------------------------------------------------------------
{
	NSArray* items = nil;

	if (parentItem == nil)
		items = rootItems;
	else
		items = [parentItem children];

	for (SPSourceListItem* item in items)
	{
		if ([[item path] caseInsensitiveCompare:path] == NSOrderedSame)
			return item;

		SPSourceListItem* result = [self findItemWithPath:path inParentItem:item];
		if (result != nil)
			return result;
	}
	
	return nil;
}


// ----------------------------------------------------------------------------
- (BOOL) removeSourceListItem:(SPSourceListItem*)item
// ----------------------------------------------------------------------------
{
	if (item == nil)
		return NO;
	
	BOOL itemWasRemoved = NO;
	
	SPSourceListItem* container = nil;
	if ([item isCollectionItem])
	{
		container = collectionsContainerItem;
		[[container children] removeObject:item];
		
		[gPreferences.mCollections removeAllObjects];
		for (SPSourceListItem* collectionItem in [collectionsContainerItem children])
			[gPreferences.mCollections addObject:[collectionItem path]];
		
		itemWasRemoved = YES;
	}
	else if ([item isSharedCollectionItem])
	{
		container = sharedCollectionsContainerItem;
		if (container != nil)
		{
			[[container children] removeObject:item];
			
			if ([container children].count < 1)
			{
				[rootItems removeObject:container];
				sharedCollectionsContainerItem = nil;
			}
		}
		
		itemWasRemoved = YES;
	}
	else if ([item isPlaylistItem] || [item isSmartPlaylistItem])
	{
		BOOL suppressAlert = [[NSUserDefaults standardUserDefaults] boolForKey:SPDefaultKeyDontShowDeletePlaylistAlert];
		BOOL deletePlaylist = YES;
		
		if ([[item playlist] count] == 0)
			suppressAlert = YES;
		
		if (!suppressAlert)
		{
			deletePlaylist = NO;
			
			NSString* alertText = [NSString stringWithFormat:@"Are you sure you want to delete the playlist \"%@\"", [[item playlist] name]];
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:alertText];
			[alert setInformativeText:@"If you delete the playlist, it will not be possible to undo the operation!"];
			[alert setAlertStyle:NSAlertStyleInformational]; // or NSAlertStyleWarning, or NSAlertStyleCritical
			[alert addButtonWithTitle:@"Cancel"];
			[alert addButtonWithTitle:@"Delete"];
			
			[alert setShowsSuppressionButton:YES];
			
			if ([alert runModal] == NSAlertSecondButtonReturn)
			{
				if (alert.suppressionButton.state == NSOnState)
					[[NSUserDefaults standardUserDefaults] setBool:YES forKey:SPDefaultKeyDontShowDeletePlaylistAlert];
				
				deletePlaylist = YES;
			}
		}
		
		if (deletePlaylist)
		{
			//[[NSFileManager defaultManager] removeFileAtPath:[item path] handler:nil];
			
            [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:[item path]] error:nil];
			container = playlistsContainerItem;
			[[container children] removeObject:item];
			itemWasRemoved = YES;
			
			[self bumpUpdateRevision];
			//[self publishSharedCollectionWithPath:gPreferences.mSharedCollectionPath];
		}
	}

	return itemWasRemoved;
}


// ----------------------------------------------------------------------------
- (SPBrowserDataSource*) browserDataSource
// ----------------------------------------------------------------------------
{
	return browserDataSource;
}


// ----------------------------------------------------------------------------
- (SPSourceListView*) sourceListView
// ----------------------------------------------------------------------------
{
	return sourceListView;
}


// ----------------------------------------------------------------------------
- (NSArray*) draggedItems
// ----------------------------------------------------------------------------
{
	return draggedItems;
}


// ----------------------------------------------------------------------------
- (SPSourceListItem*) currentCollection
// ----------------------------------------------------------------------------
{
	return currentCollection;
}


// ----------------------------------------------------------------------------
- (void) setCurrentCollection:(SPSourceListItem*)collectionItem
// ----------------------------------------------------------------------------
{
	currentCollection = collectionItem;
}


// ----------------------------------------------------------------------------
- (SPSourceListItem*) collectionsContainerItem
// ----------------------------------------------------------------------------
{
	return collectionsContainerItem;
}


// ----------------------------------------------------------------------------
- (SPSourceListItem*) playlistsContainerItem
// ----------------------------------------------------------------------------
{
	return playlistsContainerItem;
}


// ----------------------------------------------------------------------------
- (void) sortPlaylists
// ----------------------------------------------------------------------------
{
	NSMutableArray* playlistItems = [playlistsContainerItem children];
	
	NSMutableArray* simplePlaylistItems = [[NSMutableArray alloc] init];
	NSMutableArray* smartPlaylistItems = [[NSMutableArray alloc] init];
	
	for (SPSourceListItem* playlistItem in playlistItems)
	{
		if ([playlistItem isSmartPlaylistItem])
			[smartPlaylistItems addObject:playlistItem];
		else
			[simplePlaylistItems addObject:playlistItem];
	}
	
	[simplePlaylistItems sortUsingSelector:@selector(compare:)];
	[smartPlaylistItems sortUsingSelector:@selector(compare:)];
	[playlistItems removeAllObjects];
	[playlistItems addObjectsFromArray:smartPlaylistItems];
	[playlistItems addObjectsFromArray:simplePlaylistItems];
}


// ----------------------------------------------------------------------------
- (void) recacheSmartPlaylists
// ----------------------------------------------------------------------------
{
	for (SPSourceListItem* item in [playlistsContainerItem children])
	{
		if ([item isSmartPlaylistItem])
			[(SPSmartPlaylist*)[item playlist] startSpotlightQuery:[[SPCollectionUtilities sharedInstance] rootPath]];	
	}
}


// ----------------------------------------------------------------------------
- (void) createNewPlaylistWithName:(NSString*)name andSelectInSourceList:(BOOL)select
// ----------------------------------------------------------------------------
{
	SPSimplePlaylist* playlist = [[SPSimplePlaylist alloc] init];
	[playlist setName:name];
	[playlist saveToFile];
	SPSourceListItem* item = [SPSourceListDataSource addSourceListItemToItem:playlistsContainerItem atIndex:-1 forPath:[playlist path] withName:[playlist name] withImage:[SPSourceListItem playlistIcon]];
	[item setType:SOURCELIST_PLAYLIST];
	[item setPlaylist:playlist];
	[self sortPlaylists];
	[sourceListView reloadData];
    
	if (select)
	{
		NSInteger newRow = [sourceListView rowForItem:item];
		if (newRow >= 0)
		{
			[sourceListView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
			[sourceListView editColumn:0 row:newRow withEvent:nil select:YES];
		}
	}
}
// ----------------------------------------------------------------------------
- (void) addSongToPlaylist:(NSString *)song withSubtune:(int) subtune
// ----------------------------------------------------------------------------
{
    SPSimplePlaylist *currentPlaylist = (SPSimplePlaylist*) [browserDataSource playlist];
    NSString* relativePath = [[SPCollectionUtilities sharedInstance] makePathRelativeToCollectionRoot:song];
    SPPlaylistItem* playlistItem = [[SPPlaylistItem alloc] initWithPath:relativePath andSubtuneIndex:0 andLoopCount:1];
    [playlistItem setSubtune:subtune];
    [currentPlaylist addItem:playlistItem];
    [currentPlaylist saveToFile];
    [self bumpUpdateRevision];
    [sourceListView reloadData];
    [browserDataSource switchToPlaylist:currentPlaylist];
}

#pragma mark -
#pragma mark collection sharing methods

#if 0
// ----------------------------------------------------------------------------
- (void) publishSharedCollectionWithPath:(NSString*)collectionPath
// ----------------------------------------------------------------------------
{
	if (collectionPath == nil)
	{
		[self publishSharedCollection:nil];
		return;
	}
	
	SPSourceListItem* sharedCollectionItem = [self findItemWithPath:collectionPath inParentItem:collectionsContainerItem];
	if (sharedCollectionItem != nil)
		[self publishSharedCollection:sharedCollectionItem];
}


// ----------------------------------------------------------------------------
- (void) publishSharedCollection:(SPSourceListItem*)collectionItem
// ----------------------------------------------------------------------------
{
	if (collectionItem == nil)
	{
		if (httpServer != nil)
		{
			[httpServer stop];
			httpServer = nil;
		}
		return;
	}
	
	if (httpServer == nil)
		httpServer = [[HTTPServer alloc] init];
	else
	{
		[httpServer stop];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0f]];
	}

	if (![collectionItem isPathValid])
		return;
	
	[httpServer setType:SPSharedCollectionServiceType];
	[httpServer setPort:6581];
	[httpServer setName:[NSString stringWithFormat:@"%@ on %@", [[collectionItem name] string], (__bridge NSString*) CSCopyMachineName()]];
	[httpServer setDocumentRoot:[NSURL fileURLWithPath:[collectionItem path]]];
	[httpServer setSourceListDataSource:self];
	
	NSError* error;
	/*BOOL success =*/ [httpServer start:&error];
	
	//if(!success)
		//NSLog(@"Error starting HTTP Server: %@", error);
}
#endif

// ----------------------------------------------------------------------------
- (void) searchForSharedCollections:(BOOL)enableSearching
// ----------------------------------------------------------------------------
{
    if (serviceBrowser == nil)
        return;
	
	[serviceBrowser stop];
	if (enableSearching)
		[serviceBrowser searchForServicesOfType:SPSharedCollectionServiceType inDomain:@"local"];
	else
	{
		NSMutableArray* sharedCollectionItems = [sharedCollectionsContainerItem children];
		long count = sharedCollectionItems.count;
		int index = 0;
		for (SPSourceListItem* sharedCollectionItem in sharedCollectionItems)
		{
			[self netServiceBrowser:serviceBrowser didRemoveService:[sharedCollectionItem service] moreComing:(index != (count - 1))];
			index++;
		}
	}
}


// ----------------------------------------------------------------------------
- (NSNetService*) currentSharedCollectionService
// ----------------------------------------------------------------------------
{
	return currentSharedCollectionService;
}


// ----------------------------------------------------------------------------
- (void) setCurrentSharedCollectionService:(NSNetService*)service
// ----------------------------------------------------------------------------
{
	currentSharedCollectionService = service;
}


// ----------------------------------------------------------------------------
- (void) sharedPlaylistsIndexDownloaded:(NSNotification *)notification
// ----------------------------------------------------------------------------
{
	[sourceListView reloadData];
	
	NSInteger selectedRow = sourceListView.selectedRow;
	if (selectedRow != -1)
	{
		SPSourceListItem* firstCollectionItem = [collectionsContainerItem childAtIndex:0];
		NSInteger row = [sourceListView rowForItem:firstCollectionItem];
		if (row != -1)
			[sourceListView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	}
}


// ----------------------------------------------------------------------------
- (NSInteger) updateRevision
// ----------------------------------------------------------------------------
{
	return gPreferences.mUpdateRevision;
}


// ----------------------------------------------------------------------------
- (void) bumpUpdateRevision
// ----------------------------------------------------------------------------
{
	gPreferences.mUpdateRevision++;
}


// ----------------------------------------------------------------------------
- (void) checkForRemoteUpdateRevisionChange
// ----------------------------------------------------------------------------
{
	if (sharedCollectionsContainerItem == nil || ![sharedCollectionsContainerItem hasChildren])
		return;
	
	NSMutableArray* sharedCollectionItems = [sharedCollectionsContainerItem children];
	for (SPSourceListItem* sharedCollectionItem in sharedCollectionItems)
		[sharedCollectionItem checkForRemoteUpdateRevisionChange];
}


#pragma mark -
#pragma mark UI actions

// ----------------------------------------------------------------------------
- (IBAction) removeSelectedSourceListItem:(id)sender
// ----------------------------------------------------------------------------
{
	NSInteger row = sourceListView.selectedRow;
    if (row != -1)
	{
        SPSourceListItem* item = [sourceListView itemAtRow:row];
		BOOL itemWasRemoved = [self removeSourceListItem:item];

		if (itemWasRemoved)
		{
			[sourceListView deselectRow:row];
			long newRow = row - 1;
			SPSourceListItem* newItem = [sourceListView itemAtRow:newRow];
			if (newItem != nil && ![newItem isHeader])
				[sourceListView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
			else if (newItem != nil && [newItem isHeader] && [newItem children].count > 0)
				[sourceListView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow+1] byExtendingSelection:NO];

			
			[sourceListView reloadData];
		}
	}
}


// ----------------------------------------------------------------------------
- (IBAction) addNewPlaylist:(id)sender
// ----------------------------------------------------------------------------
{
	if (!sourceListView.window.visible)
		return;
		
	BOOL isOptionPressed = NSApp.currentEvent.modifierFlags & NSEventModifierFlagOption ? YES : NO;
	if (isOptionPressed)
	{
		[self addNewSmartPlaylist:sender];
		return;
	}
	
	[self createNewPlaylistWithName:@"untitled playlist" andSelectInSourceList:YES];

	[self bumpUpdateRevision];
	//[self publishSharedCollectionWithPath:gPreferences.mSharedCollectionPath];
}


// ----------------------------------------------------------------------------
- (IBAction) addNewSmartPlaylist:(id)sender
// ----------------------------------------------------------------------------
{
	if (!sourceListView.window.visible)
		return;

	SPSmartPlaylist* playlist = [[SPSmartPlaylist alloc] init];
	[playlist setName:@"untitled smart playlist"];
	SPSourceListItem* item = [SPSourceListDataSource addSourceListItemToItem:playlistsContainerItem atIndex:-1 forPath:nil withName:[playlist name] withImage:[SPSourceListItem smartPlaylistIcon]];
	[item setType:SOURCELIST_SMARTPLAYLIST];
	[item setPlaylist:playlist];
	[self sortPlaylists];
	[sourceListView reloadData];
    
    NSInteger newRow = [sourceListView rowForItem:item];
	if (newRow >= 0)
	{
		[sourceListView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[sourceListView editColumn:0 row:newRow withEvent:nil select:YES];
		[browserDataSource enableSmartPlaylistEditor:YES];
	}
	
	[self bumpUpdateRevision];
	//[self publishSharedCollectionWithPath:gPreferences.mSharedCollectionPath];
}


// ----------------------------------------------------------------------------
- (IBAction) editSmartPlaylist:(id)sender
// ----------------------------------------------------------------------------
{
	NSInteger row = sourceListView.selectedRow;
    if (row != -1)
	{
        SPSourceListItem* item = [sourceListView itemAtRow:row];
		if (![item isSmartPlaylistItem])
			return;
		
		SPPlaylist* playlist = [item playlist];
		[browserDataSource switchToPlaylist:playlist];
		[browserDataSource enableSmartPlaylistEditor:YES];
	}
}


// ----------------------------------------------------------------------------
- (void) addSavedSearchSmartPlaylist:(SPSmartPlaylist*)smartPlaylist
// ----------------------------------------------------------------------------
{
	SPSourceListItem* item = [SPSourceListDataSource addSourceListItemToItem:playlistsContainerItem atIndex:-1 forPath:nil withName:[smartPlaylist name] withImage:[SPSourceListItem smartPlaylistIcon]];
	[item setType:SOURCELIST_SMARTPLAYLIST];
	[item setPlaylist:smartPlaylist];
	[self sortPlaylists];
	[sourceListView reloadData];
    
    NSInteger newRow = [sourceListView rowForItem:item];
	if (newRow >= 0)
	{
		[sourceListView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[browserDataSource enableSmartPlaylistEditor:YES];
	}
	
	[self bumpUpdateRevision];
	//[self publishSharedCollectionWithPath:gPreferences.mSharedCollectionPath];
}


// ----------------------------------------------------------------------------
- (IBAction) savePlaylistToM3U:(id)sender
// ----------------------------------------------------------------------------
{
	NSInteger row = sourceListView.selectedRow;
    if (row != -1)
	{
        SPSourceListItem* item = [sourceListView itemAtRow:row];
		if (![item isPlaylistItem] && ![item isSmartPlaylistItem])
			return;
        //__block NSInteger result;
		//[NSApp beginSheet:m3uExportOptionsPanel modalForWindow:sourceListView.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
        [sourceListView.window beginSheet:m3uExportOptionsPanel completionHandler:nil];
        
		NSInteger result = [NSApp runModalForWindow:sourceListView.window];
		[NSApp endSheet:m3uExportOptionsPanel];
		[m3uExportOptionsPanel orderOut:self];

		if (result == 1)
		{
			SPPlaylist* playlist = [item playlist];

			NSSavePanel* savePanel = [NSSavePanel savePanel];
            savePanel.allowedFileTypes = @[@"m3u"];
			[savePanel setCanSelectHiddenExtension:YES];
			
			NSString* filename = [NSString stringWithFormat:@"%@.m3u", [playlist name]];
            savePanel.nameFieldStringValue = filename;
            
            [savePanel beginSheetModalForWindow:sourceListView.window completionHandler:^(NSInteger res)
             {
                 if (res == NSModalResponseOK)
                 {
                     BOOL exportRelativePaths = (self->m3uExportRelativePathsButton.state == NSOnState);
                     NSString* exportPathPrefix = self->m3uExportPathPrefixTextField.stringValue;
                     
                     [playlist saveToM3U:(savePanel.URL).path withRelativePaths:exportRelativePaths andPathPrefix:exportPathPrefix];
                 }
             }
             ];
		}
	}
}


// ----------------------------------------------------------------------------
- (IBAction) clickExportRelativePaths:(id)sender
// ----------------------------------------------------------------------------
{
	if ([sender state] == NSOnState)
		[m3uExportPathPrefixTextField setEnabled:YES];
	else
		[m3uExportPathPrefixTextField setEnabled:NO];
}	


// ----------------------------------------------------------------------------
- (IBAction) cancelM3UExportOptions:(id)sender
// ----------------------------------------------------------------------------
{
	[NSApp stopModalWithCode:0];
}


// ----------------------------------------------------------------------------
- (IBAction) confirmM3UExportOptions:(id)sender
// ----------------------------------------------------------------------------
{
	[NSApp stopModalWithCode:1];
}


// ----------------------------------------------------------------------------
- (IBAction) switchToFavoritesPlaylist:(id)sender
// ----------------------------------------------------------------------------
{
	NSMutableArray* playlistItems = [playlistsContainerItem children];
	for (SPSourceListItem* item in playlistItems)
	{
		if ([[item name].string caseInsensitiveCompare:@"Favorites"] == NSOrderedSame)
		{
			NSInteger row = [sourceListView rowForItem:item];
			if (row != -1)
				[sourceListView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		}
	}
}
// ----------------------------------------------------------------------------
- (IBAction) shufflePlaylist:(id)sender
// ----------------------------------------------------------------------------
{
    NSInteger row = sourceListView.selectedRow;
    if (row != -1)
    {
        SPSourceListItem* item = [sourceListView itemAtRow:row];
        if (![item isPlaylistItem])
            return;
        
        SPPlaylist* playlist = [item playlist];
        [playlist shuffleMe];
        [browserDataSource switchToPlaylist:playlist];
    }
}
// ----------------------------------------------------------------------------
- (IBAction) shuffleSmartPlaylist:(id)sender
// ----------------------------------------------------------------------------
{
    NSInteger row = sourceListView.selectedRow;
    if (row != -1)
    {
        SPSourceListItem* item = [sourceListView itemAtRow:row];
        if (![item isSmartPlaylistItem])
            return;
        
        SPPlaylist* playlist = [item playlist];
        [playlist shuffleMe];
        [browserDataSource switchToPlaylist:playlist];
    }
}

// ----------------------------------------------------------------------------
- (BOOL) validateMenuItem:(NSMenuItem*)item
// ----------------------------------------------------------------------------
{
    SEL action = item.action;

    if (action == @selector(editSmartPlaylist:))
    {
		NSInteger row = sourceListView.selectedRow;
		if (row != -1)
		{
			SPSourceListItem* itemA = [sourceListView itemAtRow:row];
			if ([itemA isSmartPlaylistItem])
				return YES;
		}

		return NO;
    }
	else
		return YES;
}


#pragma mark -
#pragma mark sync support


// ----------------------------------------------------------------------------
- (void) checkForAutoSync
// ----------------------------------------------------------------------------
{
	if (!gPreferences.mSyncAutomatically)
		return;
		
	// check if we've passed the sync interval
	NSTimeInterval intervalSinceCheck = [[NSDate date] timeIntervalSinceDate:gPreferences.mLastSyncTime];
	NSTimeInterval desiredInterval = 3600 * 24 * 7;
	
	switch(gPreferences.mSyncInterval)
	{
		case SYNC_DAILY:
			desiredInterval = 3600 * 24;
			break;

		case SYNC_WEEKLY:
			desiredInterval = 3600 * 24 * 7;
			break;

		case SYNC_MONTHLY:
			desiredInterval = 3600 * 24 * 30;
			break;
	}

	//NSLog(@"time interval: %f, desired: %f\n", intervalSinceCheck, desiredInterval);
	
	if (intervalSinceCheck > desiredInterval)
	{
		//NSLog(@"interval has passed, performing sync!\n");
		[self performSyncOperationAutomatically:YES showWarningDialog:YES];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) syncCurrentCollection:(id)sender
// ----------------------------------------------------------------------------
{
	if (currentCollection == nil)
		return;

	[self performSyncOperationAutomatically:NO showWarningDialog:YES];
}
#pragma mark -
#pragma mark RSYNC operations
// ----------------------------------------------------------------------------
- (void) performSyncOperationAutomatically:(BOOL)triggeredByAutoInterval showWarningDialog:(BOOL)showDialog
// ----------------------------------------------------------------------------
{
	BOOL doSync = NO;

	if (showDialog)
	{
		if (triggeredByAutoInterval)
		{
			NSString* alertText = [NSString stringWithFormat:@"Do you want to sync the collection '%@' with the latest available HVSC version now?", [currentCollection name].string];
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:alertText];
			[alert setInformativeText:@"This will delete any files that you've manually added to the collection!"];
			[alert setAlertStyle:NSAlertStyleInformational]; // or NSAlertStyleWarning, or NSAlertStyleCritical
			[alert addButtonWithTitle:@"Remind me later"];
			[alert addButtonWithTitle:@"Sync Collection"];
			[alert addButtonWithTitle:@"Skip this time"];

			NSInteger returnStatus = [alert runModal];
			if (returnStatus == NSAlertSecondButtonReturn)
				doSync = YES;
			else if (returnStatus == NSAlertThirdButtonReturn)
				gPreferences.mLastSyncTime = [NSDate date];
		}
		else
		{
			NSString* alertText = [NSString stringWithFormat:@"Do you really want to sync the collection '%@' with the latest available HVSC version?", [currentCollection name].string];
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:alertText];
			[alert setInformativeText:@"This will delete any files that you've manually added to the collection!"];
			[alert setAlertStyle:NSAlertStyleInformational]; // or NSAlertStyleWarning, or NSAlertStyleCritical
			[alert addButtonWithTitle:@"Cancel"];
			[alert addButtonWithTitle:@"Sync Collection"];

			if ([alert runModal] == NSAlertSecondButtonReturn)
				doSync = YES;
		}
	}
	else
		doSync = YES;
	
	if (!doSync)
		return;
		
	if (rsyncTask.running)
		return;
	
	gPreferences.mLastSyncTime = [NSDate date];

	SPPlayerWindow* window = (SPPlayerWindow*) sourceListView.window;
	[window clickStopButton:self];
	[window orderOut:self];

	[browserDataSource stopSearchAndClearSearchString];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rsyncTaskFinished:) name:NSTaskDidTerminateNotification object:nil];

	NSString* destinationPath = [currentCollection path].stringByStandardizingPath;
	BOOL isFolder = NO;
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:destinationPath isDirectory:&isFolder];
	if (!exists)
	{
		exists = [[NSFileManager defaultManager] createDirectoryAtPath:destinationPath withIntermediateDirectories:NO  attributes:nil error:nil];
		isFolder = YES;
	}

	if (exists && isFolder)
	{
		rsyncTask = [[NSTask alloc] init];
		NSPipe* outputPipe = [NSPipe pipe];
		rsyncTask.standardOutput = outputPipe;
		//[rsyncTask setStandardError:outputPipe];
		rsyncTask.launchPath = @"/usr/bin/rsync";
		//[rsyncTask setCurrentDirectoryPath:destinationPath];
		rsyncTask.arguments = @[@"-rtvz", @"--safe-links", @"--delete", @"--progress", gPreferences.mSyncUrl, destinationPath];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rsyncOutputPending:) name:NSFileHandleReadCompletionNotification object:[rsyncTask.standardOutput fileHandleForReading]];
		[[rsyncTask.standardOutput fileHandleForReading] readInBackgroundAndNotify];
		
		syncProgressActionTextView.string = @" ";
		syncProgressActionTextView.font = [NSFont systemFontOfSize:10.0f];
		
		[syncProgressIndicator setIndeterminate:YES];
		[syncProgressIndicator startAnimation:self];
		[rsyncTask launch];

		syncProgressDialog.showsResizeIndicator = syncProgressDisclosureTriangle.state == NSOnState;
		[syncProgressDialog makeKeyAndOrderFront:self];
	}
	else
	{
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setMessageText:@"Sync operation could not be started."];
		[alert setInformativeText:@"Destination folder of collection does not exist and can't be created."];
		[alert setAlertStyle:NSAlertStyleInformational]; // or NSAlertStyleWarning, or NSAlertStyleCritical
		[alert addButtonWithTitle:@"OK"];
		
		[alert runModal];
		
		SPPlayerWindow* window2 = (SPPlayerWindow*) sourceListView.window;
		[window2 makeKeyAndOrderFront:self];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) cancelSync:(id)sender
// ----------------------------------------------------------------------------
{
	if (rsyncTask == nil)
		return;
		
	[rsyncTask terminate];
}


// ----------------------------------------------------------------------------
- (IBAction) discloseSyncProgressDetails:(id)sender
// ----------------------------------------------------------------------------
{
	NSRect frame = syncProgressDialog.frame;
	BOOL isExpanded = ([sender state] == NSOnState);
	
	float desiredHeight = isExpanded ? 300.0f : syncProgressDialog.minSize.height;

	float diff = desiredHeight - frame.size.height;
	frame.size.height += diff;
	frame.origin.y -= diff;
	[syncProgressDialog setFrame:frame display:YES animate:YES];
	syncProgressDialog.showsResizeIndicator = isExpanded;
	syncProgressActionTextView.hidden = !isExpanded;
}


// ----------------------------------------------------------------------------
- (void) rsyncOutputPending:(NSNotification*)aNotification
// ----------------------------------------------------------------------------
{
    NSData* data = aNotification.userInfo[NSFileHandleNotificationDataItem];

	static NSString* overflowFromPreviousOutput = nil;

    // If the length of the data is zero, then the task is basically over - there is nothing
    // more to get from the handle so we may as well shut down.
    if (data.length)
    {
		NSString* output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

		if (overflowFromPreviousOutput != nil)
			output = [NSString stringWithFormat:@"%@%@", overflowFromPreviousOutput, output];

		//NSLog(@"rsync:\n------------\n%@\n-----------\n", output);
		NSMutableArray* lines = [[output componentsSeparatedByString:@"\n"] mutableCopy];
		
		// If block of output data doesn't end with a linebreak, we have to take the last line
		// and consider it with the next block (fix: removed wrong ;)
		if ([output characterAtIndex:output.length - 1] != '\n')
		{
			overflowFromPreviousOutput = lines.lastObject;
			[lines removeLastObject];
		}
		
		NSMutableString* filteredOutput = [[NSMutableString alloc] init];
		for (NSString* line in lines)
		{
			if (line.length == 0)
				continue;

			if ([line characterAtIndex:0] != ' ')
				[filteredOutput appendFormat:@"%@\n", line];
			else
			{
				NSArray* components = [line componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"()"]];
				if (components.count > 1)
				{
					NSString* bracketContents = components[1];
					NSArray* componentsOfBacketContents = [bracketContents componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]];
					if (componentsOfBacketContents.count == 5)
					{
						NSString* percentString = componentsOfBacketContents[2];
						float progress = [percentString substringWithRange:NSMakeRange(0, percentString.length - 1)].floatValue;
						[syncProgressIndicator setIndeterminate:NO];
						syncProgressIndicator.doubleValue = progress;
					}
				}
			}
		}
		
		NSRange range = NSMakeRange(syncProgressActionTextView.textStorage.length, 0);
		[syncProgressActionTextView replaceCharactersInRange:range withString:filteredOutput];
		[syncProgressActionTextView scrollRangeToVisible:range];
		[syncProgressActionTextView setNeedsDisplay:YES];
    }
    
    // we need to schedule the file handle go read more data in the background again.
    [aNotification.object readInBackgroundAndNotify];  
}


// ----------------------------------------------------------------------------
- (void) rsyncTaskFinished:(NSNotification*)aNotification
// ----------------------------------------------------------------------------
{
	NSTask* task = (NSTask*) aNotification.object;
	if (task != rsyncTask)
		return;
	
	int result = rsyncTask.terminationStatus;
	rsyncTask = nil;

	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:nil];

	NSString* name = [[SPCollectionUtilities sharedInstance] collectionNameOfPath:[currentCollection path]];
	[currentCollection setNameFromString:name];
	[browserDataSource setRootPath:[currentCollection path]];

	[syncProgressIndicator stopAnimation:self];
	
	NSAlert* alert = nil;
	
	if (result == 0)
	{
		syncProgressIndicator.doubleValue = 100.0f;
		
		alert = [[NSAlert alloc] init];
		[alert setMessageText:@"Sync operation has completed."];
		[alert setInformativeText:@"Your collection is now up-to-date."];
		[alert setAlertStyle:NSAlertStyleInformational]; // or NSAlertStyleWarning, or NSAlertStyleCritical
		[alert addButtonWithTitle:@"OK"];
	}
	else if (result == 20)
	{
		alert = [[NSAlert alloc] init];
		[alert setMessageText:@"Sync operation was cancelled."];
		[alert setInformativeText:@"Some files may have already been updated, please check your collection."];
		[alert setAlertStyle:NSAlertStyleInformational]; // or NSAlertStyleWarning, or NSAlertStyleCritical
		[alert addButtonWithTitle:@"OK"];
	}
	else
	{
		alert = [[NSAlert alloc] init];
		[alert setMessageText:@"Sync operation was stopped due to an error."];
		[alert setInformativeText:@"Please try again later, or select a different sync mirror server."];
		[alert setAlertStyle:NSAlertStyleInformational]; // or NSAlertStyleWarning, or NSAlertStyleCritical
		[alert addButtonWithTitle:@"OK"];
	}
	
	[alert runModal];


	SPPlayerWindow* window = (SPPlayerWindow*) sourceListView.window;
	[window makeKeyAndOrderFront:self];

	[syncProgressDialog orderOut:self];
}


// ----------------------------------------------------------------------------
- (NSWindow*) syncProgressDialog
// ----------------------------------------------------------------------------
{
	return syncProgressDialog;
}


#pragma mark -
#pragma mark data source methods


// ----------------------------------------------------------------------------
- (int) outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item 
// ----------------------------------------------------------------------------
{
    if (item == nil)
		return (int)rootItems.count;
	else
		return (int)[item children].count;
}


// ----------------------------------------------------------------------------
- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item 
// ----------------------------------------------------------------------------
{
	return [item hasChildren];
}


// ----------------------------------------------------------------------------
- (id) outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item 
// ----------------------------------------------------------------------------
{
	if (item == nil)
		return rootItems[index];
	else
		return [(SPSourceListItem *)item childAtIndex:index];
}


// ----------------------------------------------------------------------------
- (id) outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item 
// ----------------------------------------------------------------------------
{
    return (item == nil) ? @"no item" : [item name];
}


// ----------------------------------------------------------------------------
- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
// ----------------------------------------------------------------------------
{
	if (item == nil)
		return;
	
	if ([item isSharedPlaylistItem] || [item isSharedSmartPlaylistItem])
		return;
	
	SPSourceListItem* sourceListItem = (SPSourceListItem*) item;
	SPPlaylist* playlist = [sourceListItem playlist];

	NSMutableParagraphStyle* paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
	NSDictionary* attrs = @{NSFontAttributeName: [NSFont systemFontOfSize:12.0f],
																			NSParagraphStyleAttributeName: paragraphStyle};
	NSAttributedString* listItemName = [[NSAttributedString alloc] initWithString:object attributes:attrs];
	
	if (listItemName.length == 0)
		return;
	
	[playlist setName:object];
	[sourceListItem setName:listItemName]; 
	[browserDataSource updatePathControlForPlaylistMode:NO];
	[playlist saveToFile];
	[self sortPlaylists];
	[sourceListView reloadData];
	
	[self bumpUpdateRevision];
	//[self publishSharedCollectionWithPath:gPreferences.mSharedCollectionPath];
	
    NSInteger newRow = [sourceListView rowForItem:item];
	if (newRow >= 0)
		[sourceListView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
}


#pragma mark -
#pragma mark outlineview delegate methods


// ----------------------------------------------------------------------------
- (BOOL) outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item 
// ----------------------------------------------------------------------------
{
	if ([item isPlaylistItem] || [item isSmartPlaylistItem])
		return YES;
		
	return NO;
}


// ----------------------------------------------------------------------------
- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
// ----------------------------------------------------------------------------
{
	if (item != nil && cell != nil)
	{
		SPSourceListItem* selectedItem = [outlineView itemAtRow:outlineView.selectedRow];
		if(selectedItem == item || currentCollection == item)
		{
			NSMutableDictionary* attrs = [[[(SPSourceListItem*)item name] attributesAtIndex:0 effectiveRange:NULL] mutableCopy];
			attrs[NSFontAttributeName] = [NSFont boldSystemFontOfSize:12.0f];
			NSAttributedString* name = [[NSAttributedString alloc] initWithString:[(SPSourceListItem*)item name].string  attributes:attrs];
			[cell setAttributedStringValue:name];
		}
		else
			[cell setAttributedStringValue:[(SPSourceListItem*)item name]];

		[cell setImage:[item icon]];
		[cell setLineBreakMode:NSLineBreakByTruncatingTail];
		[cell setFocusRingType:NSFocusRingTypeNone];

		if ([item isHeader])
		{
			SPSourceListView* view = (SPSourceListView*) outlineView;
			if ([view isActive])
				[cell setTextColor:[NSColor labelColor]];
            //                 [cell setTextColor:[NSColor colorWithDeviceRed:0.376f green:0.431f blue:0.502f alpha:1.0f]];
			else
				[cell setTextColor:[NSColor secondaryLabelColor]];
            //                [cell setTextColor:[NSColor colorWithDeviceRed:0.376f green:0.376f blue:0.376f alpha:1.0f]];
		}
		else
			[cell setTextColor:[NSColor textColor]];
            //        [cell setTextColor:[NSColor blackColor]];

	}
}


// ----------------------------------------------------------------------------
- (BOOL) outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
// ----------------------------------------------------------------------------
{
	return (![item isHeader]);
}


// ----------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray*)items toPasteboard:(NSPasteboard*)pasteboard
// ----------------------------------------------------------------------------
{
	SPSourceListItem* firstItem = (SPSourceListItem*) items[0];
	if (![firstItem isCollectionItem])
		return NO;
	
	draggedItems = items;
    [pasteboard declareTypes:@[SPSourceListCollectionItemPBoardType, NSStringPboardType] owner:self];
	//[pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:items] forType:SPSourceListCollectionItemPBoardType];
    [pasteboard setData:[NSData data] forType:SPSourceListCollectionItemPBoardType];
	
	if (items.count == 1)
		[pasteboard setString:[items[0] path] forType:NSStringPboardType];
	
    return YES;
}


// ----------------------------------------------------------------------------
- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
// ----------------------------------------------------------------------------
{
	SPSourceListItem* proposedItem = item;

	NSString* type = [info.draggingPasteboard availableTypeFromArray:@[NSFilenamesPboardType, SPSourceListCollectionItemPBoardType, SPBrowserItemPBoardType]];
	if (type == nil)
		return NSDragOperationNone;
	
	if (proposedItem == nil)
		return NSDragOperationNone;
	
	if (info.draggingSource == outlineView)
	{
		// Items from the list can not be dropped on items in the list
		if ([type isEqualToString:SPSourceListCollectionItemPBoardType] && [proposedItem isHeader] && proposedItem == collectionsContainerItem && [draggedItems[0] isCollectionItem])
		{
			return NSDragOperationGeneric;
		}
	
		return NSDragOperationNone;
	}
	else
	{
		if ([type isEqualToString:SPBrowserItemPBoardType] && [proposedItem isPlaylistItem] && index == NSOutlineViewDropOnItemIndex)
		{
			return NSDragOperationCopy;
		}
		else if (([type isEqualToString:NSFilenamesPboardType] || [type isEqualToString:SPSourceListCollectionItemPBoardType]) && [proposedItem isHeader] && proposedItem == collectionsContainerItem)
		{
			// If there are files in the list of paths, we can't accept the drop
			NSPasteboard *pasteBoard = info.draggingPasteboard;
			NSArray *files = [pasteBoard propertyListForType:NSFilenamesPboardType];
			BOOL isFolder = NO;
			[[NSFileManager defaultManager] fileExistsAtPath:files[0] isDirectory:&isFolder];
			
			return isFolder ? NSDragOperationGeneric : NSDragOperationNone;
		}
	}
	
	return NSDragOperationNone; 
}


// ----------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index
// ----------------------------------------------------------------------------
{
	NSPasteboard* pasteboard = info.draggingPasteboard;
	NSArray* supportedTypes = @[SPSourceListCollectionItemPBoardType, NSFilenamesPboardType, SPBrowserItemPBoardType];
	NSString* bestType = [pasteboard availableTypeFromArray:supportedTypes];
	SPSourceListItem* targetItem = item;
	long targetIndex = (index == NSOutlineViewDropOnItemIndex) ? -1 : index;
	NSMutableArray* targetContainer = [targetItem children];
	
	if ([bestType isEqualToString:SPSourceListCollectionItemPBoardType])
	{
		// Remove the dragged items from the array
		for (SPSourceListItem* draggedItem in draggedItems)
		{
			[targetContainer removeObject:draggedItem];
		}

		// Add the dragged items at the desired index
		for (SPSourceListItem* draggedItem in draggedItems)
		{
			if (targetIndex >= targetContainer.count)
				[targetContainer addObject:draggedItem];
			else
				[targetContainer insertObject:draggedItem atIndex:targetIndex];
		}
				
		// Rebuild collections preference from datasource
		[gPreferences.mCollections removeAllObjects];
		for (SPSourceListItem* collectionItem in targetContainer)
			[gPreferences.mCollections addObject:[collectionItem path]];
			
		[[SPPreferencesController sharedInstance] save];
	}
	else if ([bestType isEqualToString:NSFilenamesPboardType])
	{
		NSArray* droppedPaths = [pasteboard propertyListForType:NSFilenamesPboardType];
	
		// Add the paths that are directories to the collections list
		for (NSString* path in droppedPaths)
		{
			BOOL folder = NO;
			BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&folder];
			if (!exists || !folder)
				continue;
		
			[self addCollectionItemForPath:path atIndex:targetIndex withImage:nil];
			[gPreferences.mCollections addObject:path];
		}
	}
	else if ([bestType isEqualToString:SPBrowserItemPBoardType] && [targetItem isPlaylistItem])
	{
		// Add the dragged items to the playlist
		SPSimplePlaylist* playlist = (SPSimplePlaylist*) [targetItem playlist];

		for (SPBrowserItem* draggedItem in [browserDataSource draggedItems])
		{
			NSString* relativePath = [[SPCollectionUtilities sharedInstance] makePathRelativeToCollectionRoot:[draggedItem path]];
			SPPlaylistItem* playlistItem = [[SPPlaylistItem alloc] initWithPath:relativePath andSubtuneIndex:0 andLoopCount:1];
			[playlistItem setSubtune:[draggedItem defaultSubTune]];
			[playlist addItem:playlistItem];
		}
		
		[playlist saveToFile];
		[self bumpUpdateRevision];
	}
	
	[sourceListView reloadData];

    return YES;
}


// ----------------------------------------------------------------------------
- (BOOL) outlineView:(NSOutlineView *)sender isGroupItem:(id)item
// ----------------------------------------------------------------------------
{
	return [item isHeader];
}


#pragma mark -
#pragma mark netservice browser delegate methods


// ----------------------------------------------------------------------------
- (void)netServiceBrowser:(NSNetServiceBrowser*)netServiceBrowser didFindService:(NSNetService*)service moreComing:(BOOL)moreComing
// ----------------------------------------------------------------------------
{
	//NSLog(@"Found service: %@\n", service);
	
	// Ignore local service
    /*
	if ([[service name] isEqualToString:[[httpServer netService] name]])
	{
		if (!moreComing)
			[sourceListView reloadData];

		return;
	}
    */
     
	while (serviceBeingResolved != nil)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];
	
	service.delegate = (id<NSNetServiceDelegate>)self;
	[service resolveWithTimeout:10.0f];
	serviceBeingResolved = service;
}	


// ----------------------------------------------------------------------------
- (void)netServiceBrowser:(NSNetServiceBrowser*)netServiceBrowser didRemoveService:(NSNetService*)service moreComing:(BOOL)moreComing
// ----------------------------------------------------------------------------
{
	//NSLog(@"Removing service: %@\n", service);
	NSMutableArray* itemsToRemove = [[NSMutableArray alloc] init];
	
	if (sharedCollectionsContainerItem == nil || ![sharedCollectionsContainerItem hasChildren])
		return;
	
	NSMutableArray* sharedCollectionItems = [sharedCollectionsContainerItem children];
	for (SPSourceListItem* sharedCollectionItem in sharedCollectionItems)
	{
		if ([[sharedCollectionItem service] isEqualTo:service])
			[itemsToRemove addObject:sharedCollectionItem];
	}

	SPSourceListItem* itemToRemove = itemsToRemove[0]; 
	
	if ([service isEqualTo:currentSharedCollectionService] && [collectionsContainerItem hasChildren])
	{
		currentSharedCollectionService = nil;

		// Check if the service is currently selected in the list, if so jump to the first normal collection item
		SPSourceListItem* firstCollectionItem = [collectionsContainerItem childAtIndex:0];
		NSInteger row = [sourceListView rowForItem:firstCollectionItem];
		if (row != -1)
			[sourceListView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

		[self removeSourceListItem:itemToRemove];

		if (!moreComing)
			[sourceListView reloadData];
	}
	else
	{
		// If something else is selected, preserve the selection
		SPSourceListItem* selectedItem = nil;
		NSInteger selectedRow = sourceListView.selectedRow;
		if (selectedRow != -1)
			selectedItem = [sourceListView itemAtRow:selectedRow];
		
		[self removeSourceListItem:itemToRemove];
		if (!moreComing)
		{
			[sourceListView reloadData];
	
			if (selectedItem != nil)
			{
				NSInteger newRow = [sourceListView rowForItem:selectedItem];
				[sourceListView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
			}
		}
	}
}	


// ----------------------------------------------------------------------------
- (BOOL)addressesComplete:(NSArray *)addresses forServiceType:(NSString *)serviceType
// ----------------------------------------------------------------------------
{
    // Perform appropriate logic to ensure that [netService addresses]
    // contains the appropriate information to connect to the service
    return YES;
}



// ----------------------------------------------------------------------------
- (void)netServiceDidResolveAddress:(NSNetService*)service
// ----------------------------------------------------------------------------
{
	//NSLog(@"Resolved service: %@\n", service);
	
	// Preserve the current selection
	SPSourceListItem* selectedItem = nil;
	NSInteger selectedRow = sourceListView.selectedRow;
	if (selectedRow != -1)
		selectedItem = [sourceListView itemAtRow:selectedRow];
	
	// If a service came online, add it to the list
	NSMutableArray* sharedCollectionItems = [sharedCollectionsContainerItem children];
	for (SPSourceListItem* sharedCollectionItem in sharedCollectionItems)
	{
		if ([[sharedCollectionItem service].hostName isEqualToString:service.hostName])
		{
			serviceBeingResolved = nil;
			return;
		}
	}
	
	long sharedServiceCount = sharedCollectionItems != nil ? sharedCollectionItems.count : 0;
	[self addSharedCollectionItemForService:service atIndex:sharedServiceCount];
	
	[sourceListView reloadData];
		
	if (selectedItem != nil)
	{
		NSInteger newRow = [sourceListView rowForItem:selectedItem];
		[sourceListView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
	}
	
	serviceBeingResolved = nil;
}


// ----------------------------------------------------------------------------
- (void)netService:(NSNetService*)service didNotResolve:(NSDictionary *)errorDict
// ----------------------------------------------------------------------------
{
	//NSLog(@"Failed to resolve service: %@\n", service);
	serviceBeingResolved = nil;

    //[self handleError:[errorDict objectForKey:NSNetServicesErrorCode]];
    //[services removeObject:netService];
}


@end


#pragma mark -

@implementation SPSourceListView


// ----------------------------------------------------------------------------
- (void) viewWillMoveToWindow:(NSWindow *)newWindow
// ----------------------------------------------------------------------------
{
	[[NSNotificationCenter defaultCenter] removeObserver:self 
	                                                name:NSWindowDidResignKeyNotification
												  object:nil];
												  
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(windowDidChangeKeyNotification:)
											     name:NSWindowDidResignKeyNotification object:newWindow];
												 
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSWindowDidBecomeKeyNotification
												  object:nil];
												  
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowDidChangeKeyNotification:)
												 name:NSWindowDidBecomeKeyNotification
											   object:newWindow];
}

// NSTableView

// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	isActive = NO;
	self.doubleAction = @selector(doubleClick:);
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(itemDidCollapse:)
											     name:NSOutlineViewItemDidCollapseNotification object:nil];
}


// ----------------------------------------------------------------------------
- (void) reloadData
// ----------------------------------------------------------------------------
{
	[super reloadData];
		
	SPSourceListDataSource* source = (SPSourceListDataSource*)self.dataSource;
	int rootItemCount = [source outlineView:self numberOfChildrenOfItem:nil];
	for (int i = 0; i < rootItemCount; i++)
	{
		SPSourceListItem* item = [source outlineView:self child:i ofItem:nil]; 
		[self expandItem:item];
	}
}


// ----------------------------------------------------------------------------
- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend
// ----------------------------------------------------------------------------
{
	[super selectRowIndexes:indexes byExtendingSelection:extend];

	if (indexes.count == 1)
	{
		SPSourceListItem* selectedItem = [self itemAtRow:indexes.firstIndex];
		[self activateSourceListItem:selectedItem];
	}
}


// ----------------------------------------------------------------------------
- (void) activateSourceListItem:(SPSourceListItem*)selectedItem
// ----------------------------------------------------------------------------
{
	if (selectedItem == nil || [selectedItem isHeader])
		return;
	
	SPSourceListDataSource* dataSource = (SPSourceListDataSource*)self.dataSource;
	SPBrowserDataSource* browserDataSource = [dataSource browserDataSource];
	SPPlaylist* currentPlaylist = [browserDataSource playlist];
	
	enum SourceListItemType type = [selectedItem type];
	
	switch (type)
	{
		case SOURCELIST_COLLECTION:
		{
			[dataSource setCurrentSharedCollectionService:nil];
			NSString* rootPath = [browserDataSource rootPath];
			BOOL rootPathChanged = rootPath == nil || ![rootPath isEqualToString:[selectedItem path]];
			
			[dataSource setCurrentCollection:selectedItem];
			if (rootPathChanged)
			{
				[browserDataSource setRootPath:[selectedItem path]];
				[dataSource recacheSmartPlaylists];
			}
			else
			{
				NSString* currentPath = [browserDataSource currentPath];
				if (currentPath != nil)
					[browserDataSource switchToPath:currentPath];
				else
					[browserDataSource switchToPath:rootPath];
			}
			[self reloadData];
		}
		break;
			
		case SOURCELIST_PLAYLIST:
		case SOURCELIST_SMARTPLAYLIST:
			
			if ([selectedItem playlist] != currentPlaylist || currentPlaylist == nil)
			{
				[dataSource setCurrentSharedCollectionService:nil];
				[browserDataSource switchToPlaylist:[selectedItem playlist]];
                [browserDataSource activateLastPlayedItem];
			}
		break;
			
		case SOURCELIST_SHAREDCOLLECTION:
		{
			NSNetService* service = [selectedItem service];
			if (service != nil)
			{
				[dataSource setCurrentSharedCollectionService:service];
				[browserDataSource setSharedCollectionRootPath:[selectedItem path] withServiceName:service.name];
			}
		}
		break;
			
		case SOURCELIST_SHAREDPLAYLIST:
		case SOURCELIST_SHAREDSMARTPLAYLIST:
			
			if ([selectedItem playlist] != currentPlaylist || currentPlaylist == nil)
			{
				BOOL smartPlaylist = type == SOURCELIST_SHAREDSMARTPLAYLIST;
				[browserDataSource switchToSharedPlaylist:[selectedItem playlist] withService:[selectedItem service] isSmartPlaylist:smartPlaylist];
				[dataSource setCurrentSharedCollectionService:[selectedItem service]];
			}
		break;
			
		default:
			break;
	}
	
}


// NSTableView (Private)

// ----------------------------------------------------------------------------
- (void) windowDidChangeKeyNotification:(NSNotification*)notification
// ----------------------------------------------------------------------------
{
	if ([notification.name isEqualToString:NSWindowDidBecomeKeyNotification])
		isActive = YES;
	else
		isActive = NO;
}


// ----------------------------------------------------------------------------
- (void) keyDown:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	NSString* characters = event.charactersIgnoringModifiers;
	unichar character = [characters characterAtIndex:0];
	
	if (character == 63272 || character == 127)
	{
		[(SPSourceListDataSource*)self.dataSource removeSelectedSourceListItem:self];
		return;
	}
	
	[super keyDown:event];
}


// ----------------------------------------------------------------------------
- (void) itemDidCollapse:(NSNotification*)notification
// ----------------------------------------------------------------------------
{

}


// ----------------------------------------------------------------------------
- (BOOL) isActive
// ----------------------------------------------------------------------------
{
	return isActive;
}


// ----------------------------------------------------------------------------
- (void)drawRow:(NSInteger)rowIndex clipRect:(NSRect)clipRect
// ----------------------------------------------------------------------------
{
	[super drawRow:rowIndex clipRect:clipRect];
}


// ----------------------------------------------------------------------------
- (NSMenu*) menuForEvent:(NSEvent *)event
// ----------------------------------------------------------------------------
{
	NSPoint position = [self convertPoint:event.locationInWindow fromView:nil];
	NSInteger row = [self rowAtPoint:position];
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

	SPSourceListItem* item = [self itemAtRow:row];
	
	if (item == nil)
		return nil;

	if ([item isCollectionItem])
		return collectionItemMenu;
	else if ([item isSharedCollectionItem])
		return collectionItemMenu;
	else if ([item isPlaylistItem])
		return playlistItemMenu;
	else if ([item isSmartPlaylistItem])
		return smartPlaylistItemMenu;
		
	return nil;
}

@end


