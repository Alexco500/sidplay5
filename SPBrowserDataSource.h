@class SPBrowserItem;
@class SongLengthDatabase;
@class SPPlaylist;
@class SPSourceListDataSource;
@class SPPredicateEditorController;
@class SPGradientBox;
@class SPBrowserState;


extern NSString* SPBrowserItemPBoardType;

enum ColumnType
{
	COLUMN_TITLE = 0,
	COLUMN_TIME,
	COLUMN_AUTHOR,
	COLUMN_RELEASED,
	COLUMN_PATH,
	COLUMN_INDEX,
	COLUMN_SUBTUNE,
	COLUMN_REPEAT,
	
	COLUMN_COUNT
};


enum BrowserMode
{
	BROWSER_MODE_COLLECTION = 0,
	BROWSER_MODE_SHARED_COLLECTION,
	BROWSER_MODE_SPOTLIGHT_RESULT,
	BROWSER_MODE_PLAYLIST,
	BROWSER_MODE_SMART_PLAYLIST,
	BROWSER_MODE_SHARED_PLAYLIST,
	BROWSER_MODE_SHARED_SMART_PLAYLIST
};


@interface SPBrowserView : NSOutlineView
{
	IBOutlet NSMenu* browserContextMenu;
	IBOutlet NSMenu* playlistContextMenu;
	IBOutlet NSMenu* smartPlaylistContextMenu;
	IBOutlet NSMenu* spotlightResultContextMenu;
	IBOutlet NSMenu* sharedCollectionContextMenu;
}

- (void) awakeFromNib;
- (void) activateItem:(SPBrowserItem*)item;
- (void) doubleClick:(id)sender;
- (void) keyDown:(NSEvent*)event;
- (void) itemDidCollapse:(NSNotification*)notification;

@end


@interface SPBrowserDataSource : NSObject <NSMetadataQueryDelegate>
{
	NSMutableArray* rootItems;
	NSString* rootPath;
	NSString* currentPath;
	NSMutableArray* browseHistory;
	int browseHistoryIndex;
	SPBrowserItem* currentItem;
	SPPlaylist* playlist;
	BrowserMode browserMode;
	
	NSString* currentSharedCollection;
	NSString* currentSharedCollectionRoot;
	NSString* currentSharedCollectionName;
    NSMutableData* indexData;
    NSURLConnection* indexDownloadConnection;
	
	NSArray* draggedItems;
	NSMutableArray* unfilteredPlaylistItems;
    NSMutableArray* shuffledPlaylistItems;
    int currentShuffleIndex;
	BOOL spotlightSearchTypeSubViewVisible;
	BOOL limitSpotlightScopeToCurrentFolder;
	SPBrowserState* savedState;
	
	NSMetadataQuery* searchQuery;
	NSPredicate* currentSearchPredicate;

	NSTableColumn* tableColumns[COLUMN_COUNT];

	IBOutlet SPBrowserView* browserView;
	IBOutlet NSPathControl* pathControl;
	IBOutlet NSSegmentedControl* navigationControl;
	IBOutlet NSProgressIndicator* progressIndicator;
	IBOutlet NSProgressIndicator* searchTypeProgressIndicator;
	IBOutlet NSSearchField* toolbarSearchField;
	IBOutlet NSMenu* toolbarSearchFieldMenu;
	IBOutlet NSMenu* tableHeaderContextMenu;
	IBOutlet NSMenu* tableHeaderPlaylistContextMenu;
	IBOutlet NSSegmentedControl* browserPlaybackModeControl;
	
	IBOutlet SPSourceListDataSource* sourceListDataSource;
	IBOutlet SPPredicateEditorController* predicateEditorController;
	IBOutlet SPGradientBox* spotlightSearchTypeSubView;
	IBOutlet NSButton* searchFullCollectionButton;
	IBOutlet NSButton* searchCurrentFolderButton;	
	IBOutlet NSButton* saveSearchAsSmartPlaylistButton;
	
