#import <Cocoa/Cocoa.h>
#import "PlayerLibSidplay.h"

@class SPPlayerWindow;
@class SPSourceListDataSource;

enum SPSearchType
{
	SEARCH_ALL = 0,
	SEARCH_TITLE,
	SEARCH_AUTHOR,
	SEARCH_RELEASED,
	SEARCH_FILENAME
};


enum SPSyncInterval
{
	SYNC_DAILY = 0,
	SYNC_WEEKLY,
	SYNC_MONTHLY
};


struct Preferences
{
	void				initializeDefaults();
	void				resetFilterDefaults();
	void				setDistortionParametersBasedOnFilterType();
	
	float				mPlaybackVolume;
	NSMutableArray*		mCollections;
	SPSearchType		mSearchType;

	BOOL				mInfoWindowVisible;
	
	BOOL				mTuneInfoCollapsed;
	BOOL				mOscilloscopeCollapsed;
	BOOL				mSidRegistersCollapsed;
	BOOL				mMixerCollapsed;
	BOOL				mFilterControlCollapsed;
	BOOL				mComposerPhotoCollapsed;
	
	BOOL				mLegacyPlaylistsMigrated;
	BOOL				mShuffleActive;
	BOOL				mFadeActive;
	BOOL				mRepeatActive;
    BOOL                mRepeatSingleActive;
    BOOL                mAllSubSongsActive;
	int					mDefaultPlayTime;
	BOOL				mHideStilBrowserOnLinkClicked;
	
	NSString*			mSyncUrl;
	BOOL				mSyncAutomatically;
	NSDate*				mLastSyncTime;
	SPSyncInterval		mSyncInterval;
	
	BOOL				mSearchForSharedCollections;
	BOOL				mPublishSharedCollection;
	NSString*			mSharedCollectionPath;
	BOOL				mShareAllPlaylists;
	NSMutableArray*		mSharedPlaylists;
	int					mUpdateRevision;
	
	PlaybackSettings	mPlaybackSettings;
	PlaybackSettings	mCustomFilterSettings;
};

extern Preferences		gPreferences;

extern NSString* SPPlaybackSettingsChangedNotification;

@interface SPPreferencesController : NSObject
{
	BOOL loaded;
}

+ (void) initialize;
+ (SPPreferencesController*) sharedInstance;

- (void) load;
- (void) save;

- (void) initializeFilterSettingsFromChipModelOfPlayer:(PlayerLibSidplay*)player;

@end


enum SPPreferencePane
{
	PREFS_GENERAL = 0,
	PREFS_PLAYBACK,
	PREFS_SYNC,
	PREFS_SHARING,
	
	NUM_PREF_PANES
};


@interface SPPreferencesWindowController : NSWindowController
{
	SPPlayerWindow* ownerWindow;
	SPSourceListDataSource* sourceListDataSource;
	NSView* preferencePanes[NUM_PREF_PANES];
	
	NSTask* rebuildSpotlightTask;
	
	BOOL sharedPlaylistsChanged;
	
	IBOutlet NSToolbar* prefsToolbar;
	IBOutlet NSToolbarItem* defaultPrefsPaneItem;

	IBOutlet NSView* generalPreferencePane;
	IBOutlet NSView* playbackPreferencePane;
	IBOutlet NSView* syncPreferencePane;
	IBOutlet NSView* sharingPreferencePane;
	
	// general pref pane
	IBOutlet NSProgressIndicator* rebuiltSpotlightProgressIndicator;
	IBOutlet NSTextField* timeTextField;
	IBOutlet NSStepper* timeStepper;
	IBOutlet NSButton* hideStilBrowserButton;
	
	// playback pref pane
	IBOutlet NSPopUpButton* optimizationPopup;
	IBOutlet NSButton* filterDistortionButton;
	IBOutlet NSPopUpButton* oversamplingPopup;
	IBOutlet NSMatrix* sidModelRadioButton;
	IBOutlet NSButton* forceSidModelButton;
	IBOutlet NSMatrix* timingRadioButton;
	
	// sync pref pane
	IBOutlet NSButton* autoSyncButton;
	IBOutlet NSPopUpButton* autoSyncIntervalPopup;
	IBOutlet NSPopUpButton* syncUrlPopup;
	
	// sharing pref pane
	IBOutlet NSButton* searchForSharedCollectionsButton;
	IBOutlet NSButton* publishSharedCollectionButton;
	IBOutlet NSPopUpButton* sharedCollectionsPopup;
	IBOutlet NSMatrix* playlistSharingRadioButton;
	IBOutlet NSTableView* sharedPlaylistsTableView;
}

- (void) setOwnerWindow:(SPPlayerWindow*)window;
- (void) setSourceListDataSource:(SPSourceListDataSource*)dataSource;
- (void) switchToPreferencePane:(SPPreferencePane)pane;

- (void) updateStateOfPlaybackControls:(BOOL)resetOldState;

- (IBAction) showWindow:(id)sender;

- (IBAction) toolbarItemClicked:(id)sender;
- (IBAction) playbackSettingsChanged:(id)sender;

- (IBAction) rebuildSpotlightIndex:(id)sender;
- (IBAction) clickTimeStepper:(id)sender;
- (IBAction) timeChanged:(id)sender;
- (void) updateTimeTextField:(int)timeInSeconds;
- (void) timeChangedNotification:(NSNotification*)notification;

- (IBAction) clickHideStilBrowserButton:(id)sender;

- (void) fillRsyncMirrorPopupMenu;
- (IBAction) refreshRsyncMirrorsList:(id)sender;
- (IBAction) selectRsyncMirror:(id)sender;
- (IBAction) clickAutoSyncButton:(id)sender;
- (IBAction) selectAutoSyncInterval:(id)sender;

- (void) fillSharedCollectionsPopup;
- (IBAction) selectCollectionToShare:(id)sender;
- (IBAction) clickSearchForSharedCollectionsButton:(id)sender;
- (IBAction) clickPublishSharedCollectionButton:(id)sender;
- (IBAction) clickShareAllPlaylistsRadioButton:(id)sender;

@end


@interface SPSharedPlaylistsTableView : NSTableView
{
	
}

@end;


