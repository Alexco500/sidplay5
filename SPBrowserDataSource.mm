#import "SPBrowserDataSource.h"
#import "SPBrowserItem.h"
#import "SPHttpBrowserItem.h"
#import "SPPlayerWindow.h"
#import "SongLengthDatabase.h"
#import "SPCollectionUtilities.h"
#import "SPStilBrowserController.h"
#import "SPSourceListDataSource.h"
#import "SPSourceListItem.h"
#import "SPPlaylist.h"
#import "SPPlaylistItem.h"
#import "SPSimplePlaylist.h"
#import "SPSmartPlaylist.h"
#import "SPPredicateEditorController.h"
#import "SPExportController.h"
#import "SPExporter.h"
#import "SPPreferencesController.h"
#import "SPBrowserState.h"
#import "SPRemixKwedOrgController.h"
#import "SPGradientBox.h"


@implementation SPBrowserDataSource

NSString* SPBrowserItemPBoardType = @"SPBrowserItemPBoardType";

NSDate* fillStart = nil;


// ----------------------------------------------------------------------------
- (id) init
// ----------------------------------------------------------------------------
{
	if (self = [super init])
	{
		rootItems = [[NSMutableArray alloc] init];
		browseHistory = [[NSMutableArray alloc] init];;
		browseHistoryIndex = 0;
		currentPath = nil;
		currentItem = nil;
		draggedItems = nil;
		unfilteredPlaylistItems = nil;
        shuffledPlaylistItems = nil;
        currentShuffleIndex = 0;
		playlist = nil;
		browserMode = BROWSER_MODE_COLLECTION;
		currentSharedCollection = nil;
		currentSharedCollectionRoot = nil;
		currentSharedCollectionName = nil;
		
		spotlightSearchTypeSubViewVisible = NO;
		limitSpotlightScopeToCurrentFolder = NO;
		
		savedState = nil;
		
		searchQuery = [[NSMetadataQuery alloc] init];
		[searchQuery setDelegate:self];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchQueryNotification:) name:nil object:searchQuery];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(smartPlaylistUpdatedNotification:) name:SPSmartPlaylistChangedNotification object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(httpBrowserItemInfoDownloaded:) name:SPHttpBrowserItemInfoDownloadedNotification object:nil];	
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(httpBrowserItemIndexDownloaded:) name:SPHttpBrowserItemIndexDownloadedNotification object:nil];	
		
		rootPath = nil;
	}
	
	return self;
}


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[[SPPreferencesController sharedInstance] load];

	[browserView registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, SPSourceListCollectionItemPBoardType, SPBrowserItemPBoardType, nil]];
	[browserView setVerticalMotionCanBeginDrag:YES];
	
	[self adjustSearchTypeControlsAndMenu];

	[progressIndicator setHidden:YES];
	[searchTypeProgressIndicator setHidden:YES];
	
	[self setPlaybackModeControlImages];

	NSArray* columns = [browserView tableColumns];
	for (NSTableColumn* column in columns)
	{
		NSString* identifier = [column identifier];
		if ([identifier isEqualToString:@"title"])
			tableColumns[COLUMN_TITLE] = column;
		else if ([identifier isEqualToString:@"time"])
			tableColumns[COLUMN_TIME] = column;
		else if ([identifier isEqualToString:@"author"])
			tableColumns[COLUMN_AUTHOR] = column;
		else if ([identifier isEqualToString:@"released"])
			tableColumns[COLUMN_RELEASED] = column;
		else if ([identifier isEqualToString:@"path"])
			tableColumns[COLUMN_PATH] = column;
		else if ([identifier isEqualToString:@"index"])
			tableColumns[COLUMN_INDEX] = column;
		else if ([identifier isEqualToString:@"subtune"])
			tableColumns[COLUMN_SUBTUNE] = column;
		else if ([identifier isEqualToString:@"repeat"])
			tableColumns[COLUMN_REPEAT] = column;
	}

	// Set the loop icon on the loopcount column
	NSTableHeaderCell* cell = [tableColumns[COLUMN_REPEAT] headerCell];
	[cell setImage:[NSImage imageNamed:@"repeat"]];
	
	// Initially we start in normal browser mode
	[self setBrowserMode:BROWSER_MODE_COLLECTION];
	//[self setPlaylistModeBrowserColumns:NO];
}