	IBOutlet NSMenuItem* nextPlaylistItemMenuItem;
	IBOutlet NSMenuItem* previousPlaylistItemMenuItem;
}

- (void) awakeFromNib;
- (void) updateCurrentSong:(NSInteger)seconds;

- (NSMutableArray*) rootItems;

- (SPPlaylist*) playlist;
- (void) switchToPlaylist:(SPPlaylist*)thePlaylist;
- (void) switchToSharedPlaylist:(SPPlaylist*)thePlaylist withService:(NSNetService*)service isSmartPlaylist:(BOOL)smartPlaylist;

- (void) setPlaylistModeBrowserColumns:(BOOL)playlistMode;
- (void) enableSmartPlaylistEditor:(BOOL)enable;

- (void) switchToSharedCollectionURL:(NSString*)urlString withServiceName:(NSString*)serviceName;
- (void) setSharedCollectionRootPath:(NSString*)urlString withServiceName:(NSString*)serviceName;

- (NSString*) rootPath;
- (void) setRootPath:(NSString*)path;
- (NSString*) currentPath;
- (void) switchToPath:(NSString*)path;
- (void) browseToPath:(NSString*)path;
- (void) browseToFile:(NSString*)path andSetAsCurrentItem:(BOOL)setAsCurrentItem;
- (void) navigateBack;
- (void) navigateForward;
- (void) clearBrowseHistory;
- (void) updatePathControlForPlaylistMode:(BOOL)isCaching;

- (void) playItem:(SPBrowserItem*)item;

- (void) findExpandedItems:(NSMutableArray*)expandedItems inItems:(NSMutableArray*)items;
- (void) saveBrowserState;
- (BOOL) restoreBrowserState;

- (void) setInProgress:(BOOL)active;
- (void) setCurrentItem:(SPBrowserItem*)item;
- (BOOL) playSelectedItem;

- (void) stopSearchAndClearSearchString;
- (void) searchInPlaylist:(NSString*)searchString;
- (void) adjustSearchTypeControlsAndMenu;

- (void) setPlaybackModeControlImages;

- (NSArray*) draggedItems;
- (NSSearchField*) toolbarSearchField;
- (BOOL) isSmartPlaylist;
- (BOOL) isSpotlightResult;
- (BOOL) isSharedCollection;
- (BOOL) isSharedPlaylist;
- (BOOL) isSharedSmartPlaylist;
- (BrowserMode) browserMode;
- (void) setBrowserMode:(BrowserMode)mode;

- (IBAction) clickNavigateControl:(id)sender;
- (IBAction) clickPathControl:(id)sender;
- (IBAction) searchStringEntered:(id)sender;
- (IBAction) searchTypeChanged:(id)sender;
- (IBAction) searchTypeChangedViaButtons:(id)sender;
- (IBAction) searchScopeChanged:(id)sender;
- (IBAction) saveCurrentSearchAsSmartPlaylist:(id)sender;

- (IBAction) navigateBackFromMenu:(id)sender;
- (IBAction) navigateForwardFromMenu:(id)sender;

- (IBAction) tableColumnStatusChanged:(id)sender;

- (IBAction) playNextPlaylistItem:(id)sender;
- (IBAction) playPreviousPlaylistItem:(id)sender;

- (IBAction) showCurrentItem:(id)sender;

- (IBAction) revealSelectedItemInBrowser:(id)sender;
- (IBAction) revealSelectedItemInFinder:(id)sender;
- (IBAction) copyPathOfSelectedItemToClipboard:(id)sender;
- (IBAction) copyRelativePathOfSelectedItemToClipboard:(id)sender;

- (IBAction) deleteSelectedItems:(id)sender;
- (IBAction) exportSelectedItems:(id)sender;
- (IBAction) findRemixesOfSelectedItem:(id)sender;

- (IBAction) clickPlaybackModeControl:(id)sender;

@end

