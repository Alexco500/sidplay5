#import <Cocoa/Cocoa.h>


@class SPSourceListItem;
@class SPSourceListView;
@class SPBrowserDataSource;
@class SPPlaylist;
@class SPSmartPlaylist;
@class HTTPServer;

extern NSString* SPSourceListCollectionItemPBoardType;


@interface SPSourceListDataSource : NSObject <NSNetServiceBrowserDelegate>
{
	IBOutlet NSTableColumn *tableColumn;
	
	NSMutableArray* rootItems;
	SPSourceListItem* collectionsContainerItem;
	SPSourceListItem* sharedCollectionsContainerItem;
	SPSourceListItem* playlistsContainerItem;
	SPSourceListItem* tasksContainerItem;
	
	SPSourceListItem* currentCollection;
	NSTask* rsyncTask;
	volatile BOOL rsyncMirrorsListDownloaded;
	NSArray* draggedItems;
	
	HTTPServer* httpServer;
	NSNetServiceBrowser* serviceBrowser;
	NSNetService* currentSharedCollectionService;
	NSNetService* serviceBeingResolved;
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
- (SPSourceListItem*) addSharedCollectionItemForService:(NSNetService*)service atIndex:(NSInteger)index;
- (SPSourceListItem*) addPlaylistItemForPath:(NSString*)path toContainerItem:(SPSourceListItem*)containerItem atIndex:(NSInteger)index withPlaylist:(SPPlaylist*)playlist isSmart:(BOOL)isSmartPlaylist;
+ (SPSourceListItem*) addSourceListItemToItem:(SPSourceListItem*)containerItem atIndex:(NSInteger)index forPath:(NSString*)path withName:(NSString*)name withImage:(NSImage*)image;
+ (SPSourceListItem*) addSourceListItemToItem:(SPSourceListItem*)containerItem atIndex:(NSInteger)index forPath:(NSString*)path withName:(NSString*)name;
- (BOOL) removeSourceListItem:(SPSourceListItem*)item;

- (SPSourceListItem*) findItemWithPath:(NSString*)path;
- (SPSourceListItem*) findItemWithPath:(NSString*)path inParentItem:(SPSourceListItem*)parentItem;

- (SPBrowserDataSource*) browserDataSource;
- (SPSourceListView*) sourceListView;
- (NSArray*) draggedItems;
- (NSWindow*) syncProgressDialog;

- (SPSourceListItem*) currentCollection;
- (void) setCurrentCollection:(SPSourceListItem*)collectionItem;

- (SPSourceListItem*) collectionsContainerItem;
- (SPSourceListItem*) playlistsContainerItem;

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

//- (NSNetService*) currentSharedCollectionService;
//- (void) setCurrentSharedCollectionService:(NSNetService*)service;
//- (void) publishSharedCollectionWithPath:(NSString*)collectionPath;
//- (void) publishSharedCollection:(SPSourceListItem*) collectionItem;
//- (void) searchForSharedCollections:(BOOL)enableSearching;
//- (void) sharedPlaylistsIndexDownloaded:(NSNotification *)notification;
//- (NSInteger) updateRevision;
//- (void) bumpUpdateRevision;
//- (void) checkForRemoteUpdateRevisionChange;

- (IBAction) removeSelectedSourceListItem:(id)sender;

- (IBAction) addNewPlaylist:(id)sender;
- (IBAction) addNewSmartPlaylist:(id)sender;
- (IBAction) editSmartPlaylist:(id)sender;
- (IBAction) savePlaylistToM3U:(id)sender;
- (IBAction) cancelM3UExportOptions:(id)sender;
- (IBAction) confirmM3UExportOptions:(id)sender;
- (IBAction) clickExportRelativePaths:(id)sender;

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
- (BOOL) isActive;

@end