// ----------------------------------------------------------------------------
- (void) updateCurrentSong:(NSInteger)seconds
// ----------------------------------------------------------------------------
{
	if (currentItem == nil)
		return;

	if ([self isSharedCollection])
		return;
	
	NSInteger loopCount = [currentItem loopCount];
	BOOL loopsForever = (loopCount == 0);
	if (playlist == nil)
		loopsForever = gPreferences.mRepeatActive;
	
	if (!loopsForever)
	{
		SPPlayerWindow* window = (SPPlayerWindow*) [browserView window];

		int currentSongLength = (int)[window currentTuneLengthInSeconds];
		if (currentSongLength == 0)
			currentSongLength = gPreferences.mDefaultPlayTime;
		else if (loopCount > 0)
			currentSongLength *= loopCount;
		
		const float fadeTime = 3.0f;
		
		if (seconds > currentSongLength)
		{
			[window stopFadeOut];
			
			if (playlist != nil)
				[self playNextPlaylistItem:self];
			else
			{ 
				if (gPreferences.mShuffleActive)
                {
                    if (browserMode == BROWSER_MODE_SPOTLIGHT_RESULT)
                    {
                        [self playRandomTuneFromSearchResults];
                    }
                    else
                        [window playRandomTuneFromCollection:self];
                }
				else
				{
					SPBrowserItem* parentItem = [currentItem parent];
					NSMutableArray* itemArray = (parentItem == nil) ? rootItems : [parentItem children];

					if (itemArray != nil && [itemArray count] > 0)
					{
						NSInteger currentItemIndex = [itemArray indexOfObject:currentItem];
						
						SPBrowserItem* item = nil;
						BOOL isFolder = YES;
						NSInteger nextItemIndex = currentItemIndex;
						NSInteger firstIndex = -1;
						
						while (isFolder && nextItemIndex != firstIndex)
						{
							nextItemIndex = (nextItemIndex + 1) % [itemArray count];
							if (firstIndex == -1)
								firstIndex = nextItemIndex;
							item = [itemArray objectAtIndex:nextItemIndex];
							if (item != nil)
								isFolder = [item isFolder];
						}

						if (item != nil)
						{
							[self playItem:item];
							int row = (int)[browserView rowForItem:currentItem];
							[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
							[browserView scrollRowToVisible:row];
						}
					}
				}
			}
		}
		else if (gPreferences.mFadeActive && currentSongLength > fadeTime && seconds >= (currentSongLength - fadeTime))
		{
			[window startFadeOut];
		}
	}
}


// ----------------------------------------------------------------------------
- (NSMutableArray*) rootItems
// ----------------------------------------------------------------------------
{
	return rootItems;
}


// ----------------------------------------------------------------------------
- (SPPlaylist*) playlist
// ----------------------------------------------------------------------------
{
	return playlist;
}


#pragma mark -
#pragma mark maintaining the browser contents


// ----------------------------------------------------------------------------
- (void) switchToPlaylist:(SPPlaylist*)thePlaylist 
// ----------------------------------------------------------------------------
{
	if (rootPath == nil)
		return;
		
    BOOL inNormalBrowserMode = (browserMode == BROWSER_MODE_COLLECTION);
        
	playlist = thePlaylist;
	if (playlist == nil)
		return;

	BOOL isSmartPlaylist = [playlist isKindOfClass:[SPSmartPlaylist class]];
	
	[self setInProgress:YES];
    if (inNormalBrowserMode)
        [self saveBrowserState];
	[self stopSearchAndClearSearchString];
	[rootItems removeAllObjects];

	currentSharedCollection = nil;
	[self setBrowserMode:isSmartPlaylist ? BROWSER_MODE_SMART_PLAYLIST : BROWSER_MODE_PLAYLIST];

	BOOL isCaching = isSmartPlaylist && [(SPSmartPlaylist*)playlist isCachingItems];

	if (!isCaching)
		[SPBrowserItem fillArray:rootItems withPlaylist:playlist];

    if (gPreferences.mShuffleActive)
        [self shufflePlaylist];
    
	[browserView reloadData];
	[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    [browserView scrollRowToVisible:0];

	[self updatePathControlForPlaylistMode:isCaching];
	[self clearBrowseHistory];
	if (!isCaching)
		[self setInProgress:NO];
}


// ----------------------------------------------------------------------------
- (void) switchToSharedPlaylist:(SPPlaylist*)thePlaylist withService:(NSNetService*)service isSmartPlaylist:(BOOL)smartPlaylist
// ----------------------------------------------------------------------------
{
    BOOL inNormalBrowserMode = (browserMode == BROWSER_MODE_COLLECTION);
	
	playlist = thePlaylist;
	if (playlist == nil)
		return;
	
	BOOL isSmartPlaylist = smartPlaylist;
	
	[self setInProgress:YES];
    if (inNormalBrowserMode)
        [self saveBrowserState];
	[self stopSearchAndClearSearchString];
    
    if (browserMode == BROWSER_MODE_SHARED_PLAYLIST || browserMode == BROWSER_MODE_SHARED_SMART_PLAYLIST || browserMode == BROWSER_MODE_SHARED_COLLECTION)
    {
        for (SPHttpBrowserItem* item in rootItems)
            [item cancelDownload];
    }
    
	[rootItems removeAllObjects];
	
	currentSharedCollection = nil;
	currentSharedCollectionName = [service name];
	[self setBrowserMode:isSmartPlaylist ? BROWSER_MODE_SHARED_SMART_PLAYLIST : BROWSER_MODE_SHARED_PLAYLIST];
	
	NSString* host = [service hostName];
	NSInteger port = [service port];
	NSString* urlString = nil;
	if (port != -1)
		urlString = [NSString stringWithFormat:@"http://%@:%ld", host, (long)port];
	
    fillStart = [NSDate date];
    
	[SPHttpBrowserItem fillArray:rootItems withSharedPlaylist:playlist fromUrl:urlString];
	
	[browserView reloadData];
	[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    [browserView scrollRowToVisible:0];
	
	[self updatePathControlForPlaylistMode:NO];
	[self clearBrowseHistory];
	[self setInProgress:NO];
}


// ----------------------------------------------------------------------------
- (void) setPlaylistModeBrowserColumns:(BOOL)playlistMode
// ----------------------------------------------------------------------------
{
	static NSSortDescriptor* previousSortDescriptor = nil;
	
	if (playlistMode)
	{
		[tableColumns[COLUMN_INDEX] setHidden:NO];
		[tableColumns[COLUMN_SUBTUNE] setHidden:NO];
		[tableColumns[COLUMN_REPEAT] setHidden:NO];

		[[browserView headerView] setMenu:tableHeaderPlaylistContextMenu];
		
		[saveSearchAsSmartPlaylistButton setEnabled:NO];
		[searchFullCollectionButton setEnabled:NO];
		[searchCurrentFolderButton setEnabled:NO];

		[nextPlaylistItemMenuItem setEnabled:YES];
		[previousPlaylistItemMenuItem setEnabled:YES];

		previousSortDescriptor = [[browserView sortDescriptors] objectAtIndex:0];
		NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"playlistIndex" ascending:YES selector:@selector(compare:)];
		[browserView setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	}
	else
	{
		[tableColumns[COLUMN_INDEX] setHidden:YES];
		[tableColumns[COLUMN_SUBTUNE] setHidden:YES];
		[tableColumns[COLUMN_REPEAT] setHidden:YES];
		
		[[browserView headerView] setMenu:tableHeaderContextMenu];

		[saveSearchAsSmartPlaylistButton setEnabled:YES];
		[searchFullCollectionButton setEnabled:YES];
		[searchCurrentFolderButton setEnabled:YES];

		[nextPlaylistItemMenuItem setEnabled:NO];
		[previousPlaylistItemMenuItem setEnabled:NO];

		if (previousSortDescriptor != nil)
			[browserView setSortDescriptors:[NSArray arrayWithObject:previousSortDescriptor]];
	}

	// Reflect the table column state in the header context menu
	NSArray* items = [tableHeaderContextMenu itemArray];
	for (NSMenuItem* item in items)
	{
		ColumnType columnType = (ColumnType)[item tag];
		NSTableColumn* column = tableColumns[columnType];
		if ([column isHidden])
			[item setState:NSOffState];
		else
			[item setState:NSOnState];
	}

	items = [tableHeaderPlaylistContextMenu itemArray];
	for (NSMenuItem* item in items)
	{
		ColumnType columnType = (ColumnType)[item tag];
		NSTableColumn* column = tableColumns[columnType];
		if ([column isHidden])
			[item setState:NSOffState];
		else
			[item setState:NSOnState];
	}

	[self enableSmartPlaylistEditor:NO];
}


// ----------------------------------------------------------------------------
- (void) enableSmartPlaylistEditor:(BOOL)enable
// ----------------------------------------------------------------------------
{
	if (enable)
	{
		[predicateEditorController setPredicate:[(SPSmartPlaylist*)playlist predicate]];
		SPPlayerWindow* window = (SPPlayerWindow*) [browserView window];
		[predicateEditorController addPredicateEditorToWindow:window];
	}
	else
		[predicateEditorController removePredicateEditor];
}


// ----------------------------------------------------------------------------
- (void) enableSpotlightSearchTypeSubView:(BOOL)enable
// ----------------------------------------------------------------------------
{
	if (enable && !spotlightSearchTypeSubViewVisible)
	{
		SPPlayerWindow* window = (SPPlayerWindow*) [browserView window];
		[window addAlternateBoxView:(NSView*)spotlightSearchTypeSubView];
		spotlightSearchTypeSubViewVisible = true;
	}
	else if (!enable && spotlightSearchTypeSubViewVisible)
	{
		[spotlightSearchTypeSubView removeFromSuperview];
		spotlightSearchTypeSubViewVisible = false;
	}
}


// ----------------------------------------------------------------------------
- (void) switchToSharedCollectionURL:(NSString*)urlString withServiceName:(NSString*)serviceName
// ----------------------------------------------------------------------------
{
	if (urlString == nil)
		return;
	
	[self setBrowserMode:BROWSER_MODE_SHARED_COLLECTION];

	if (currentSharedCollection == nil)
	{
		[self clearBrowseHistory];
		currentSharedCollectionRoot = urlString;
	}

	currentSharedCollection = urlString;
	
	if (serviceName != nil)
		currentSharedCollectionName = serviceName;
	
	[self setInProgress:YES];
	[self stopSearchAndClearSearchString];
	
	currentPath = nil;
	playlist = nil;
	[rootItems removeAllObjects];

	NSURL* url = [NSURL URLWithString:urlString];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    [request setValue:SPUrlRequestUserAgentString forHTTPHeaderField:@"User-Agent"];
    indexData = [NSMutableData data];
    indexDownloadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	//NSLog(@"Downloading index of shared collection dir at: %@\n", urlString);
}


// ----------------------------------------------------------------------------
- (void) connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
// ----------------------------------------------------------------------------
{
	[indexData setLength:0];
}


// ----------------------------------------------------------------------------
- (void) connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
// ----------------------------------------------------------------------------
{
	[indexData appendData:data];
}


// ----------------------------------------------------------------------------
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
// ----------------------------------------------------------------------------
{
	//NSLog(@"connection failed!\n");
}


// ----------------------------------------------------------------------------
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
// ----------------------------------------------------------------------------
{
    NSString* indexDataString = [[NSString alloc] initWithData:indexData encoding:NSUTF8StringEncoding];
    if (indexData == nil)
        return;
	
    NSArray* indexDataItems = [indexDataString componentsSeparatedByString:@"\n"];
    
    [SPHttpBrowserItem fillArray:rootItems withIndexDataItems:indexDataItems fromUrl:currentSharedCollection andParent:nil];
	
	[rootItems sortUsingDescriptors:[browserView sortDescriptors]];
	[browserView reloadData];
	[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	[browserView scrollRowToVisible:0];
	
	NSString* relativeUrlString = [[NSURL URLWithString:currentSharedCollection] relativePath];
	NSString* escapedCollectionName = [currentSharedCollectionName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString* pathControlUrlString = [NSString stringWithFormat:@"http://dummy/SHARED/%@/%@", escapedCollectionName, relativeUrlString];
	//NSLog(@"%@ %@ %@ %@\n", currentSharedCollection, relativeUrlString, escapedCollectionName, pathControlUrlString);
	[pathControl setURL:[NSURL URLWithString:pathControlUrlString]];
	
	NSImage* folderIcon = [[NSWorkspace sharedWorkspace] iconForFile:@"/bin"];
	NSArray* pathComponentCells = [pathControl pathComponentCells];
	for (int i = 1; i < [pathComponentCells count]; i++)
	{
		NSPathComponentCell* componentCell = [pathComponentCells objectAtIndex:i];
		[componentCell setImage:(i > 1) ? folderIcon : [SPSourceListItem sharedCollectionIcon]];
	}
	
	[self setInProgress:NO];

	indexData = nil;
	indexDownloadConnection = nil;
}


// ----------------------------------------------------------------------------
- (void) httpBrowserItemInfoDownloaded:(NSNotification *)notification
// ----------------------------------------------------------------------------
{
	SPHttpBrowserItem* item = (SPHttpBrowserItem*) [notification object];
	[browserView reloadItem:item];
    
    bool allValid = true;
    for (SPHttpBrowserItem* checkItem in rootItems)
    {
        if (![checkItem isValid])
        {
            //NSLog(@"item %@ not valid: %@\n", checkItem, [checkItem path]);
            allValid = false;
            break;
        }
    }
    
    if (allValid)
    {
        //NSDate* fillEnd = [NSDate date];
        //NSLog(@"Filling took %f seconds\n", [fillEnd timeIntervalSinceDate:fillStart]);
    }
    
    
}


// ----------------------------------------------------------------------------
- (void) httpBrowserItemIndexDownloaded:(NSNotification *)notification
// ----------------------------------------------------------------------------
{
	//SPHttpBrowserItem* item = (SPHttpBrowserItem*) [notification object];
	[browserView reloadData];
}


// ----------------------------------------------------------------------------
- (NSString*) rootPath
// ----------------------------------------------------------------------------
{
	return rootPath;
}


// ----------------------------------------------------------------------------
- (void) setRootPath:(NSString*)path
// ----------------------------------------------------------------------------
{
	BOOL rootPathChanged = ![rootPath isEqualToString:path];
	rootPath = path;
	playlist = nil;
	
	if (rootPathChanged)
	{
		SongLengthDatabase* database = [[SongLengthDatabase alloc] initWithRootPath:rootPath];
		[SongLengthDatabase setSharedInstance:database];
		[[SPCollectionUtilities	sharedInstance] setRootPath:rootPath];
	}
	
	[self switchToPath:path];
	[self clearBrowseHistory];
}


// ----------------------------------------------------------------------------
- (void) setSharedCollectionRootPath:(NSString*)urlString withServiceName:(NSString*)serviceName
// ----------------------------------------------------------------------------
{
	BOOL rootPathChanged = ![rootPath isEqualToString:urlString];
	rootPath = urlString;
	playlist = nil;
	
	if (rootPathChanged)
	{
		SongLengthDatabase* database = [[SongLengthDatabase alloc] initWithRootUrlString:rootPath];
		[SongLengthDatabase setSharedInstance:database];
		//[[SPCollectionUtilities sharedInstance] setRootPath:rootPath];
	}
	
	[self switchToSharedCollectionURL:urlString withServiceName:serviceName];
	[self clearBrowseHistory];
}


// ----------------------------------------------------------------------------
- (NSString*) currentPath
// ----------------------------------------------------------------------------
{
	return currentPath;
}


#pragma mark -
#pragma mark browsing and navigation history methods


// ----------------------------------------------------------------------------
- (void) browseToPath:(NSString*)path
// ----------------------------------------------------------------------------
{
	NSString* previousPath = (browserMode == BROWSER_MODE_SHARED_COLLECTION) ? currentSharedCollection : currentPath;
	
	if ([browseHistory count] == 0)
	{
		[browseHistory addObject:previousPath];
		[browseHistory addObject:path];
		browseHistoryIndex = 1;
	}
	else
	{
		browseHistoryIndex++;
		[browseHistory removeObjectsInRange:NSMakeRange(browseHistoryIndex, [browseHistory count] - browseHistoryIndex)];
		[browseHistory insertObject:path atIndex:browseHistoryIndex];
		[navigationControl setEnabled:NO forSegment:1];
	}

	[navigationControl setEnabled:YES forSegment:0];

	//NSLog(@"browse to %@, history: %@, index: %d\n", path, browseHistory, browseHistoryIndex);

	if (browserMode != BROWSER_MODE_SHARED_COLLECTION)
		[self switchToPath:path];
	else
		[self switchToSharedCollectionURL:path withServiceName:nil];
}


// ----------------------------------------------------------------------------
- (void) switchToPath:(NSString*)path
// ----------------------------------------------------------------------------
{
	[self setInProgress:YES];
	[self stopSearchAndClearSearchString];
	
	currentSharedCollection = nil;
	[self setBrowserMode:BROWSER_MODE_COLLECTION];

	currentPath = path;
	playlist = nil;
	[rootItems removeAllObjects];
	BOOL stateRestored = [self restoreBrowserState];
	if (!stateRestored)
	{
		[SPBrowserItem fillArray:rootItems withDirectoryContentsAtPath:currentPath andParent:nil];
		[rootItems sortUsingDescriptors:[browserView sortDescriptors]];
		[browserView reloadData];
		[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
   		[browserView scrollRowToVisible:0];
	}
	
	[pathControl setURL:[NSURL fileURLWithPath:currentPath]];

	[self setInProgress:NO];
}


// ----------------------------------------------------------------------------
- (IBAction) navigateBackFromMenu:(id)sender
// ----------------------------------------------------------------------------
{
	[self navigateBack];
}


// ----------------------------------------------------------------------------
- (IBAction) navigateForwardFromMenu:(id)sender
// ----------------------------------------------------------------------------
{
	[self navigateForward];
}


// ----------------------------------------------------------------------------
- (void) navigateBack
// ----------------------------------------------------------------------------
{
	if (rootPath == nil)
		return;

	if (browseHistoryIndex > 0)
	{
		browseHistoryIndex--;
		if (browserMode != BROWSER_MODE_SHARED_COLLECTION)
			[self switchToPath:[browseHistory objectAtIndex:browseHistoryIndex]];
		else
			[self switchToSharedCollectionURL:[browseHistory objectAtIndex:browseHistoryIndex] withServiceName:nil];
		
		if (browseHistoryIndex == 0)
			[navigationControl setEnabled:NO forSegment:0];

		[navigationControl setEnabled:YES forSegment:1];
	}

	//NSLog(@"browse back to %@, history: %@, index: %d\n", currentPath, browseHistory, browseHistoryIndex);
}


// ----------------------------------------------------------------------------
- (void) navigateForward
// ----------------------------------------------------------------------------
{
	if (rootPath == nil)
		return;

	if (browseHistoryIndex < ([browseHistory count] - 1))
	{
		browseHistoryIndex++;
		if (browserMode != BROWSER_MODE_SHARED_COLLECTION)
			[self switchToPath:[browseHistory objectAtIndex:browseHistoryIndex]];
		else
			[self switchToSharedCollectionURL:[browseHistory objectAtIndex:browseHistoryIndex] withServiceName:nil];
		
		if (browseHistoryIndex == ([browseHistory count] - 1))
		{
			[navigationControl setEnabled:NO forSegment:1];
		}

		[navigationControl setEnabled:YES forSegment:0];
	}

	//NSLog(@"browse forward to %@, history: %@, index: %d\n", currentPath, browseHistory, browseHistoryIndex);
}


// ----------------------------------------------------------------------------
- (void) clearBrowseHistory
// ----------------------------------------------------------------------------
{
	browseHistoryIndex = 0;
	[browseHistory removeAllObjects];
	[navigationControl setEnabled:NO forSegment:0];
	[navigationControl setEnabled:NO forSegment:1];

	//NSLog(@"browse history cleared\n");
}


// ----------------------------------------------------------------------------
- (void) updatePathControlForPlaylistMode:(BOOL)isCaching
// ----------------------------------------------------------------------------
{
	NSString* escapedPlaylistName = [[playlist name] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	if (browserMode == BROWSER_MODE_SHARED_PLAYLIST || browserMode == BROWSER_MODE_SHARED_SMART_PLAYLIST)
	{
		BOOL isSmartPlaylist = browserMode == BROWSER_MODE_SHARED_SMART_PLAYLIST;
		NSString* escapedCollectionName = [currentSharedCollectionName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		NSString* pathControlUrlString = [NSString stringWithFormat:@"http://dummy/SHARED/%@/PLAYLISTS/%@%%20(%lu%%20songs)", escapedCollectionName, escapedPlaylistName, (unsigned long)[rootItems count]];

		[pathControl setURL:[NSURL URLWithString:pathControlUrlString]];

		NSPathComponentCell* componentCell = [[pathControl pathComponentCells] objectAtIndex:1];
		[componentCell setImage:[SPSourceListItem sharedCollectionIcon]];
		componentCell = [[pathControl pathComponentCells] objectAtIndex:3];
		[componentCell setImage:isSmartPlaylist ? [SPSourceListItem smartPlaylistIcon] : [SPSourceListItem playlistIcon]];
	}
	else
	{
		BOOL isSmartPlaylist = browserMode == BROWSER_MODE_SMART_PLAYLIST;

		if (isCaching)
			[pathControl setURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://dummy/PLAYLISTS/%@%%20(caching%%2c%%20please%%20wait%%2e%%2e%%2e)", escapedPlaylistName]]];
		else
			[pathControl setURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://dummy/PLAYLISTS/%@%%20(%lu%%20songs)", escapedPlaylistName, (unsigned long)[rootItems count]]]];

		NSPathComponentCell* componentCell = [[pathControl pathComponentCells] objectAtIndex:1];
		[componentCell setImage:isSmartPlaylist ? [SPSourceListItem smartPlaylistIcon] : [SPSourceListItem playlistIcon]];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) clickNavigateControl:(id)sender
// ----------------------------------------------------------------------------
{
	if (rootPath == nil)
		return;

	if ([sender isSelectedForSegment:0])
	{
		[self navigateBack];
	}
	else if ([sender isSelectedForSegment:1])
	{
		[self navigateForward];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) clickPathControl:(id)sender
// ----------------------------------------------------------------------------
{
	if (rootPath == nil)
		return;

	NSPathComponentCell* cell = [sender clickedPathComponentCell];
	NSString* path = [[cell URL] relativePath];
	
	if (browserMode == BROWSER_MODE_SHARED_COLLECTION)
	{
		NSMutableArray* pathComponents = [[path pathComponents] mutableCopy];
		// strip away any leading http URL stuff
		[pathComponents removeObjectsInRange:NSMakeRange(0, 3)];
		NSString* relativePath = [NSString pathWithComponents:pathComponents];
		NSString* newURLString;
		if ([relativePath length] == 0)
			newURLString = currentSharedCollectionRoot;
		else
			newURLString = [NSString stringWithFormat:@"%@%@/", currentSharedCollectionRoot, relativePath];
		//NSLog(@"url: %@\nrelativePath: %@\ncurrentSharedCollectionRoot: %@\nnewURLString: %@\n\n", [cell URL], relativePath, currentSharedCollectionRoot, newURLString);
		[self browseToPath:newURLString];
	}
	else
	{
		if ([[path pathComponents] count] < [[rootPath pathComponents] count])
			return;
		
		[self browseToPath:path];
	}
}


// ----------------------------------------------------------------------------
- (void) playItem:(SPBrowserItem*)item
// ----------------------------------------------------------------------------
{
	SPPlayerWindow* window = (SPPlayerWindow*) [browserView window];

	if ([item class] == [SPHttpBrowserItem class])
		[window playTuneAtURL:[item path] subtune:[item defaultSubTune]];
	else
		[window playTuneAtPath:[item path] subtune:[item defaultSubTune]];

	currentItem = item;
}



// ----------------------------------------------------------------------------
- (void) browseToFile:(NSString*)path andSetAsCurrentItem:(BOOL)setAsCurrentItem
// ----------------------------------------------------------------------------
{
	BOOL wasInPlaylist = playlist != nil;
	
	// Deselect source list item (most likely a playlist) and select the
	// current collection item
	SPSourceListView* sourceListView = [sourceListDataSource sourceListView]; 
	int row = (int)[sourceListView selectedRow];
	SPSourceListItem* collectionItem = [sourceListDataSource currentCollection];
	if (collectionItem != nil)
	{
		int newRow = (int)[sourceListView rowForItem:collectionItem];
		if (row != newRow)
		{
			[sourceListView deselectRow:row];
			[sourceListView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		}
	}

	NSString* directory = [path stringByDeletingLastPathComponent];
	if (wasInPlaylist)
		[self switchToPath:directory];
	else
		[self browseToPath:directory];
	
	// Make the item visible in the browser
	for (SPBrowserItem* browserItem in rootItems)
	{
		if ([[browserItem path] caseInsensitiveCompare:path] == NSOrderedSame)
		{
			NSInteger row = [browserView rowForItem:browserItem];
			[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
			[browserView scrollRowToVisible:row];
			if (setAsCurrentItem)
				currentItem = browserItem;
			break;
		}
	}
}


// ----------------------------------------------------------------------------
- (void) findExpandedItems:(NSMutableArray*)expandedItems inItems:(NSMutableArray*)items
// ----------------------------------------------------------------------------
{
	for (SPBrowserItem* item in items)
	{
		if ([browserView isItemExpanded:item] && [item isFolder])
		{
			[expandedItems addObject:item];
			[self findExpandedItems:expandedItems inItems:[item children]];
		}
	}
}


// ----------------------------------------------------------------------------
- (void) saveBrowserState
// ----------------------------------------------------------------------------
{
	if (currentPath == nil)
		return;
		
	if (browserMode == BROWSER_MODE_SPOTLIGHT_RESULT)
		return;
		
	NSMutableArray* expandedItems = [[NSMutableArray alloc] init];
	[self findExpandedItems:expandedItems inItems:rootItems];

	NSMutableArray* selectedItems = [[NSMutableArray alloc] init];
	NSIndexSet* selectedIndices = [browserView selectedRowIndexes];
	NSUInteger index = [selectedIndices firstIndex];
	while (index != NSNotFound)
	{
		SPBrowserItem* item = [browserView itemAtRow:index];
		if (item != nil)
			[selectedItems addObject:item];
	
		index = [selectedIndices indexGreaterThanIndex:index];
	}

	savedState = [[SPBrowserState alloc] initWithPath:currentPath andItems:rootItems andExpandedFolders:expandedItems andSelectedItems:selectedItems];
}


// ----------------------------------------------------------------------------
- (BOOL) restoreBrowserState
// ----------------------------------------------------------------------------
{
	if (savedState == nil)
		return NO;
	
	if (currentPath == nil)
		return NO;
	
	if (![currentPath isEqualToString:[savedState currentPath]])
		return NO;
		
	rootItems = [savedState rootItems];
	[browserView reloadData];
	
	for (SPBrowserItem* expandedItem in [savedState expandedFolderItems])
		[browserView expandItem:expandedItem];

	BOOL firstItem = YES;
	for (SPBrowserItem* selectedItem in [savedState selectedItems])
	{
		NSInteger row = [browserView rowForItem:selectedItem];
		[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:firstItem ? NO : YES];

		firstItem = NO;
	}
					
	savedState = nil;
	
	return YES;
}


#pragma mark -
#pragma mark searching and spotlight methods


// ----------------------------------------------------------------------------
- (void) searchInPlaylist:(NSString*)searchString
// ----------------------------------------------------------------------------
{
	NSMutableArray* playlistItemsMatchingSearchString = [NSMutableArray arrayWithCapacity:[rootItems count]];

	if (unfilteredPlaylistItems == nil)
		unfilteredPlaylistItems = [rootItems mutableCopy];

	if ([searchString length] == 0)
	{
		rootItems = unfilteredPlaylistItems;
		unfilteredPlaylistItems = nil;
		[browserView reloadData];
		[self enableSpotlightSearchTypeSubView:NO];
		return;
	}

	[self enableSpotlightSearchTypeSubView:YES];

	NSRange range;
	BOOL match = NO;
	for (SPBrowserItem* item in unfilteredPlaylistItems)
	{
		match = NO;
		switch (gPreferences.mSearchType)
		{
			case SEARCH_ALL:
				range = [[item title] rangeOfString:searchString options:NSCaseInsensitiveSearch];
				match = range.location != NSNotFound;
				if (!match)
				{
					range = [[item author] rangeOfString:searchString options:NSCaseInsensitiveSearch];
					match = range.location != NSNotFound;
					if (!match)
					{
						range = [[item releaseInfo] rangeOfString:searchString options:NSCaseInsensitiveSearch];
						match = range.location != NSNotFound;
						if (!match)
						{	
							range = [[item path] rangeOfString:searchString options:NSCaseInsensitiveSearch];
							match = range.location != NSNotFound;
						}
					}
				}
				break;
			case SEARCH_TITLE:
				range = [[item title] rangeOfString:searchString options:NSCaseInsensitiveSearch];
				match = range.location != NSNotFound;
				break;
			case SEARCH_AUTHOR:
				range = [[item author] rangeOfString:searchString options:NSCaseInsensitiveSearch];
				match = range.location != NSNotFound;
				break;
			case SEARCH_RELEASED:
				range = [[item releaseInfo] rangeOfString:searchString options:NSCaseInsensitiveSearch];
				match = range.location != NSNotFound;
				break;
			case SEARCH_FILENAME:
				range = [[item path] rangeOfString:searchString options:NSCaseInsensitiveSearch];
				match = range.location != NSNotFound;
				break;
		}
	
		if (match)
			[playlistItemsMatchingSearchString addObject:item];
	}
	
	[rootItems removeAllObjects];
	[rootItems addObjectsFromArray:playlistItemsMatchingSearchString];
	[browserView reloadData];
}


// ----------------------------------------------------------------------------
- (IBAction) searchStringEntered:(id)sender
// ----------------------------------------------------------------------------
{
	if (rootPath == nil)
		return;
    // if window is to small for toolbar we would raise an exception
    // with [sender stringValue], so we check for NSTextField here
    // (if hidden, it is a NSMenuitem)
    if (![sender isKindOfClass:[NSTextField class]])
        return;
    
	NSString* searchString = [sender stringValue];

	if (browserMode == BROWSER_MODE_PLAYLIST || browserMode == BROWSER_MODE_SHARED_PLAYLIST || 
		browserMode == BROWSER_MODE_SMART_PLAYLIST || browserMode == BROWSER_MODE_SHARED_SMART_PLAYLIST)
	{
		[self searchInPlaylist:searchString];
		return;
	}

	if ([searchString length] == 0)
	{
		[self switchToPath:currentPath];
		return;
	}
		
	[self setBrowserMode:BROWSER_MODE_SPOTLIGHT_RESULT];
	
	[self saveBrowserState];
		
	[rootItems removeAllObjects];
	[browserView reloadData];
	[self enableSpotlightSearchTypeSubView:YES];

	[searchQuery stopQuery]; 
	
	if ([searchString length] < 3)
		return;

	NSString *likeSearchString = [NSString stringWithFormat:@"*%@*", searchString];
	NSString *predicateFormat = nil;
    currentSearchPredicate = nil;

	switch (gPreferences.mSearchType)
	{
		case SEARCH_ALL:
			predicateFormat = @"(kMDItemContentType == 'org.sidmusic.sidtune') && ((kMDItemTitle LIKE[cd] %@) || (kMDItemComposer LIKE[cd] %@) || (org_sidmusic_Released LIKE[cd] %@) || (kMDItemFSName LIKE[cd] %@))";
			currentSearchPredicate = [NSPredicate predicateWithFormat:predicateFormat, likeSearchString, likeSearchString, likeSearchString, likeSearchString, likeSearchString];
			break;
		case SEARCH_TITLE:
			predicateFormat = @"(kMDItemContentType == 'org.sidmusic.sidtune') && (kMDItemTitle LIKE[cd] %@)";
			currentSearchPredicate = [NSPredicate predicateWithFormat:predicateFormat, likeSearchString];
			break;
		case SEARCH_AUTHOR:
			predicateFormat = @"(kMDItemContentType == 'org.sidmusic.sidtune') && (kMDItemComposer LIKE[cd] %@)";
			currentSearchPredicate = [NSPredicate predicateWithFormat:predicateFormat, likeSearchString];
			break;
		case SEARCH_RELEASED:
			predicateFormat = @"(kMDItemContentType == 'org.sidmusic.sidtune') && (org_sidmusic_Released LIKE[cd] %@)";
			currentSearchPredicate = [NSPredicate predicateWithFormat:predicateFormat, likeSearchString];
			break;
		case SEARCH_FILENAME:
			predicateFormat = @"(kMDItemContentType == 'org.sidmusic.sidtune') && (kMDItemFSName LIKE[cd] %@)";
			currentSearchPredicate = [NSPredicate predicateWithFormat:predicateFormat, likeSearchString];
			break;
	}
	
    [searchQuery setPredicate:currentSearchPredicate];
	[searchQuery setSearchScopes:[NSArray arrayWithObject:limitSpotlightScopeToCurrentFolder ? currentPath : rootPath]];
    [searchQuery startQuery]; 
	
	[self setInProgress:YES];
}


// ----------------------------------------------------------------------------
- (IBAction) searchTypeChanged:(id)sender
// ----------------------------------------------------------------------------
{
	gPreferences.mSearchType = (SPSearchType) [sender tag];
	[self searchStringEntered:toolbarSearchField];
	[self adjustSearchTypeControlsAndMenu];
}


// ----------------------------------------------------------------------------
- (IBAction) searchTypeChangedViaButtons:(id)sender
// ----------------------------------------------------------------------------
{
	gPreferences.mSearchType = (SPSearchType) ([sender tag] - 10);
	[self searchStringEntered:toolbarSearchField];
	[self adjustSearchTypeControlsAndMenu];
}


// ----------------------------------------------------------------------------
- (void) adjustSearchTypeControlsAndMenu
// ----------------------------------------------------------------------------
{
	// set the search field menu to show the currently selected search type
	NSArray* menuItems = [toolbarSearchFieldMenu itemArray];
	for (id menuItem in menuItems)
	{
		[menuItem setState:NSOffState];

		if ([menuItem tag] == (NSInteger)gPreferences.mSearchType)
		{
			[menuItem setState:NSOnState];
			if (gPreferences.mSearchType == SEARCH_ALL)
				[[toolbarSearchField cell] setPlaceholderString:@"Search"];
			else
				[[toolbarSearchField cell] setPlaceholderString:[NSString stringWithFormat:@"%@ Search", [menuItem title]]];
		}
	}

	[[toolbarSearchField cell] setSearchMenuTemplate:toolbarSearchFieldMenu];

	NSArray* searchTypeBoxButtons = [[spotlightSearchTypeSubView contentView] subviews];
	for (id button in searchTypeBoxButtons)
	{
		if ([button tag] == (gPreferences.mSearchType + 10))
			[button setState:NSOnState];
		else if ([button tag] >= 10 && [button tag] < 20)
			[button setState:NSOffState];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) searchScopeChanged:(id)sender
// ----------------------------------------------------------------------------
{
	int activeTag = 0;
	int inactiveTag = 0;
	
	if ([sender tag] == 100)
	{
		// Set scope to "full collection"
		limitSpotlightScopeToCurrentFolder = NO;
		activeTag = 100;
		inactiveTag = 200;
	}
	else if ([sender tag] == 200)
	{
		// Set scope to "current folder"
		limitSpotlightScopeToCurrentFolder = YES;
		activeTag = 200;
		inactiveTag = 100;
	}

	NSArray* searchTypeBoxButtons = [[spotlightSearchTypeSubView contentView] subviews];
	for (id button in searchTypeBoxButtons)
	{
		if ([button tag] == activeTag)
			[button setState:NSOnState];
		else if ([button tag] == inactiveTag)
			[button setState:NSOffState];
	}

	[self searchStringEntered:toolbarSearchField];
}


// ----------------------------------------------------------------------------
- (void) stopSearchAndClearSearchString
// ----------------------------------------------------------------------------
{
	[searchQuery stopQuery];
	[toolbarSearchField setStringValue:@""];
	[self enableSpotlightSearchTypeSubView:NO];
	unfilteredPlaylistItems = nil;
	currentSearchPredicate = nil;
}


// ----------------------------------------------------------------------------
- (void) searchQueryNotification:(NSNotification *)notification
// ----------------------------------------------------------------------------
{
    if ([[notification name] isEqualToString:NSMetadataQueryDidStartGatheringNotification])
	{

    }
	else if ([[notification name] isEqualToString:NSMetadataQueryDidFinishGatheringNotification])
	{
		NSArray* results = [searchQuery results];
		[rootItems removeAllObjects];
		[SPBrowserItem fillArray:rootItems withMetaDataQueryResults:results];
		[rootItems sortUsingDescriptors:[browserView sortDescriptors]];
		[browserView reloadData];
		[self setInProgress:NO];

		[searchQuery enableUpdates];
    }
	else if ([[notification name] isEqualToString:NSMetadataQueryGatheringProgressNotification])
	{

    }
	else if ([[notification name] isEqualToString:NSMetadataQueryDidUpdateNotification])
	{
		[self setInProgress:YES];
		NSArray* results = [searchQuery results];
		[rootItems removeAllObjects];
		[SPBrowserItem fillArray:rootItems withMetaDataQueryResults:results];
		[rootItems sortUsingDescriptors:[browserView sortDescriptors]];
		[browserView reloadData];
		[self setInProgress:NO];
    }
}



// ----------------------------------------------------------------------------
- (void) playRandomTuneFromSearchResults
// ----------------------------------------------------------------------------
{
    if (browserMode != BROWSER_MODE_SPOTLIGHT_RESULT)
        return;
    
    int currentItemIndex = (int)[browserView rowForItem:currentItem];
    if (currentItemIndex == -1)
        currentItemIndex = 0;
    else
        currentItemIndex = (int)(random() % [rootItems count]);
    
    SPBrowserItem* item = [rootItems objectAtIndex:currentItemIndex];
    if (item != nil)
    {
        [self playItem:item];
        int row = (int)[browserView rowForItem:currentItem];
        [browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [browserView scrollRowToVisible:row];
    }
}


// ----------------------------------------------------------------------------
- (void) smartPlaylistUpdatedNotification:(NSNotification *)notification
// ----------------------------------------------------------------------------
{
	SPSmartPlaylist* smartPlaylist = [notification object];
	if (smartPlaylist == playlist)
	{
		[self setInProgress:YES];
		[rootItems removeAllObjects];
		[self stopSearchAndClearSearchString];
		[SPBrowserItem fillArray:rootItems withPlaylist:playlist];
		[rootItems sortUsingDescriptors:[browserView sortDescriptors]];
		[browserView reloadData];
		[self updatePathControlForPlaylistMode:NO];
		[self setInProgress:NO];
		
		//[sourceListDataSource bumpUpdateRevision];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) saveCurrentSearchAsSmartPlaylist:(id)sender
// ----------------------------------------------------------------------------
{
	if (currentSearchPredicate == nil)
		return;
		
	NSPredicate* originalPredicate = currentSearchPredicate;
	NSPredicate* newPredicate = nil;
	
	// Clean the predicate, exchange LIKE for CONTAINS, remove content type clause and trim *s from string
	if ([originalPredicate isKindOfClass:[NSCompoundPredicate class]])
	{
		NSArray* subPredicates = [(NSCompoundPredicate*)originalPredicate subpredicates];
		NSMutableArray* newSubPredicates = [NSMutableArray arrayWithCapacity:[subPredicates count]];
		for (NSPredicate* subPredicate in subPredicates)
		{
			if ([subPredicate isKindOfClass:[NSComparisonPredicate class]])
			{
				NSComparisonPredicate* comparisonPredicate = (NSComparisonPredicate*) subPredicate;
				NSExpression* leftExpression = [comparisonPredicate leftExpression];
				NSExpression* rightExpression = [comparisonPredicate rightExpression];
				
				if ([leftExpression expressionType] == NSKeyPathExpressionType)
				{
					NSString* keyPath = [leftExpression keyPath];
					if ([keyPath isEqualToString:@"kMDItemContentType"])
						continue;

					if ([rightExpression expressionType] == NSConstantValueExpressionType)
					{
						NSString* searchString = [rightExpression constantValue];
						searchString = [searchString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"*"]];
					
						NSPredicateOperatorType operatorType = [comparisonPredicate predicateOperatorType];
						if (operatorType == NSLikePredicateOperatorType)
							operatorType = NSContainsPredicateOperatorType;

						NSExpression* newRightExpression = [NSExpression expressionForConstantValue:searchString];
						NSPredicate* newSubPredicate = [NSComparisonPredicate predicateWithLeftExpression:leftExpression
																						  rightExpression:newRightExpression
																								 modifier:[comparisonPredicate comparisonPredicateModifier]
																									 type:operatorType
																								  options:[comparisonPredicate options]];
						[newSubPredicates addObject:newSubPredicate];
					}
				}
			}
		}

		NSCompoundPredicateType type = [(NSCompoundPredicate*)originalPredicate compoundPredicateType];
		newPredicate = [[NSCompoundPredicate alloc] initWithType:type subpredicates:newSubPredicates];
	}
	else
		newPredicate = originalPredicate;

	//NSLog(@"cleaned predicate: %@\n", newPredicate);

	NSString* name = [toolbarSearchField stringValue];

	SPSmartPlaylist* smartPlaylist = [[SPSmartPlaylist alloc] init];
	[smartPlaylist setName:name];
	[smartPlaylist setPredicate:newPredicate];
	[smartPlaylist startSpotlightQuery:[[SPCollectionUtilities sharedInstance] rootPath]];
	[smartPlaylist saveToFile];
	
	[sourceListDataSource addSavedSearchSmartPlaylist:smartPlaylist];
}


// ----------------------------------------------------------------------------
- (void) setInProgress:(BOOL)active
// ----------------------------------------------------------------------------
{
	NSProgressIndicator* indicator = spotlightSearchTypeSubViewVisible ? searchTypeProgressIndicator : progressIndicator;
	NSProgressIndicator* otherIndicator = spotlightSearchTypeSubViewVisible ? progressIndicator : searchTypeProgressIndicator;
	
	if (active)
	{
		[indicator setHidden:NO];
		[indicator startAnimation:self];
	}
	else
	{
		[indicator setHidden:YES];
		[indicator stopAnimation:self];
	}

	[otherIndicator setHidden:YES];
	[otherIndicator stopAnimation:self];
}


// ----------------------------------------------------------------------------
- (void) setCurrentItem:(SPBrowserItem*)item;
// ----------------------------------------------------------------------------
{
	currentItem = item;
}


// ----------------------------------------------------------------------------
- (NSArray*) draggedItems
// ----------------------------------------------------------------------------
{
	return draggedItems;
}


// ----------------------------------------------------------------------------
- (NSSearchField*) toolbarSearchField
// ----------------------------------------------------------------------------
{
	return toolbarSearchField;
}


// ----------------------------------------------------------------------------
- (BOOL) isSmartPlaylist
// ----------------------------------------------------------------------------
{
	return browserMode == BROWSER_MODE_SMART_PLAYLIST;

}


// ----------------------------------------------------------------------------
- (BOOL) isSpotlightResult
// ----------------------------------------------------------------------------
{
	return browserMode == BROWSER_MODE_SPOTLIGHT_RESULT;
}


// ----------------------------------------------------------------------------
- (BOOL) isSharedCollection
// ----------------------------------------------------------------------------
{
	return browserMode == BROWSER_MODE_SHARED_COLLECTION;
}


// ----------------------------------------------------------------------------
- (BOOL) isSharedPlaylist
// ----------------------------------------------------------------------------
{
	return browserMode == BROWSER_MODE_SHARED_PLAYLIST;
}


// ----------------------------------------------------------------------------
- (BOOL) isSharedSmartPlaylist
// ----------------------------------------------------------------------------
{
	return browserMode == BROWSER_MODE_SHARED_SMART_PLAYLIST;
}


// ----------------------------------------------------------------------------
- (BrowserMode) browserMode
// ----------------------------------------------------------------------------
{
	return browserMode;
}


// ----------------------------------------------------------------------------
- (void) setBrowserMode:(BrowserMode)mode
// ----------------------------------------------------------------------------
{
	browserMode = mode;
	
	switch (browserMode)
	{
		case BROWSER_MODE_COLLECTION:
			[self setPlaylistModeBrowserColumns:NO];
			[toolbarSearchField setEnabled:YES];
			[tableColumns[COLUMN_TIME] setHidden:NO];
			break;
		case BROWSER_MODE_SPOTLIGHT_RESULT:
			[self setPlaylistModeBrowserColumns:NO];
			[toolbarSearchField setEnabled:YES];
			[tableColumns[COLUMN_TIME] setHidden:NO];
			break;
		case BROWSER_MODE_SHARED_COLLECTION:
			[self setPlaylistModeBrowserColumns:NO];
			[toolbarSearchField setEnabled:NO];
			[tableColumns[COLUMN_TIME] setHidden:NO];
			break;
		case BROWSER_MODE_PLAYLIST:
		case BROWSER_MODE_SMART_PLAYLIST:
			[self setPlaylistModeBrowserColumns:YES];
			[toolbarSearchField setEnabled:YES];
			[tableColumns[COLUMN_TIME] setHidden:NO];
			break;
		case BROWSER_MODE_SHARED_PLAYLIST:
		case BROWSER_MODE_SHARED_SMART_PLAYLIST:
			[self setPlaylistModeBrowserColumns:YES];
			[toolbarSearchField setEnabled:YES];
			[tableColumns[COLUMN_TIME] setHidden:NO];
	}
}


// ----------------------------------------------------------------------------
- (void) findMissingPlaylistFileOfItem:(SPBrowserItem*)missingItem
// ----------------------------------------------------------------------------
{
	if (missingItem == nil)
		return;
		
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	NSArray* fileTypes = [NSArray arrayWithObject:@"sid"];
	
	NSString* directory = [[missingItem path] stringByDeletingLastPathComponent];
	BOOL isFolder = NO;
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:directory isDirectory:&isFolder];
	if (!exists || !isFolder)
		directory = nil;
		
	[openPanel beginSheetForDirectory:directory file:nil types:fileTypes modalForWindow:[browserView window] modalDelegate:self didEndSelector:@selector(didEndMissingFileSheet:returnCode:contextInfo:) contextInfo:(void*)missingItem];
}


// ----------------------------------------------------------------------------
- (void)didEndMissingFileSheet:(NSOpenPanel*)openPanel returnCode:(int)returnCode contextInfo:(void*)contextInfo
// ----------------------------------------------------------------------------
{
	if (returnCode == NSOKButton)
	{
        NSArray *filesToOpen = [openPanel filenames];
        NSString* file = [filesToOpen objectAtIndex:0];
		
		SPBrowserItem* missingItem = (__bridge SPBrowserItem*) contextInfo;
		int playlistIndex = (int)[missingItem playlistIndex];
		if (playlist != nil)
		{
			SPPlaylistItem* playlistItem = [playlist itemAtIndex:playlistIndex];
			if (playlistItem != nil)
			{
				NSString* relativePath = [[SPCollectionUtilities sharedInstance] makePathRelativeToCollectionRoot:file];
				if (relativePath != nil)
				{
					[playlistItem setPath:relativePath];
					[playlist saveToFile];
					[self switchToPlaylist:playlist];
				}
			}
		}
    }	
}


// ----------------------------------------------------------------------------
- (BOOL) playSelectedItem
// ----------------------------------------------------------------------------
{
	NSIndexSet* set = [browserView selectedRowIndexes];
	if ([set count] > 0)
	{
		SPBrowserItem* item = [browserView itemAtRow:[set firstIndex]];
		if (item != nil && ![item isFolder])
		{
			[browserView activateItem:item];
			return YES;
		}
	}
	
	return NO;
}


// ----------------------------------------------------------------------------
- (void) shufflePlaylist
// ----------------------------------------------------------------------------
{
    shuffledPlaylistItems = [rootItems mutableCopy];
    for (int i = 0; i < [shuffledPlaylistItems count]; i++)
    {
        int random_index = (arc4random() % ([shuffledPlaylistItems count] - i)) + i;
        [shuffledPlaylistItems exchangeObjectAtIndex:i withObjectAtIndex:random_index];
    }
    currentShuffleIndex = 0;
}


#pragma mark -
#pragma mark UI actions

// ----------------------------------------------------------------------------
- (IBAction) tableColumnStatusChanged:(id)sender
// ----------------------------------------------------------------------------
{
    if (sender)
    {
		ColumnType columnType = (ColumnType) [sender tag];
		NSTableColumn* column = tableColumns[columnType];
		
		if ([sender state] == NSOffState)
		{
			[sender setState:NSOnState];
			[column setHidden:NO];
		}
		else if ([sender state] == NSOnState)
		{
			[sender setState:NSOffState];
			[column setHidden:YES];
		}
	}
}


// ----------------------------------------------------------------------------
- (IBAction) playNextPlaylistItem:(id)sender
// ----------------------------------------------------------------------------
{
	if (playlist == nil)
		return;
		
	if (currentItem == nil)
		return;
		
	if ([rootItems count] == 0)
		return;

	if ([rootItems count] != [playlist count])
		return;
	
	BOOL playNextItem = YES;
    SPBrowserItem* item = nil;
    
    if (gPreferences.mShuffleActive)
    {
        item = [shuffledPlaylistItems objectAtIndex:currentShuffleIndex];
        currentShuffleIndex = (currentShuffleIndex + 1) % [shuffledPlaylistItems count];
//        if (currentShuffleIndex == 0)
//            [self shufflePlaylist];
    }
    else
    {
        int currentItemIndex = (int) [browserView rowForItem:currentItem];
        if (currentItemIndex == -1)
            currentItemIndex = 0;
        else
        {
            BOOL isLastItem = currentItemIndex == ([rootItems count] - 1);
            
            if (!gPreferences.mRepeatActive && isLastItem)
            {
                SPPlayerWindow* window = (SPPlayerWindow*) [browserView window];
                [window clickStopButton:nil];
                playNextItem = NO;
            }
            else
                currentItemIndex = (currentItemIndex + 1) % [rootItems count];
        }
        
        item = [rootItems objectAtIndex:currentItemIndex];
    }

	if (item != nil && playNextItem)
	{
		[self playItem:item];
		int row = (int)[browserView rowForItem:currentItem];
		[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[browserView scrollRowToVisible:row];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) playPreviousPlaylistItem:(id)sender
// ----------------------------------------------------------------------------
{
	if (playlist == nil)
		return;

	if (currentItem == nil)
		return;
		
	if ([rootItems count] == 0)
		return;
	
    SPBrowserItem* item = nil;

    if (gPreferences.mShuffleActive)
    {
        currentShuffleIndex--;
        if (currentShuffleIndex == -1)
            currentShuffleIndex = (int)[shuffledPlaylistItems count] - 1;

        item = [shuffledPlaylistItems objectAtIndex:currentShuffleIndex];
    }
    else
    {
        int currentItemIndex = (int)[browserView rowForItem:currentItem];
        if (currentItemIndex == -1)
            currentItemIndex = 0;
        else
        {
            currentItemIndex--;
            if (currentItemIndex == -1)
                currentItemIndex = (int)[rootItems count] - 1;
        }
        
        item = [rootItems objectAtIndex:currentItemIndex];
    }
    
	if (item != nil)
	{
		[self playItem:item];
		int row = (int)[browserView rowForItem:currentItem];
		[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[browserView scrollRowToVisible:row];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) showCurrentItem:(id)sender
// ----------------------------------------------------------------------------
{
	if (currentItem == nil)
		return;
		
	int row = (int)[browserView rowForItem:currentItem];
	if (row != -1)
	{
		[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[browserView scrollRowToVisible:row];
	}
	else
		[self browseToFile:[currentItem path] andSetAsCurrentItem:YES];
}


// ----------------------------------------------------------------------------
- (IBAction) revealSelectedItemInBrowser:(id)sender
// ----------------------------------------------------------------------------
{
	NSIndexSet* set = [browserView selectedRowIndexes];
	if ([set count] == 1)
	{
		SPBrowserItem* item = [browserView itemAtRow:[set firstIndex]];
		if (item != nil)
			[self browseToFile:[item path] andSetAsCurrentItem:NO];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) revealSelectedItemInFinder:(id)sender
// ----------------------------------------------------------------------------
{
	NSIndexSet* set = [browserView selectedRowIndexes];
	if ([set count] == 1)
	{
		SPBrowserItem* item = [browserView itemAtRow:[set firstIndex]];
		if (item != nil)
		{
			NSWorkspace *workSpace = [NSWorkspace sharedWorkspace];
			[workSpace selectFile:[item path] inFileViewerRootedAtPath:@""];
		}
	}
}


// ----------------------------------------------------------------------------
- (IBAction) copyPathOfSelectedItemToClipboard:(id)sender
// ----------------------------------------------------------------------------
{
	NSString* result = @"";
	NSIndexSet* set = [browserView selectedRowIndexes];
	NSUInteger index = [set firstIndex];
	if ([set count] == 1)
	{
		SPBrowserItem* item = [browserView itemAtRow:index];
		if (item != nil)
			result = [item path];
	}
	else
	{
		while (index != NSNotFound)
		{
			SPBrowserItem* item = [browserView itemAtRow:index];
			if (item != nil)
				result = [result stringByAppendingFormat:@"%@\n", [item path]];
		
			index = [set indexGreaterThanIndex:index];
		}
	}

	NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
	NSArray* types = [NSArray arrayWithObjects:NSStringPboardType, nil];
	[pasteboard declareTypes:types owner:self];
	[pasteboard setString:result forType:NSStringPboardType];
}


// ----------------------------------------------------------------------------
- (IBAction) copyRelativePathOfSelectedItemToClipboard:(id)sender
// ----------------------------------------------------------------------------
{
	NSString* result = @"";
	NSIndexSet* set = [browserView selectedRowIndexes];
	NSUInteger index = [set firstIndex];
	if ([set count] == 1)
	{
		SPBrowserItem* item = [browserView itemAtRow:index];
		if (item != nil)
		{
			NSString* relativePath = [[SPCollectionUtilities sharedInstance] makePathRelativeToCollectionRoot:[item path]];
			result = relativePath;
		}
	}
	else
	{
		while (index != NSNotFound)
		{
			SPBrowserItem* item = [browserView itemAtRow:index];
			if (item != nil)
			{
				NSString* relativePath = [[SPCollectionUtilities sharedInstance] makePathRelativeToCollectionRoot:[item path]];
				result = [result stringByAppendingFormat:@"%@\n", relativePath];
			}
		
			index = [set indexGreaterThanIndex:index];
		}
	}

	NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
	NSArray* types = [NSArray arrayWithObjects:NSStringPboardType, nil];
	[pasteboard declareTypes:types owner:self];
	[pasteboard setString:result forType:NSStringPboardType];
}


// ----------------------------------------------------------------------------
- (IBAction) deleteSelectedItems:(id)sender
// ----------------------------------------------------------------------------
{
	if (browserMode == BROWSER_MODE_SMART_PLAYLIST || browserMode == BROWSER_MODE_SHARED_SMART_PLAYLIST)
		return;
		
	SPSimplePlaylist* simplePlaylist = (SPSimplePlaylist*) playlist;
	NSIndexSet* selectedRowIndices = [browserView selectedRowIndexes];
	NSMutableIndexSet* selectedPlaylistIndices = [[NSMutableIndexSet alloc] init];
	
	NSUInteger index = [selectedRowIndices firstIndex];
	while (index != NSNotFound)
	{
		[browserView deselectRow:index];

		SPBrowserItem* item = [browserView itemAtRow:index];
		if (item != nil)
			[selectedPlaylistIndices addIndex:[item playlistIndex]];
		
		index = [selectedRowIndices indexGreaterThanIndex:index];
	}
	
	[simplePlaylist removeItemsAtIndices:selectedPlaylistIndices];
	[simplePlaylist saveToFile];

	[rootItems removeAllObjects];
	[SPBrowserItem fillArray:rootItems withPlaylist:playlist];
	[rootItems sortUsingDescriptors:[browserView sortDescriptors]];
	[browserView reloadData];
	[self updatePathControlForPlaylistMode:NO];
}


// ----------------------------------------------------------------------------
- (IBAction) exportSelectedItems:(id)sender
// ----------------------------------------------------------------------------
{
	ExportFileType type = (ExportFileType) [sender tag];
	SPPlayerWindow* window = (SPPlayerWindow*) [browserView window];
	SPExportController* exportController = [window exportController];

	NSIndexSet* set = [browserView selectedRowIndexes];
	NSUInteger index = [set firstIndex];
	if ([set count] == 1)
	{
		SPBrowserItem* item = [browserView itemAtRow:index];
		SPExportItem* exportItem = [[SPExportItem alloc] initWithPath:[item path] andTitle:[item title] andAuthor:[item author] andSubtune:[item defaultSubTune] andLoopCount:(int)[item loopCount]];

		[exportController exportFile:exportItem withType:type];
	}
	else if ([set count] > 1)
	{
		NSMutableArray* exportItems = [NSMutableArray arrayWithCapacity:[set count]];
		while (index != NSNotFound)
		{
			SPBrowserItem* item = [browserView itemAtRow:index];
			if (item != nil && ![item isFolder])
			{
				SPExportItem* exportItem = [[SPExportItem alloc] initWithPath:[item path] andTitle:[item title] andAuthor:[item author] andSubtune:[item defaultSubTune] andLoopCount:(int)[item loopCount]];
				[exportItems addObject:exportItem];
			}

			index = [set indexGreaterThanIndex:index];
		}

		if ([exportItems count] > 0)
			[exportController exportFiles:exportItems withType:type];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) findRemixesOfSelectedItem:(id)sender
// ----------------------------------------------------------------------------
{
	SPPlayerWindow* window = (SPPlayerWindow*) [browserView window];
	SPRemixKwedOrgController* remixKwedOrgController = [window remixKwedOrgController];

	NSIndexSet* set = [browserView selectedRowIndexes];
	NSUInteger index = [set firstIndex];
	if ([set count] == 1)
	{
		SPBrowserItem* item = [browserView itemAtRow:index];
		if (item != nil)
		{
			NSString* relativePath = [[SPCollectionUtilities sharedInstance] makePathRelativeToCollectionRoot:[item path]];
			[remixKwedOrgController findRemixesForHvscPath:relativePath withTitle:[item title]];
		}
	}
}


// ----------------------------------------------------------------------------
- (IBAction) clickPlaybackModeControl:(id)sender
// ----------------------------------------------------------------------------
{
	NSInteger clickedSegment = [sender selectedSegment];
	NSInteger clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment]; 
	
	switch (clickedSegmentTag)
	{
		case 0:
			gPreferences.mFadeActive = !gPreferences.mFadeActive;
			break;

		case 1:
			gPreferences.mRepeatActive = !gPreferences.mRepeatActive;
			break;

		case 2:
			gPreferences.mShuffleActive = !gPreferences.mShuffleActive;
            if (gPreferences.mShuffleActive && playlist != nil)
                [self shufflePlaylist];
			break;
	}

	[self setPlaybackModeControlImages];
}


static NSImage* SPFadeButtonPressedImage = nil;
static NSImage* SPFadeButtonImage = nil;
static NSImage* SPRepeatButtonPressedImage = nil;
static NSImage* SPRepeatButtonImage = nil;
static NSImage* SPShuffleButtonPressedImage = nil;
static NSImage* SPShuffleButtonImage = nil;


// ----------------------------------------------------------------------------
- (void) setPlaybackModeControlImages
// ----------------------------------------------------------------------------
{
	if (SPFadeButtonPressedImage == nil)
	{
		SPFadeButtonPressedImage = [NSImage imageNamed:@"fade_pressed"];
		SPFadeButtonImage = [NSImage imageNamed:@"fade"];
		SPRepeatButtonPressedImage = [NSImage imageNamed:@"repeat_button_pressed"];
		SPRepeatButtonImage = [NSImage imageNamed:@"repeat_button"];
		SPShuffleButtonPressedImage = [NSImage imageNamed:@"shuffle_pressed"];
		SPShuffleButtonImage = [NSImage imageNamed:@"shuffle"];
	}

	[browserPlaybackModeControl setImage:(gPreferences.mFadeActive ? SPFadeButtonPressedImage : SPFadeButtonImage) forSegment:0];
	[browserPlaybackModeControl setImage:(gPreferences.mRepeatActive ? SPRepeatButtonPressedImage : SPRepeatButtonImage) forSegment:1];
	[browserPlaybackModeControl setImage:(gPreferences.mShuffleActive ? SPShuffleButtonPressedImage : SPShuffleButtonImage) forSegment:2];
}


#pragma mark -
#pragma mark data source methods


// ----------------------------------------------------------------------------
- (int) outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item 
// ----------------------------------------------------------------------------
{
    if (item == nil)
		return (int)[rootItems count];
	else
	{
		[self setInProgress:YES];
		int count = (int)[[item children] count];
        [[(SPBrowserItem*)item children] sortUsingDescriptors:[outlineView sortDescriptors]];
        [self setInProgress:NO];
		return count;
	}
}


// ----------------------------------------------------------------------------
- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item 
// ----------------------------------------------------------------------------
{
	return [item isFolder];
}


// ----------------------------------------------------------------------------
- (id) outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item 
// ----------------------------------------------------------------------------
{
	if (item == nil)
		return [rootItems objectAtIndex:index];
	else
		return [(SPBrowserItem *)item childAtIndex:index];
}


// ----------------------------------------------------------------------------
- (void) outlineView:(NSOutlineView *)outlineView sortDescriptorsDidChange:(NSArray *)oldDescriptors
// ----------------------------------------------------------------------------
{
	NSMutableArray* selectedItems = [[NSMutableArray alloc] init];
	NSIndexSet* selectedIndices = [browserView selectedRowIndexes];
	NSUInteger index = [selectedIndices firstIndex];
    while (index != NSNotFound)
	{
		[browserView deselectRow:index];

		SPBrowserItem* item = [browserView itemAtRow:index];
		if (item != nil)
			[selectedItems addObject:item];
		
		index = [selectedIndices indexGreaterThanIndex:index];
	}
	
	[rootItems sortUsingDescriptors:[outlineView sortDescriptors]];
	[outlineView reloadData];
	
	for (SPBrowserItem* item in selectedItems)
	{
		int row = (int)[browserView rowForItem:item];
		if (row != -1)
			[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:YES];
	}
}


// ----------------------------------------------------------------------------
- (id) outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item 
// ----------------------------------------------------------------------------
{
    SPBrowserItem* browserItem = (SPBrowserItem*)item;
    
	if (browserItem == nil)
		return @"no item";
		
	if([[tableColumn identifier] isEqual:@"index"])
    {
		return [NSString stringWithFormat:@"%ld", ([browserItem playlistIndex] + 1)];
    }
	else if([[tableColumn identifier] isEqual:@"title"])
	{
		return [browserItem title];
	}
	else if([[tableColumn identifier] isEqual:@"author"])
	{
		return [browserItem author];
	}
	else if([[tableColumn identifier] isEqual:@"released"])
	{
		return [browserItem releaseInfo];
	}
	else if([[tableColumn identifier] isEqual:@"path"])
	{
		return [browserItem path];
	}
	else if([[tableColumn identifier] isEqual:@"subtune"])
	{
		return [NSString stringWithFormat:@"%d", [browserItem defaultSubTune]];
	}
	else if([[tableColumn identifier] isEqual:@"time"])
	{
		if ([browserItem isFolder])
			return @"";
		else
			return [NSString stringWithFormat:@"%d:%02d", [browserItem playTimeMinutes], [browserItem playTimeSeconds]];
	}
	else if([[tableColumn identifier] isEqual:@"repeat"])
    {
		NSInteger loopCount = [browserItem loopCount];
		if (loopCount == 0)
			return @"∞";
		else
			return [NSString stringWithFormat:@"%ld", (long)loopCount];
    }
	else
	{
		return nil;
	}
}


// ----------------------------------------------------------------------------
- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
// ----------------------------------------------------------------------------
{
	if (item == nil)
		return;

	if (browserMode == BROWSER_MODE_SMART_PLAYLIST || browserMode == BROWSER_MODE_SHARED_PLAYLIST || browserMode == BROWSER_MODE_SHARED_SMART_PLAYLIST )
		return;
	
	SPBrowserItem* browserItem = (SPBrowserItem*) item;
	NSString* string = (NSString*) object;
	
	if ([[tableColumn identifier] isEqual:@"subtune"])
	{
		NSInteger defaultSubtune = [string integerValue];
		if (defaultSubtune > 0 && defaultSubtune <= [browserItem subTuneCount] && playlist != nil)
		{
			[browserItem setDefaultSubTune:defaultSubtune];
			int playtime = [[SongLengthDatabase sharedInstance] getSongLengthByPath:[browserItem path] andSubtune:(int)defaultSubtune];
			[browserItem setPlayTimeInSeconds:playtime];

			NSInteger playlistIndex = [browserItem playlistIndex];
			SPPlaylistItem* playlistItem = [playlist itemAtIndex:playlistIndex];
			[playlistItem setSubtune:defaultSubtune];
			
			[browserView reloadData];
			[playlist saveToFile];
		}
	}
	else if ([[tableColumn identifier] isEqual:@"repeat"])
	{
		NSInteger loopCount = [string integerValue];
		if (loopCount >= 0)
		{
			[browserItem setLoopCount:loopCount];
			NSInteger playlistIndex = [browserItem playlistIndex];
			SPPlaylistItem* playlistItem = [playlist itemAtIndex:playlistIndex];
			[playlistItem setLoopCount:loopCount];
			[browserView reloadData];
			[playlist saveToFile];
		}
	}
	else if ([[tableColumn identifier] isEqual:@"path"])
	{
		NSInteger index = [rootItems indexOfObject:browserItem];
		if (index != -1)
		{
			NSInteger playlistIndex = [browserItem playlistIndex];
			SPBrowserItem* newBrowserItem = [[SPBrowserItem alloc] initWithPath:string isFolder:NO forParent:nil withDefaultSubtune:0];
			[newBrowserItem setPlaylistIndex:playlistIndex];
			[newBrowserItem setLoopCount:1];
			[rootItems replaceObjectAtIndex:index withObject:newBrowserItem];

			SPPlaylistItem* playlistItem = [playlist itemAtIndex:playlistIndex];
			NSString* relativePath = [[SPCollectionUtilities sharedInstance] makePathRelativeToCollectionRoot:string];
			[playlistItem setPath:relativePath];
			[browserView reloadData];
			[playlist saveToFile];
		}
	}
	
	//[sourceListDataSource bumpUpdateRevision];
}


#pragma mark -
#pragma mark outlineview delegate methods


// ----------------------------------------------------------------------------
- (BOOL) outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item 
// ----------------------------------------------------------------------------
{
	if (item != nil && playlist != nil && browserMode == BROWSER_MODE_PLAYLIST && browserMode != BROWSER_MODE_SMART_PLAYLIST)
	{
		SPBrowserItem* browserItem = (SPBrowserItem*) item;
		
		if (tableColumn == tableColumns[COLUMN_SUBTUNE])
			return ([browserItem subTuneCount] > 1);
		else if (tableColumn == tableColumns[COLUMN_REPEAT] || tableColumn == tableColumns[COLUMN_PATH])
            ;
			return YES;
	}
	
	return NO;
}


// ----------------------------------------------------------------------------
- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
// ----------------------------------------------------------------------------
{
	if (item != nil && cell != nil)
	{
		if ([item fileDoesNotExist])
		{
			NSMutableDictionary* attributes = [[[cell attributedStringValue] attributesAtIndex:0 effectiveRange:NULL] mutableCopy];
			[attributes setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
			NSAttributedString* name = [[NSAttributedString alloc] initWithString:[cell stringValue] attributes:attributes];
			[cell setAttributedStringValue:name];
		}
	
		[cell setLineBreakMode:NSLineBreakByTruncatingMiddle];
	}
}


// ----------------------------------------------------------------------------
- (BOOL) outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
// ----------------------------------------------------------------------------
{
	return YES;
}


// ----------------------------------------------------------------------------
- (NSString *)outlineView:(NSOutlineView *)outlineView typeSelectStringForTableColumn:(NSTableColumn *)tableColumn item:(id)item 
// ----------------------------------------------------------------------------
{
	NSString* identifier = [tableColumn identifier];
	if ([identifier isEqualToString:@"title"])
		return [item title];
	else
		return @"";
}


// ----------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray*)items toPasteboard:(NSPasteboard*)pasteboard
// ----------------------------------------------------------------------------
{
	SPBrowserItem* firstItem = [items objectAtIndex:0];
	if ([firstItem isFolder])
		return NO;

	if (browserMode == BROWSER_MODE_SHARED_COLLECTION || browserMode == BROWSER_MODE_SHARED_PLAYLIST || browserMode == BROWSER_MODE_SHARED_SMART_PLAYLIST)
		return NO;
	
	draggedItems = items;
		
    // Provide data for our custom type, and simple NSStrings.
    [pasteboard declareTypes:[NSArray arrayWithObjects:SPBrowserItemPBoardType, NSStringPboardType, nil] owner:self];

    [pasteboard setData:[NSData data] forType:SPBrowserItemPBoardType];

	if ([items count] == 1)
		[pasteboard setString:[[items objectAtIndex:0] path] forType:NSStringPboardType];
	
    return YES;
}


// ----------------------------------------------------------------------------
- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
// ----------------------------------------------------------------------------
{
	//SPBrowserItem* proposedItem = item;

	NSString* type = [[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, SPSourceListCollectionItemPBoardType, SPBrowserItemPBoardType, nil]];
	if (type == nil)
		return NSDragOperationNone;
	
	NSSortDescriptor* sortDescriptor = [[browserView sortDescriptors] objectAtIndex:0];
	BOOL isSortedByPlaylistIndex = [sortDescriptor ascending] && [[sortDescriptor key] isEqualToString:@"playlistIndex"];
	
	if ([info draggingSource] == browserView && playlist != nil && [type isEqualToString:SPBrowserItemPBoardType] && 
		index != NSOutlineViewDropOnItemIndex && isSortedByPlaylistIndex && browserMode != BROWSER_MODE_SMART_PLAYLIST)
	{
		// Playlist item reordering
		return NSDragOperationGeneric;
	}
	else if ([type isEqualToString:NSFilenamesPboardType] && index != NSOutlineViewDropOnItemIndex)
	{
		// Files dragged from the Finder
		if (playlist != nil && browserMode != BROWSER_MODE_SMART_PLAYLIST && isSortedByPlaylistIndex)
		{
			NSPasteboard *pasteBoard = [info draggingPasteboard];
			NSArray *files = [pasteBoard propertyListForType:NSFilenamesPboardType];
		
			BOOL someFilesUnderCurrentCollectionRoot = YES;
			for (NSString* file in files)
			{
				NSString* relativePath = [[SPCollectionUtilities sharedInstance] makePathRelativeToCollectionRoot:file];
				if (relativePath == nil)
				{
					someFilesUnderCurrentCollectionRoot = NO;
					break;
				}
			}
		
			return someFilesUnderCurrentCollectionRoot ? NSDragOperationGeneric : NSDragOperationNone;
		}
		else if (playlist == nil)
		{
			[outlineView setDropItem:nil dropChildIndex:-1];
			return NSDragOperationGeneric;
		}
	}
	/*
	else
	{
		if ([type isEqualToString:SPSourceListCollectionItemPBoardType] && index == NSOutlineViewDropOnItemIndex)
		{
			return NSDragOperationGeneric;
		}
	}
	*/
	
	return NSDragOperationNone; 
}


// ----------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index
// ----------------------------------------------------------------------------
{
	NSPasteboard* pasteboard = [info draggingPasteboard];
	NSArray* supportedTypes = [NSArray arrayWithObjects:SPSourceListCollectionItemPBoardType, SPBrowserItemPBoardType, NSFilenamesPboardType, nil];
	NSString* bestType = [pasteboard availableTypeFromArray:supportedTypes];
	//SPBrowserItem* targetItem = item;
	int targetIndex = (index == NSOutlineViewDropOnItemIndex) ? -1 : (int)index;
	
	if ([bestType isEqualToString:NSFilenamesPboardType])
	{
		NSPasteboard *pasteBoard = [info draggingPasteboard];
		NSArray *paths = [pasteBoard propertyListForType:NSFilenamesPboardType];

		// Files dropped from Finder
		if (playlist != nil && browserMode != BROWSER_MODE_SMART_PLAYLIST)
		{
			SPSimplePlaylist* simplePlaylist = (SPSimplePlaylist*) playlist;
			NSMutableArray* playlistItems = [simplePlaylist items];
			
			for (NSString* path in paths)
			{
				NSString* relativePath = [[SPCollectionUtilities sharedInstance] makePathRelativeToCollectionRoot:path];
				if (relativePath != nil)
				{
					SPPlaylistItem* playlistItem = [[SPPlaylistItem alloc] initWithPath:relativePath andSubtuneIndex:0 andLoopCount:1];
					[playlistItems insertObject:playlistItem atIndex:targetIndex];
				}
			}
			
			[simplePlaylist saveToFile];
			
			// Refresh browser with new playlist contents
			[rootItems removeAllObjects];
			[SPBrowserItem fillArray:rootItems withPlaylist:playlist];
			[rootItems sortUsingDescriptors:[browserView sortDescriptors]];
			
			//[sourceListDataSource bumpUpdateRevision];
		}
		else if (playlist == nil)
		{
			NSString* firstPath = [paths objectAtIndex:0];
			BOOL isFolder = NO;
			[[NSFileManager defaultManager] fileExistsAtPath:firstPath isDirectory:&isFolder];
			
			if ([paths count] == 1 && isFolder)
			{
				[self setInProgress:YES];
				[self stopSearchAndClearSearchString];
		
				currentPath = firstPath;
				[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
				
                [browserView scrollRowToVisible:0];
				[self saveBrowserState];
				[rootItems removeAllObjects];
				[SPBrowserItem fillArray:rootItems withDirectoryContentsAtPath:currentPath andParent:nil];
				[rootItems sortUsingDescriptors:[browserView sortDescriptors]];
				[pathControl setURL:[NSURL fileURLWithPath:currentPath]];
				[self setInProgress:NO];
			}
			else
			{
				[self setInProgress:YES];
				[self stopSearchAndClearSearchString];
		
				[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                [browserView scrollRowToVisible:0];
				[self saveBrowserState];
				[rootItems removeAllObjects];

				// Files dropped onto browser
				for (NSString* path in paths)
				{
					BOOL isFolder = NO;
					[[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isFolder];
				
					SPBrowserItem* item = [[SPBrowserItem alloc] initWithPath:path isFolder:isFolder forParent:nil withDefaultSubtune:0];
					[rootItems addObject:item];
				}

				[pathControl setURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://dummy/DRAGGED%%20ITEMS"]]];
				NSPathComponentCell* componentCell = [[pathControl pathComponentCells] objectAtIndex:0];
				[componentCell setImage:[NSImage imageNamed:@"psid.icns"]];
				currentPath = nil;
				[self setInProgress:NO];
			}
		}
	}
	else if ([bestType isEqualToString:SPBrowserItemPBoardType] && playlist != nil && browserMode != BROWSER_MODE_SMART_PLAYLIST)
	{
		// Reorder items (move dragged items to new index)
		NSMutableIndexSet* indices = [[NSMutableIndexSet alloc] init];
		for (SPBrowserItem* draggedItem in draggedItems)
			[indices addIndex:[draggedItem playlistIndex]];

		SPSimplePlaylist* simplePlaylist = (SPSimplePlaylist*) playlist;
		NSInteger newBaseIndex = [simplePlaylist moveItemsAtIndices:indices toIndex:targetIndex];
		[playlist saveToFile];

		// Refresh browser with new playlist contents
		[rootItems removeAllObjects];
		[SPBrowserItem fillArray:rootItems withPlaylist:playlist];
		[rootItems sortUsingDescriptors:[browserView sortDescriptors]];

		for (int i = 0; i < [draggedItems count]; i++)
		{
			int row = (int)(newBaseIndex + i);
			if (i == 0)
				[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
			else
				[browserView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:YES];
		}
		
		//[sourceListDataSource bumpUpdateRevision];
	}
	/*
	NSArray* draggedSourceListItems = [sourceListDataSource draggedItems];
	else if ([bestType isEqualToString:SPSourceListCollectionItemPBoardType] && [draggedSourceListItems count] == 1)
	{
		SPSourceListItem* sourceListItem = [draggedSourceListItems objectAtIndex:0];
		NSLog(@"switch to collection %@\n", [sourceListItem path]);
	}
	*/
	
	draggedItems = nil;
	[browserView reloadData];

    return YES;
}


// ----------------------------------------------------------------------------
- (BOOL) outlineView:(NSOutlineView *)sender isGroupItem:(id)item
// ----------------------------------------------------------------------------
{
	return NO;
}


@end


#pragma mark -

@implementation SPBrowserView


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[self setDoubleAction:@selector(doubleClick:)];

	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(itemDidCollapse:)
											     name:NSOutlineViewItemDidCollapseNotification object:nil];

	[self reloadData];
}


// ----------------------------------------------------------------------------
- (void) activateItem:(SPBrowserItem*)item
// ----------------------------------------------------------------------------
{
    SPBrowserDataSource* dataSource = (SPBrowserDataSource*)[self dataSource];
    
	if ([item isFolder])
	{
		[dataSource browseToPath:[item path]];
	}
	else
	{
		if ([item fileDoesNotExist])
		{
			NSAlert* alert = [NSAlert alertWithMessageText:@"This file cannot be found!"
											 defaultButton:@"Locate File"
										   alternateButton:@"Cancel"
											   otherButton:nil
								 informativeTextWithFormat:@"Do you want to update the playlist entry by specifying a new file?"];

			NSInteger returnStatus = [alert runModal];
			
			if (returnStatus == NSAlertDefaultReturn)
				[dataSource findMissingPlaylistFileOfItem:item];
		}
		else
			[dataSource playItem:item];
	}
}


// ----------------------------------------------------------------------------
- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend
// ----------------------------------------------------------------------------
{
    SPBrowserDataSource* dataSource = (SPBrowserDataSource*)[self dataSource];

	[super selectRowIndexes:indexes byExtendingSelection:extend];

	if ([dataSource isSharedCollection] || [dataSource isSharedPlaylist] || [dataSource isSharedSmartPlaylist])
	{
		[[SPStilBrowserController sharedInstance] displaySharedCollectionMessage];
	}
	else
	{
		if ([indexes count] == 1)
		{
			SPBrowserItem* item = [self itemAtRow:[indexes firstIndex]];
			if (item != nil)
			{
				NSString* absolutePath = [item path];
				NSString* relativePath = [[SPCollectionUtilities sharedInstance] makePathRelativeToCollectionRoot:absolutePath];
				[[SPStilBrowserController sharedInstance] displayEntryForRelativePath:relativePath];
			}
		}
	}
}


// ----------------------------------------------------------------------------
- (void) doubleClick:(id)sender
// ----------------------------------------------------------------------------
{	
	SPBrowserItem* item = [self itemAtRow:[self clickedRow]];
	if (item == nil)
		return;

	[self activateItem:item];
}


// ----------------------------------------------------------------------------
- (void) keyDown:(NSEvent*)event
// ----------------------------------------------------------------------------
{
    SPBrowserDataSource* dataSource = (SPBrowserDataSource*)[self dataSource];
    
	NSString* characters = [event charactersIgnoringModifiers];
	unichar character = [characters characterAtIndex:0];
	
	if (character == '\r' || character == 3)
	{
		NSIndexSet* set = [self selectedRowIndexes];
		if ([set count] == 1)
		{
			SPBrowserItem* item = [self itemAtRow:[set firstIndex]];
			if (item != nil)
			{
				[self activateItem:item];
				return;
			}
		}
	}
	else if (character == 63272 || character == 127)
	{
		SPPlaylist* playlist = [dataSource playlist];
		if (playlist != nil && ![dataSource isSharedPlaylist] && ![dataSource isSmartPlaylist])
		{
			[dataSource deleteSelectedItems:self];
			return;
		}
	}
	/*
	else if (isdigit(character))
	{
		return;
	}
	*/
	
	[super keyDown:event];
}



// ----------------------------------------------------------------------------
- (void) paste:(id)sender
// ----------------------------------------------------------------------------
{
	NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
	NSArray* types = [NSArray arrayWithObjects:NSStringPboardType, nil];
	NSString* bestType = [pasteboard availableTypeFromArray:types];	
	if (bestType != nil)
	{
		NSString* pasteboardContents = [pasteboard stringForType:bestType];
		if (pasteboardContents != nil)
		{
			NSString* pastedPath = [pasteboardContents stringByStandardizingPath];
			NSString* relativePath = [[SPCollectionUtilities sharedInstance] makePathRelativeToCollectionRoot:pastedPath];
			NSString* absolutePath = nil;

			if (relativePath != nil)
				absolutePath = [[SPCollectionUtilities sharedInstance] absolutePathFromRelativePath:relativePath];
			else
			{
				absolutePath = [[SPCollectionUtilities sharedInstance] absolutePathFromRelativePath:pastedPath];
				
				BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:NULL];
				if (!exists)
				{
					absolutePath = pastedPath;
				}
			}
			
			if (absolutePath != nil)
			{
				BOOL isFolder = NO;
				BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isFolder];
				if (exists)
				{
					SPBrowserDataSource* dataSource = (SPBrowserDataSource*)[self dataSource];
					if (isFolder)
					{
						[dataSource browseToPath:absolutePath];
					}
					else
					{
						[dataSource browseToFile:absolutePath andSetAsCurrentItem:YES];
					}
				}
			}
		}
	}
}


// ----------------------------------------------------------------------------
- (void) itemDidCollapse:(NSNotification*)notification
// ----------------------------------------------------------------------------
{
	[self setNeedsDisplay:YES];
	[self display];
}


// ----------------------------------------------------------------------------
- (NSImage*) dragImageForRowsWithIndexes:(NSIndexSet*)dragRows tableColumns:(NSArray*)tableColumns event:(NSEvent*)dragEvent offset:(NSPointPointer)dragImageOffset
// ----------------------------------------------------------------------------
{
	if ([dragRows count] == 1)
	{
		NSArray* columns = [self tableColumns];
		NSImage* defaultImage = [super dragImageForRowsWithIndexes:dragRows tableColumns:columns event:dragEvent offset:dragImageOffset];
		NSSize imageSize = [defaultImage size];
		NSImage* image = [[NSImage alloc] initWithSize:imageSize];
		[image lockFocus];
		NSBezierPath* path = [NSBezierPath bezierPathWithRect:NSMakeRect(0.0f, 0.0f, imageSize.width, imageSize.height)];
		[[NSColor colorWithCalibratedWhite:1.0f alpha:0.5f] set];
		[path fill];
		[[NSColor colorWithCalibratedWhite:0.0f alpha:0.5f] set];
		[path stroke];
		[defaultImage compositeToPoint:NSMakePoint(0, 0) operation:NSCompositeSourceOver];
		[image unlockFocus];
		
		return image;
	}
	else if ([dragRows count] < 10)
	{
		NSImage* iconImage = [NSImage imageNamed:@"psid.icns"];
		NSImage* badgeImage = [NSImage imageNamed:@"dragBadge"]; 

		NSRect iconImageRect = NSMakeRect(0.0f, 0.0f, [iconImage size].width, [iconImage size].height);
		NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(64.0f, 64.0f)];
		[image lockFocus];
		[iconImage drawInRect:NSMakeRect(16.0f, 16.0f, 32.0f, 32.0f) fromRect:iconImageRect operation:NSCompositeSourceOver fraction:0.5f];
		[badgeImage compositeToPoint:NSMakePoint(38.0f, 10.0f) operation:NSCompositeSourceOver];
		NSDictionary* normalAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont boldSystemFontOfSize:11.0f], NSFontAttributeName,
																		       [NSColor whiteColor], NSForegroundColorAttributeName, nil];
		NSMutableAttributedString* numberString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%lu", (unsigned long)[dragRows count]] attributes:normalAttrs];
		[numberString drawAtPoint:NSMakePoint(47.0f, 16.0f)];
		[image unlockFocus];

		return image;
	}
	else
	{
		NSImage* iconImage = [NSImage imageNamed:@"psid.icns"];

		NSRect iconImageRect = NSMakeRect(0.0f, 0.0f, [iconImage size].width, [iconImage size].height);
		NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(64.0f, 64.0f)];
		[image lockFocus];
		[iconImage drawInRect:NSMakeRect(12.0f, 20.0f, 32.0f, 32.0f) fromRect:iconImageRect operation:NSCompositeSourceOver fraction:0.8f];
		[iconImage drawInRect:NSMakeRect(16.0f, 16.0f, 32.0f, 32.0f) fromRect:iconImageRect operation:NSCompositeSourceOver fraction:0.8f];
		[iconImage drawInRect:NSMakeRect(20.0f, 12.0f, 32.0f, 32.0f) fromRect:iconImageRect operation:NSCompositeSourceOver fraction:0.8f];
		[image unlockFocus];

		return image;
	}
}


// ----------------------------------------------------------------------------
- (NSMenu*) menuForEvent:(NSEvent *)event
// ----------------------------------------------------------------------------
{
	NSPoint position = [self convertPoint:[event locationInWindow] fromView:nil];
	NSInteger row = [self rowAtPoint:position];

	NSIndexSet* set = [self selectedRowIndexes];
	if (![set containsIndex:row])
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

	SPBrowserDataSource* dataSource = (SPBrowserDataSource*)[self dataSource];
	
	if ([dataSource playlist] != nil)
	{
		if ([dataSource isSmartPlaylist])
			return smartPlaylistContextMenu;
		else if ([dataSource isSharedPlaylist] || [dataSource isSharedSmartPlaylist])
			return sharedCollectionContextMenu;
		else
			return playlistContextMenu;
	}
	else
	{
		if ([dataSource isSpotlightResult])
			return spotlightResultContextMenu;
		else if ([dataSource isSharedCollection])
			return sharedCollectionContextMenu;
		else
			return browserContextMenu;
	}
}


@end
