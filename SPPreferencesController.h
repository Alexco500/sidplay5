#import <Cocoa/Cocoa.h>
#import "PlayerLibSidplayWrapper.h"

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


@interface Preferences : NSObject
{
    float                mPlaybackVolume;
    NSMutableArray*        mCollections;
    enum SPSearchType    mSearchType;
    BOOL                mInfoWindowVisible;
    BOOL                mTuneInfoCollapsed;
    BOOL                mOscilloscopeCollapsed;
    BOOL                mSidRegistersCollapsed;
    BOOL                mMixerCollapsed;
    BOOL                mFilterControlCollapsed;
    BOOL                mComposerPhotoCollapsed;
    BOOL                mLegacyPlaylistsMigrated;
    BOOL                mShuffleActive;
    BOOL                mFadeActive;
    BOOL                mRepeatActive;
    BOOL                mRepeatSingleActive;
    BOOL                mAllSubSongsActive;
    int                    mDefaultPlayTime;
    BOOL                mHideStilBrowserOnLinkClicked;
    NSString*            mSyncUrl;
    BOOL                mSyncAutomatically;
    NSDate*                mLastSyncTime;
    enum SPSyncInterval    mSyncInterval;
    int                    mUpdateRevision;
    struct PlaybackSettings    mPlaybackSettings;
    struct PlaybackSettings    mCustomFilterSettings;
}
@property   float				mPlaybackVolume;
@property	NSMutableArray*		mCollections;
@property	enum SPSearchType	mSearchType;
@property	BOOL				mInfoWindowVisible;
@property	BOOL				mTuneInfoCollapsed;
@property	BOOL				mOscilloscopeCollapsed;
@property	BOOL				mSidRegistersCollapsed;
@property	BOOL				mMixerCollapsed;
@property	BOOL				mFilterControlCollapsed;
@property	BOOL				mComposerPhotoCollapsed;
@property	BOOL				mLegacyPlaylistsMigrated;
@property	BOOL				mShuffleActive;
@property	BOOL				mFadeActive;
@property	BOOL				mRepeatActive;
@property   BOOL                mRepeatSingleActive;
@property   BOOL                mAllSubSongsActive;
@property	int					mDefaultPlayTime;
@property	BOOL				mHideStilBrowserOnLinkClicked;
@property	NSString*			mSyncUrl;
@property	BOOL				mSyncAutomatically;
@property	NSDate*				mLastSyncTime;
@property	enum SPSyncInterval	mSyncInterval;
@property	int					mUpdateRevision;
- (void)    initializeDefaults;
- (void)    resetFilterDefaults;
- (void)    setDistortionParametersBasedOnFilterType;
- (void)    copyPlaybackSettings:(struct PlaybackSettings*)pbSettings;
- (void)    copyCustomFilterSettings:(struct PlaybackSettings*)filterSettings;
- (void)    getPlaybackSettings:(struct PlaybackSettings*)pbSettings;
- (void)    getCustomFilterSettings:(struct PlaybackSettings*)filterSettings;
@end

extern Preferences*		gPreferences;

extern NSString* SPPlaybackSettingsChangedNotification;

@interface SPPreferencesController : NSObject
{
    BOOL loaded;
}

+ (void) initialize;
+ (SPPreferencesController*) sharedInstance;

- (void) load;
- (void) save;

- (void) initializeFilterSettingsFromChipModelOfPlayer:(PlayerLibSidplayWrapper*)player;

@end


enum SPPreferencePane
{
    PREFS_GENERAL = 0,
    PREFS_PLAYBACK,
    PREFS_SYNC,
    
    NUM_PREF_PANES
};


@interface SPPreferencesWindowController : NSWindowController
{
    SPPlayerWindow* ownerWindow;
    SPSourceListDataSource* sourceListDataSource;
    NSView* preferencePanes[NUM_PREF_PANES];
    
    NSTask* rebuildSpotlightTask;
    
    
    IBOutlet NSToolbar* prefsToolbar;
    IBOutlet NSToolbarItem* defaultPrefsPaneItem;
    
    IBOutlet NSView* generalPreferencePane;
    IBOutlet NSView* playbackPreferencePane;
    IBOutlet NSView* syncPreferencePane;
    
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
    
}

- (void) setOwnerWindow:(SPPlayerWindow*)window;
- (void) setSourceListDataSource:(SPSourceListDataSource*)dataSource;
- (void) switchToPreferencePane:(enum SPPreferencePane)pane;

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


@end




