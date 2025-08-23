#import <Cocoa/Cocoa.h>


@class SPSourceListItem;
@class SPSourceListView;
@class SPBrowserDataSource;
@class SPPlaylist;
@class SPSmartPlaylist;

extern NSString* SPSourceListCollectionItemPBoardType;


@interface SPSourceListDataSource : NSObject
{
	IBOutlet NSTableColumn *tableColumn;
	
	NSMutableArray* rootItems;
	SPSourceListItem* collectionsContainerItem;
	SPSourceListItem* playlistsContainerItem;
	SPSourceListItem* tasksContainerItem;
	
	SPSourceListItem* currentCollection;
	NSTask* rsyncTask;
	volatile BOOL rsyncMirrorsListDownloaded;
	NSArray* draggedItems;
	
	NSInteger updateRevision;
	
	IBOutlet SPSourceListView* sourceListView;
	IBOutlet SPBrowserDataSource* browserDataSource;
	IBOutlet NSWindow* syncProgressDialog;
	IBOutlet NSTextView* syncProgressActionTextView;
	IBOutlet NSButton* syncProgressDisclosureTriangle;
	IBOutlet NSProgressIndicator* syncProgressIndicator;
	
	IBOutlet NSPanel* m3uExportOptionsPanel;
	IBOutlet NSButton* m3uExportRelativePathsButton;
	IBOutlet NSTextField* m3uExportPathPrefixTextField;
	
	IBOutlet NSWindow* setupCollectionWindow;
}

- (void) setupInitialCollection;
- (void) setupDefaultRsyncMirror;
- (IBAction) clickInitialCollectionChoiceButton:(id)sender;

- (void) initSourceListItems;
- (SPSourceListItem*) addHeaderItemWithName:(NSString*)name atIndex:(NSInteger)index;
- (SPSourceListItem*) addCollectionItemForPath:(NSString*)path atIndex:(NSInteger)index withImage:(NSImage*)image;
- (SPSourceListItem*) addPlaylistItemForPath:(NSString*)path toContainerItem:(SPSourceListItem*)containerItem atIndex:(NSInteger)index withPlaylist:(SPPlaylist*)playlist isSmart:(BOOL)isSmartPlaylist;
+ (SPSourceListItem*) addSourceListItemToItem:(SPSourceListItem*)containerItem atIndex:(NSInteger)index forPath:(NSString*)path withName:(NSString*)name withImage:(NSImage*)image;
+ (SPSourceListItem*) addSourceListItemToItem:(SPSourceListItem*)containerItem atIndex:(NSInteger)index forPath:(NSString*)path withName:(NSString*)name;
- (BOOL) removeSourceListItem:(SPSourceListItem*)item;

- (SPSourceListItem*) findItemWithPath:(NSString*)path;
- (SPSourceListItem*) findItemWithPath:(NSString*)path inParentItem:(SPSourceListItem*)parentItem;

@property (NS_NONATOMIC_IOSONLY, readonly, strong) SPBrowserDataSource *browserDataSource;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) SPSourceListView *sourceListView;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *draggedItems;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) NSWindow *syncProgressDialog;

@property (NS_NONATOMIC_IOSONLY, strong) SPSourceListItem *currentCollection;

@property (NS_NONATOMIC_IOSONLY, readonly, strong) SPSourceListItem *collectionsContainerItem;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) SPSourceListItem *playlistsContainerItem;

- (void) sortPlaylists;
- (void) recacheSmartPlaylists;
- (void) createNewPlaylistWithName:(NSString*)name andSelectInSourceList:(BOOL)select;

- (void) checkForAutoSync;
- (void) performSyncOperationAutomatically:(BOOL)triggeredByAutoInterval showWarningDialog:(BOOL)showDialog; 
- (IBAction) syncCurrentCollection:(id)sender;
- (IBAction) cancelSync:(id)sender;
- (IBAction) discloseSyncProgressDetails:(id)sender;
- (void) rsyncOutputPending:(NSNotification*)aNotification;
- (void) rsyncTaskFinished:(NSNotification*)aNotification;

- (void) addSavedSearchSmartPlaylist:(SPSmartPlaylist*)smartPlaylist;
- (void) addSongToPlaylist:(NSString *)song withSubtune:(int) subtune;


- (IBAction) removeSelectedSourceListItem:(id)sender;

- (IBAction) addNewPlaylist:(id)sender;
- (IBAction) addNewSmartPlaylist:(id)sender;
- (IBAction) editSmartPlaylist:(id)sender;
- (IBAction) savePlaylistToM3U:(id)sender;
- (IBAction) cancelM3UExportOptions:(id)sender;
- (IBAction) confirmM3UExportOptions:(id)sender;
- (IBAction) clickExportRelativePaths:(id)sender;
- (IBAction) shufflePlaylist:(id)sender;
- (IBAction) shuffleSmartPlaylist:(id)sender;
- (IBAction) switchToFavoritesPlaylist:(id)sender;

@end

@interface SPSourceListView : NSOutlineView
{
	BOOL isActive;
	
	IBOutlet NSMenu* collectionItemMenu;
	IBOutlet NSMenu* playlistItemMenu;
	IBOutlet NSMenu* smartPlaylistItemMenu;
	IBOutlet NSMenuItem* editSmartPlaylistMenuItem;
}

- (void) awakeFromNib;
- (void) reloadData;
- (void) activateSourceListItem:(SPSourceListItem*)selectedItem;
- (void) itemDidCollapse:(NSNotification*)notification;
@property (NS_NONATOMIC_IOSONLY, getter=isActive, readonly) BOOL active;

@end
