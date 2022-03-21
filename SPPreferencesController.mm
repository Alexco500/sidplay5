#import "SPPreferencesController.h"
#import "SPPlayerWindow.h"
#import "PlayerLibSidplay.h"
#import "SPCollectionUtilities.h"
#import "SPSourceListDataSource.h"
#import "SPSourceListItem.h"
#import "SPPlaylist.h"


static NSString* SPDefaultKeyCollections					= @"Collections";
static NSString* SPDefaultKeyVolume							= @"PlaybackVolume";
static NSString* SPDefaultKeySearchType						= @"SearchType";
static NSString* SPDefaultKeyInfoWindowVisible				= @"InfoWindowVisible";
static NSString* SPDefaultKeyTuneInfoCollapsed				= @"TuneInfoCollapsed";
static NSString* SPDefaultKeyOscilloscopeCollapsed			= @"OscilloscopeCollapsed";
static NSString* SPDefaultKeySidRegistersCollapsed			= @"SidRegistersCollapsed";
static NSString* SPDefaultKeyMixerCollapsed					= @"MixerCollapsed";
static NSString* SPDefaultKeyFilterControlCollapsed			= @"FilterControlCollapsed";
static NSString* SPDefaultKeyComposerPhotoCollapsed			= @"ComposerPhotoCollapsed";
static NSString* SPDefaultKeyLegacyPlaylistsMigrated		= @"LegacyPlaylistsMigrated";
static NSString* SPDefaultKeyShuffleActive					= @"ShuffleActive";
static NSString* SPDefaultKeyFadeActive						= @"FadeActive";
static NSString* SPDefaultKeyRepeatActive					= @"RepeatActive";
static NSString* SPDefaultKeyPlayTime						= @"DefaultPlayTime";
static NSString* SPDefaultKeyHideStilBrowserAutomatically	= @"HideStilBrowserAutomatically";
static NSString* SPDefaultKeySyncUrl						= @"SyncUrl";
static NSString* SPDefaultKeyAutoSync						= @"SyncAutomatically";
static NSString* SPDefaultKeyLastSyncTime					= @"LastSyncTime";
static NSString* SPDefaultKeySyncInterval					= @"SyncInterval";
static NSString* SPDefaultKeySearchForSharedCollections		= @"SearchForSharedCollections";
static NSString* SPDefaultKeyPublishSharedCollection		= @"PublishSharedCollection";
static NSString* SPDefaultKeySharedCollectionPath			= @"SharedCollectionPath";
static NSString* SPDefaultKeyShareAllPlaylists				= @"ShareAllPlaylists";
static NSString* SPDefaultKeySharedPlaylists				= @"SharedPlaylists";
static NSString* SPDefaultKeyUpdateRevision					= @"UpdateRevision";

static NSString* SPDefaultKeyEnableFilterDistortion			= @"EnableFilterDistortion";
static NSString* SPDefaultKeyOversampling					= @"Oversampling";
static NSString* SPDefaultKeyOptimization					= @"Optimization";
static NSString* SPDefaultKeySidModel						= @"SidModel";
static NSString* SPDefaultKeyForceSidModel					= @"ForceSidModel";
static NSString* SPDefaultKeyTiming							= @"Timing";
static NSString* SPDefaultKeyFilterType						= @"FilterType";
static NSString* SPDefaultKeyFilterSteepness				= @"FilterSteepness";
static NSString* SPDefaultKeyFilterOffset					= @"FilterOffset";
static NSString* SPDefaultKeyFilterDistortionRate			= @"FilterDistortionRate";
static NSString* SPDefaultKeyFilterDistortionHeadroom		= @"FilterDistortionHeadroom";

NSString* SPPlaybackSettingsChangedNotification				= @"SPPlaybackSettingsChangedNotification";

static NSString* SPDefaultRsyncUrl							= @"rsync://www.sidmusic.org/hvsc";

Preferences	gPreferences;

// ----------------------------------------------------------------------------
void Preferences::initializeDefaults()
// ----------------------------------------------------------------------------
{
	mPlaybackVolume = 1.0f;
	mCollections = [[NSMutableArray alloc] init];
	mSearchType = SEARCH_TITLE;
	
	mInfoWindowVisible = NO;
	mTuneInfoCollapsed = NO;
	mOscilloscopeCollapsed = YES;
	mSidRegistersCollapsed = YES;
	mMixerCollapsed = YES;
	mFilterControlCollapsed = YES;
	mComposerPhotoCollapsed = YES;
	
	mLegacyPlaylistsMigrated = NO;
	mShuffleActive = NO;
	mFadeActive = NO;
	mRepeatActive = NO;
	mDefaultPlayTime = 3 * 60;
	mHideStilBrowserOnLinkClicked = NO;

	mSyncUrl = [[NSMutableString alloc] init];
	mSyncAutomatically = NO;
	mLastSyncTime = [NSDate date];
	mSyncInterval = SYNC_WEEKLY;
	
	mSearchForSharedCollections = NO; //YES;
	mPublishSharedCollection = NO;
	mSharedCollectionPath = [[NSMutableString alloc] init];
	mShareAllPlaylists = NO; //YES;
	mSharedPlaylists = [[NSMutableArray alloc] init];
	mUpdateRevision = 0;
	
	// These three are not modifiable
	mPlaybackSettings.mFrequency = 44100;
	mPlaybackSettings.mBits = 16;
	mPlaybackSettings.mStereo = false; 

	mPlaybackSettings.mOversampling = 1;
	mPlaybackSettings.mSidModel = 0;
	mPlaybackSettings.mForceSidModel = false;
	mPlaybackSettings.mClockSpeed = 0;	
#ifdef __ppc__
	mPlaybackSettings.mOptimization = 1; 
#else
	mPlaybackSettings.mOptimization = 0; 
#endif
	
	resetFilterDefaults();
}


// ----------------------------------------------------------------------------
void Preferences::resetFilterDefaults()
// ----------------------------------------------------------------------------
{
	mPlaybackSettings.mFilterType = SID_FILTER_6581_Resid;
	setDistortionParametersBasedOnFilterType();
	
	mPlaybackSettings.mEnableFilterDistortion = true;
	
	mCustomFilterSettings = mPlaybackSettings;
}


// ----------------------------------------------------------------------------
void Preferences::setDistortionParametersBasedOnFilterType()
// ----------------------------------------------------------------------------
{
    switch(mPlaybackSettings.mFilterType)
	{
		case SID_FILTER_6581_Resid:
			mPlaybackSettings.mFilterKinkiness = 0.17;
			mPlaybackSettings.mFilterBaseLevel = 210.0f;
			mPlaybackSettings.mFilterOffset = -375.0f;
			mPlaybackSettings.mFilterSteepness = 120.0f;
			mPlaybackSettings.mFilterRolloff = 5.5f;
			mPlaybackSettings.mDistortionRate = 1500;
			mPlaybackSettings.mDistortionHeadroom = 400;
			break;
			
		case SID_FILTER_6581R3:
			mPlaybackSettings.mFilterKinkiness = 0.17;
			mPlaybackSettings.mFilterBaseLevel = 210.0f;
			mPlaybackSettings.mFilterOffset = -375.0f;
			mPlaybackSettings.mFilterSteepness = 120.0f;
			mPlaybackSettings.mFilterRolloff = 5.5f;
			mPlaybackSettings.mDistortionRate = 1600;
			mPlaybackSettings.mDistortionHeadroom = 400;
			break;
			
		case SID_FILTER_6581_Galway:
			mPlaybackSettings.mFilterKinkiness = 0.17;
			mPlaybackSettings.mFilterBaseLevel = 210.0f;
			mPlaybackSettings.mFilterOffset = -725.0f;
			mPlaybackSettings.mFilterSteepness = 120.0f;
			mPlaybackSettings.mFilterRolloff = 5.5f;
			mPlaybackSettings.mDistortionRate = 1500;
			mPlaybackSettings.mDistortionHeadroom = 400;
			break;
			
		case SID_FILTER_6581R4:
			mPlaybackSettings.mFilterKinkiness = 0.17;
			mPlaybackSettings.mFilterBaseLevel = 175.0f;
			mPlaybackSettings.mFilterOffset = 0;
			mPlaybackSettings.mFilterSteepness = 132.0f;
			mPlaybackSettings.mFilterRolloff = 5.5f;
			mPlaybackSettings.mDistortionRate = 1500;
			mPlaybackSettings.mDistortionHeadroom = 400;
			break;
			
		case SID_FILTER_8580:
			mPlaybackSettings.mFilterOffset = 0;
			mPlaybackSettings.mFilterSteepness = 132.0f;
			
			mPlaybackSettings.mDistortionRate = 3200;
			mPlaybackSettings.mDistortionHeadroom = 235;
			break;
			
		case SID_FILTER_CUSTOM:
			mPlaybackSettings.mFilterKinkiness = mCustomFilterSettings.mFilterKinkiness;
			mPlaybackSettings.mFilterBaseLevel = mCustomFilterSettings.mFilterBaseLevel;
			mPlaybackSettings.mFilterOffset = mCustomFilterSettings.mFilterOffset;
			mPlaybackSettings.mFilterSteepness = mCustomFilterSettings.mFilterSteepness;
			mPlaybackSettings.mFilterRolloff = mCustomFilterSettings.mFilterRolloff;
			mPlaybackSettings.mDistortionRate = mCustomFilterSettings.mDistortionRate;
			mPlaybackSettings.mDistortionHeadroom = mCustomFilterSettings.mDistortionHeadroom;
			break;
	}
}


@implementation SPPreferencesController

static SPPreferencesController* sharedInstance = nil;


// ----------------------------------------------------------------------------
+ (void) initialize
// ----------------------------------------------------------------------------
{
	gPreferences.initializeDefaults();

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *appDefaults = [[NSMutableDictionary alloc] init];
    
    [appDefaults setObject:[[NSArray alloc] init] forKey:SPDefaultKeyCollections];
    [appDefaults setObject:[NSNumber numberWithFloat:gPreferences.mPlaybackVolume] forKey:SPDefaultKeyVolume];
    [appDefaults setObject:[NSNumber numberWithInt:gPreferences.mSearchType] forKey:SPDefaultKeySearchType];

    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mInfoWindowVisible] forKey:SPDefaultKeyInfoWindowVisible];
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mTuneInfoCollapsed] forKey:SPDefaultKeyTuneInfoCollapsed];
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mOscilloscopeCollapsed] forKey:SPDefaultKeyOscilloscopeCollapsed];
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mSidRegistersCollapsed] forKey:SPDefaultKeySidRegistersCollapsed];
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mMixerCollapsed] forKey:SPDefaultKeyMixerCollapsed];
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mFilterControlCollapsed] forKey:SPDefaultKeyFilterControlCollapsed];
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mComposerPhotoCollapsed] forKey:SPDefaultKeyComposerPhotoCollapsed];
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mLegacyPlaylistsMigrated] forKey:SPDefaultKeyLegacyPlaylistsMigrated];	
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mShuffleActive] forKey:SPDefaultKeyShuffleActive];	
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mFadeActive] forKey:SPDefaultKeyFadeActive];	
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mRepeatActive] forKey:SPDefaultKeyRepeatActive];	
    [appDefaults setObject:[NSNumber numberWithInt:gPreferences.mDefaultPlayTime] forKey:SPDefaultKeyPlayTime];	
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mHideStilBrowserOnLinkClicked] forKey:SPDefaultKeyHideStilBrowserAutomatically];

    [appDefaults setObject:SPDefaultRsyncUrl forKey:SPDefaultKeySyncUrl];
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mSyncAutomatically] forKey:SPDefaultKeyAutoSync];
    [appDefaults setObject:gPreferences.mLastSyncTime forKey:SPDefaultKeyLastSyncTime];
    [appDefaults setObject:[NSNumber numberWithInt:gPreferences.mSyncInterval] forKey:SPDefaultKeySyncInterval];

    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mSearchForSharedCollections] forKey:SPDefaultKeySearchForSharedCollections];
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mPublishSharedCollection] forKey:SPDefaultKeyPublishSharedCollection];
    [appDefaults setObject:@"" forKey:SPDefaultKeySharedCollectionPath];
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mShareAllPlaylists] forKey:SPDefaultKeyShareAllPlaylists];
	[appDefaults setObject:[[NSArray alloc] init] forKey:SPDefaultKeySharedPlaylists];
    [appDefaults setObject:[NSNumber numberWithInt:gPreferences.mUpdateRevision] forKey:SPDefaultKeyUpdateRevision];
	
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mPlaybackSettings.mEnableFilterDistortion] forKey:SPDefaultKeyEnableFilterDistortion];	
    [appDefaults setObject:[NSNumber numberWithInt:gPreferences.mPlaybackSettings.mOversampling] forKey:SPDefaultKeyOversampling];	
    [appDefaults setObject:[NSNumber numberWithInt:gPreferences.mPlaybackSettings.mSidModel] forKey:SPDefaultKeySidModel];	
    [appDefaults setObject:[NSNumber numberWithBool:gPreferences.mPlaybackSettings.mForceSidModel] forKey:SPDefaultKeyForceSidModel];	
    [appDefaults setObject:[NSNumber numberWithInt:gPreferences.mPlaybackSettings.mClockSpeed] forKey:SPDefaultKeyTiming];	
    [appDefaults setObject:[NSNumber numberWithInt:gPreferences.mPlaybackSettings.mOptimization] forKey:SPDefaultKeyOptimization];	

    [appDefaults setObject:[NSNumber numberWithInt:gPreferences.mPlaybackSettings.mFilterType] forKey:SPDefaultKeyFilterType];	
    [appDefaults setObject:[NSNumber numberWithFloat:gPreferences.mCustomFilterSettings.mFilterSteepness] forKey:SPDefaultKeyFilterSteepness];	
    [appDefaults setObject:[NSNumber numberWithFloat:gPreferences.mCustomFilterSettings.mFilterOffset] forKey:SPDefaultKeyFilterOffset];	
    [appDefaults setObject:[NSNumber numberWithInt:gPreferences.mCustomFilterSettings.mDistortionRate] forKey:SPDefaultKeyFilterDistortionRate];	
    [appDefaults setObject:[NSNumber numberWithInt:gPreferences.mCustomFilterSettings.mDistortionHeadroom] forKey:SPDefaultKeyFilterDistortionHeadroom];	

    [defaults registerDefaults:appDefaults];
}


// ----------------------------------------------------------------------------
+ (SPPreferencesController*) sharedInstance
// ----------------------------------------------------------------------------
{
	if (sharedInstance == nil)
		sharedInstance = [[SPPreferencesController alloc] init];
		
	return sharedInstance;
}


// ----------------------------------------------------------------------------
- (id) init
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		loaded = NO;
	}
	return self;
}


// ----------------------------------------------------------------------------
- (void) load
// ----------------------------------------------------------------------------
{
	if (loaded)
		return;

	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if (defaults == nil)
		return;
	
	gPreferences.mPlaybackVolume = [defaults floatForKey:SPDefaultKeyVolume];
	gPreferences.mCollections = [[defaults arrayForKey:SPDefaultKeyCollections] mutableCopy];
	gPreferences.mSearchType = (SPSearchType) [defaults integerForKey:SPDefaultKeySearchType];
	gPreferences.mInfoWindowVisible = [defaults boolForKey:SPDefaultKeyInfoWindowVisible];
	gPreferences.mTuneInfoCollapsed = [defaults boolForKey:SPDefaultKeyTuneInfoCollapsed];
	gPreferences.mOscilloscopeCollapsed = [defaults boolForKey:SPDefaultKeyOscilloscopeCollapsed];
	gPreferences.mSidRegistersCollapsed = [defaults boolForKey:SPDefaultKeySidRegistersCollapsed];
	gPreferences.mMixerCollapsed = [defaults boolForKey:SPDefaultKeyMixerCollapsed];
	gPreferences.mFilterControlCollapsed = [defaults boolForKey:SPDefaultKeyFilterControlCollapsed];
	gPreferences.mComposerPhotoCollapsed = [defaults boolForKey:SPDefaultKeyComposerPhotoCollapsed];
	gPreferences.mLegacyPlaylistsMigrated = [defaults boolForKey:SPDefaultKeyLegacyPlaylistsMigrated];
	gPreferences.mShuffleActive = [defaults boolForKey:SPDefaultKeyShuffleActive];
	gPreferences.mFadeActive = [defaults boolForKey:SPDefaultKeyFadeActive];
	gPreferences.mRepeatActive = [defaults boolForKey:SPDefaultKeyRepeatActive];
	gPreferences.mDefaultPlayTime = (int)[defaults integerForKey:SPDefaultKeyPlayTime];
	gPreferences.mHideStilBrowserOnLinkClicked = [defaults boolForKey:SPDefaultKeyHideStilBrowserAutomatically];

	gPreferences.mSyncUrl = [[defaults stringForKey:SPDefaultKeySyncUrl] mutableCopy];
	gPreferences.mSyncAutomatically = [defaults boolForKey:SPDefaultKeyAutoSync];
	gPreferences.mLastSyncTime = [defaults objectForKey:SPDefaultKeyLastSyncTime];
	gPreferences.mSyncInterval = (SPSyncInterval) [defaults integerForKey:SPDefaultKeySyncInterval];

	gPreferences.mSearchForSharedCollections = [defaults boolForKey:SPDefaultKeySearchForSharedCollections];
	gPreferences.mPublishSharedCollection = [defaults boolForKey:SPDefaultKeyPublishSharedCollection];
	gPreferences.mSharedCollectionPath = [[defaults stringForKey:SPDefaultKeySharedCollectionPath] mutableCopy];
	gPreferences.mShareAllPlaylists = [defaults boolForKey:SPDefaultKeyShareAllPlaylists];
	gPreferences.mSharedPlaylists = [[defaults arrayForKey:SPDefaultKeySharedPlaylists] mutableCopy];
	gPreferences.mUpdateRevision = (int)[defaults integerForKey:SPDefaultKeyUpdateRevision];

	gPreferences.mPlaybackSettings.mEnableFilterDistortion = [defaults boolForKey:SPDefaultKeyEnableFilterDistortion];
	gPreferences.mPlaybackSettings.mOversampling = (int)[defaults integerForKey:SPDefaultKeyOversampling];
	gPreferences.mPlaybackSettings.mSidModel = (int)[defaults integerForKey:SPDefaultKeySidModel];
	gPreferences.mPlaybackSettings.mForceSidModel = [defaults boolForKey:SPDefaultKeyForceSidModel];
	gPreferences.mPlaybackSettings.mClockSpeed = (int)[defaults integerForKey:SPDefaultKeyTiming];
	gPreferences.mPlaybackSettings.mOptimization = (int)[defaults integerForKey:SPDefaultKeyOptimization];

	gPreferences.mPlaybackSettings.mFilterType = (SPFilterType) [defaults integerForKey:SPDefaultKeyFilterType];
	gPreferences.mCustomFilterSettings.mFilterSteepness = [defaults floatForKey:SPDefaultKeyFilterSteepness];
	gPreferences.mCustomFilterSettings.mFilterOffset = [defaults floatForKey:SPDefaultKeyFilterOffset];
	gPreferences.mCustomFilterSettings.mDistortionRate = (int)[defaults integerForKey:SPDefaultKeyFilterDistortionRate];
	gPreferences.mCustomFilterSettings.mDistortionHeadroom = (int)[defaults integerForKey:SPDefaultKeyFilterDistortionHeadroom];

	loaded = YES;
}


// ----------------------------------------------------------------------------
- (void) save
// ----------------------------------------------------------------------------
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if (defaults == nil)
		return;
		
	[defaults setFloat:gPreferences.mPlaybackVolume forKey:SPDefaultKeyVolume];
	[defaults setObject:gPreferences.mCollections forKey:SPDefaultKeyCollections];
	[defaults setInteger:gPreferences.mSearchType forKey:SPDefaultKeySearchType];
	[defaults setBool:gPreferences.mInfoWindowVisible forKey:SPDefaultKeyInfoWindowVisible];
	[defaults setBool:gPreferences.mTuneInfoCollapsed forKey:SPDefaultKeyTuneInfoCollapsed];
	[defaults setBool:gPreferences.mOscilloscopeCollapsed forKey:SPDefaultKeyOscilloscopeCollapsed];
	[defaults setBool:gPreferences.mSidRegistersCollapsed forKey:SPDefaultKeySidRegistersCollapsed];
	[defaults setBool:gPreferences.mMixerCollapsed forKey:SPDefaultKeyMixerCollapsed];
	[defaults setBool:gPreferences.mFilterControlCollapsed forKey:SPDefaultKeyFilterControlCollapsed];
	[defaults setBool:gPreferences.mComposerPhotoCollapsed forKey:SPDefaultKeyComposerPhotoCollapsed];
	[defaults setBool:gPreferences.mLegacyPlaylistsMigrated forKey:SPDefaultKeyLegacyPlaylistsMigrated];
	[defaults setBool:gPreferences.mShuffleActive forKey:SPDefaultKeyShuffleActive];
	[defaults setBool:gPreferences.mFadeActive forKey:SPDefaultKeyFadeActive];
	[defaults setBool:gPreferences.mRepeatActive forKey:SPDefaultKeyRepeatActive];
	[defaults setInteger:gPreferences.mDefaultPlayTime forKey:SPDefaultKeyPlayTime];
	[defaults setBool:gPreferences.mHideStilBrowserOnLinkClicked forKey:SPDefaultKeyHideStilBrowserAutomatically];

	[defaults setObject:gPreferences.mSyncUrl forKey:SPDefaultKeySyncUrl];
	[defaults setBool:gPreferences.mSyncAutomatically forKey:SPDefaultKeyAutoSync];
	[defaults setObject:gPreferences.mLastSyncTime forKey:SPDefaultKeyLastSyncTime];
	[defaults setInteger:gPreferences.mSyncInterval forKey:SPDefaultKeySyncInterval];
	
	[defaults setBool:gPreferences.mSearchForSharedCollections forKey:SPDefaultKeySearchForSharedCollections];
	[defaults setBool:gPreferences.mPublishSharedCollection forKey:SPDefaultKeyPublishSharedCollection];
	[defaults setObject:gPreferences.mSharedCollectionPath forKey:SPDefaultKeySharedCollectionPath];
    [defaults setBool:gPreferences.mShareAllPlaylists forKey:SPDefaultKeyShareAllPlaylists];
	[defaults setObject:gPreferences.mSharedPlaylists forKey:SPDefaultKeySharedPlaylists];
    [defaults setInteger:gPreferences.mUpdateRevision forKey:SPDefaultKeyUpdateRevision];
	
	[defaults setBool:gPreferences.mPlaybackSettings.mEnableFilterDistortion forKey:SPDefaultKeyEnableFilterDistortion];
	[defaults setInteger:gPreferences.mPlaybackSettings.mOversampling forKey:SPDefaultKeyOversampling];
	[defaults setInteger:gPreferences.mPlaybackSettings.mSidModel forKey:SPDefaultKeySidModel];
	[defaults setBool:gPreferences.mPlaybackSettings.mForceSidModel forKey:SPDefaultKeyForceSidModel];
	[defaults setInteger:gPreferences.mPlaybackSettings.mClockSpeed forKey:SPDefaultKeyTiming];
	[defaults setInteger:gPreferences.mPlaybackSettings.mOptimization forKey:SPDefaultKeyOptimization];

	[defaults setInteger:gPreferences.mPlaybackSettings.mFilterType forKey:SPDefaultKeyFilterType];
	[defaults setFloat:gPreferences.mCustomFilterSettings.mFilterSteepness forKey:SPDefaultKeyFilterSteepness];
	[defaults setFloat:gPreferences.mCustomFilterSettings.mFilterOffset forKey:SPDefaultKeyFilterOffset];
	[defaults setInteger:gPreferences.mCustomFilterSettings.mDistortionRate forKey:SPDefaultKeyFilterDistortionRate];
	[defaults setInteger:gPreferences.mCustomFilterSettings.mDistortionHeadroom forKey:SPDefaultKeyFilterDistortionHeadroom];
	
	[defaults synchronize];
}


// ----------------------------------------------------------------------------
- (void) initializeFilterSettingsFromChipModelOfPlayer:(PlayerLibSidplay*)player
// ----------------------------------------------------------------------------
{
	static SPFilterType oldFilterType = SID_FILTER_6581_Resid;
	
	bool use8580 = false;
	
	if (gPreferences.mPlaybackSettings.mForceSidModel)
	{
		if (gPreferences.mPlaybackSettings.mSidModel == 1)
			use8580 = true;
		else
			use8580 = false;
	}
	else
	{
		if (player && player->getCurrentChipModel() == PlayerLibSidplay::sChipModel8580)
			use8580 = true;
		else 
			use8580 = false;
	}
	
	SPFilterType currentFilterType = gPreferences.mPlaybackSettings.mFilterType;
	
	if (use8580)
	{
		if (gPreferences.mPlaybackSettings.mFilterType != SID_FILTER_8580)
		{
			oldFilterType = gPreferences.mPlaybackSettings.mFilterType;
			gPreferences.mPlaybackSettings.mFilterType = SID_FILTER_8580;
		}
	}
	else if (gPreferences.mPlaybackSettings.mFilterType == SID_FILTER_8580)
	{
		gPreferences.mPlaybackSettings.mFilterType = oldFilterType;
	}
	
	if (gPreferences.mPlaybackSettings.mFilterType != currentFilterType)
		gPreferences.setDistortionParametersBasedOnFilterType();
	
	sid_filter_t filterSettings;
	PlayerLibSidplay::setFilterSettingsFromPlaybackSettings(filterSettings, &gPreferences.mPlaybackSettings);
    if (player != NULL)
        player->setFilterSettings(&filterSettings);
}


@end


@implementation SPPreferencesWindowController


// ----------------------------------------------------------------------------
- (id) init
// ----------------------------------------------------------------------------
{
	if (self = [super initWithWindowNibName:@"Preferences"])
	{
		ownerWindow = nil;
		sourceListDataSource = nil;
		rebuildSpotlightTask = nil;
	}
	
	return self;
}


// ----------------------------------------------------------------------------
- (void) windowDidLoad
// ----------------------------------------------------------------------------
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowWillClose:)
												 name:NSWindowWillCloseNotification
											   object:[self window]];
}


// ----------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	[[SPPreferencesController sharedInstance] save];
}	


static NSString* SPPreferencePaneNames[NUM_PREF_PANES] =
{
	@"General",
	@"Playback",
	@"Collection Sync",
	@"Sharing",
};


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	preferencePanes[PREFS_GENERAL] = generalPreferencePane;
	preferencePanes[PREFS_PLAYBACK] = playbackPreferencePane;
	preferencePanes[PREFS_SYNC] = syncPreferencePane;
	preferencePanes[PREFS_SHARING] = sharingPreferencePane;
	
	[optimizationPopup selectItemWithTag:gPreferences.mPlaybackSettings.mOptimization];
	[filterDistortionButton setState:gPreferences.mPlaybackSettings.mEnableFilterDistortion ? NSOnState : NSOffState];
	[oversamplingPopup selectItemWithTag:gPreferences.mPlaybackSettings.mOversampling];
	[sidModelRadioButton selectCellWithTag:gPreferences.mPlaybackSettings.mSidModel];
	[forceSidModelButton setState:gPreferences.mPlaybackSettings.mForceSidModel ? NSOnState : NSOffState];
	[timingRadioButton selectCellWithTag:gPreferences.mPlaybackSettings.mClockSpeed];
	[self updateStateOfPlaybackControls:NO];
	
	[self updateTimeTextField:gPreferences.mDefaultPlayTime];
	[timeStepper setIntegerValue:gPreferences.mDefaultPlayTime];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(timeChangedNotification:)
												 name:NSControlTextDidChangeNotification
											   object:nil];
	
	[hideStilBrowserButton setState:gPreferences.mHideStilBrowserOnLinkClicked ? NSOnState : NSOffState];
	
	[self switchToPreferencePane:PREFS_GENERAL];
	[prefsToolbar setSelectedItemIdentifier:[defaultPrefsPaneItem itemIdentifier]];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPPlaybackSettingsChangedNotification object:self];

	[self refreshRsyncMirrorsList:self];
	[autoSyncButton setState:gPreferences.mSyncAutomatically ? NSOnState : NSOffState];
	[autoSyncIntervalPopup selectItemWithTag:gPreferences.mSyncInterval];
	
	[self fillSharedCollectionsPopup];
	[searchForSharedCollectionsButton setState:gPreferences.mSearchForSharedCollections ? NSOnState : NSOffState];
	[publishSharedCollectionButton setState:gPreferences.mPublishSharedCollection ? NSOnState : NSOffState];
	[sharedCollectionsPopup setEnabled:gPreferences.mPublishSharedCollection];
	[playlistSharingRadioButton selectCellWithTag:gPreferences.mShareAllPlaylists];
	[sharedPlaylistsTableView setEnabled:!gPreferences.mShareAllPlaylists];
}


// ----------------------------------------------------------------------------
- (void) setOwnerWindow:(SPPlayerWindow*)window
// ----------------------------------------------------------------------------
{
	ownerWindow = window;
}


// ----------------------------------------------------------------------------
- (void) setSourceListDataSource:(SPSourceListDataSource*)dataSource
// ----------------------------------------------------------------------------
{
	sourceListDataSource = dataSource;
}


// ----------------------------------------------------------------------------
- (IBAction) showWindow:(id)sender
// ----------------------------------------------------------------------------
{
	[self fillSharedCollectionsPopup];
	
	[super showWindow:sender];
}


// ----------------------------------------------------------------------------
- (void) switchToPreferencePane:(SPPreferencePane)pane
// ----------------------------------------------------------------------------
{
	NSWindow* window = [self window];

	NSView* tempView = [[NSView alloc] initWithFrame:[[window contentView] frame]];
	[window setContentView:tempView];

	NSView* prefsView = preferencePanes[pane];
	
    NSRect newFrame = [window frame];
    newFrame.size.height = [prefsView frame].size.height + ([window frame].size.height - [[window contentView] frame].size.height);
    newFrame.size.width = [prefsView frame].size.width;
    newFrame.origin.y += ([[window contentView] frame].size.height - [prefsView frame].size.height);

    [window setFrame:newFrame display:YES animate:YES];
	[window setContentView:prefsView];
	[window setTitle:SPPreferencePaneNames[pane]];
}


// ----------------------------------------------------------------------------
- (IBAction) toolbarItemClicked:(id)sender
// ----------------------------------------------------------------------------
{
	[self switchToPreferencePane:(SPPreferencePane)[sender tag]];
	NSString* identifier = [sender itemIdentifier];
	[prefsToolbar setSelectedItemIdentifier:identifier];
}


// ----------------------------------------------------------------------------
- (NSArray*) toolbarSelectableItemIdentifiers:(NSToolbar*)toolbar
// ----------------------------------------------------------------------------
{
	NSArray* selectableItems = [toolbar items];
	NSMutableArray* selectableItemIdentifiers = [NSMutableArray arrayWithCapacity:[selectableItems count]];
	for (NSToolbarItem* item in selectableItems)
		[selectableItemIdentifiers addObject:[item itemIdentifier]];

    return selectableItemIdentifiers;
}


// ----------------------------------------------------------------------------
- (void) updateStateOfPlaybackControls:(BOOL)resetOldState
// ----------------------------------------------------------------------------
{
	static int oldDistortionState = NSOnState;
	static int oldOversamplingFactor = 1;

	if (gPreferences.mPlaybackSettings.mOptimization != 0)
	{
		oldDistortionState = (int)[filterDistortionButton state];
		[filterDistortionButton setState:NSOffState];
		[filterDistortionButton setEnabled:NO];
		gPreferences.mPlaybackSettings.mEnableFilterDistortion = false;
		
		if (resetOldState)
		{
			[oversamplingPopup selectItemWithTag:oldOversamplingFactor];
			[oversamplingPopup setEnabled:YES];
			gPreferences.mPlaybackSettings.mOversampling = oldOversamplingFactor;
		}
	}
	else
	{
		if (resetOldState)
		{
			[filterDistortionButton setState:oldDistortionState];
			[filterDistortionButton setEnabled:YES];
			gPreferences.mPlaybackSettings.mEnableFilterDistortion = oldDistortionState == NSOnState;
		}
		
		oldOversamplingFactor = (int)[[oversamplingPopup selectedItem] tag];
		[oversamplingPopup selectItemWithTag:1];
		[oversamplingPopup setEnabled:NO];
		gPreferences.mPlaybackSettings.mOversampling = 1;
	}
}


// ----------------------------------------------------------------------------
- (IBAction) playbackSettingsChanged:(id)sender
// ----------------------------------------------------------------------------
{
	int oldOptimization = gPreferences.mPlaybackSettings.mOptimization;

	gPreferences.mPlaybackSettings.mOptimization = (int)[[optimizationPopup selectedItem] tag];
	gPreferences.mPlaybackSettings.mEnableFilterDistortion = [filterDistortionButton state] == NSOnState;
	gPreferences.mPlaybackSettings.mOversampling = (int)[[oversamplingPopup selectedItem] tag];
	gPreferences.mPlaybackSettings.mSidModel = (int)[[sidModelRadioButton selectedCell] tag];
	gPreferences.mPlaybackSettings.mForceSidModel = [forceSidModelButton state] == NSOnState;
	gPreferences.mPlaybackSettings.mClockSpeed = (int)[[timingRadioButton selectedCell] tag];

	BOOL optimizationChanged = oldOptimization != gPreferences.mPlaybackSettings.mOptimization;
	
	if (optimizationChanged)
		[self updateStateOfPlaybackControls:YES];

	PlayerLibSidplay* player = [ownerWindow player];
	AudioDriver* audioDriver = [ownerWindow audioDriver];
	bool isPlaying = audioDriver->getIsPlaying();
	if (isPlaying)
		audioDriver->stopPlayback();
	player->initEmuEngine(&gPreferences.mPlaybackSettings);
	player->initCurrentSubtune();
	if (isPlaying)
		audioDriver->startPlayback();
		
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPlaybackSettingsChangedNotification object:self];
}


// ----------------------------------------------------------------------------
- (IBAction) rebuildSpotlightIndex:(id)sender
// ----------------------------------------------------------------------------
{
	NSString* collectionRootPath = [[SPCollectionUtilities sharedInstance] rootPath];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(spotlightRebuildTaskFinished:) name:NSTaskDidTerminateNotification object:nil];	
	rebuildSpotlightTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/mdimport" arguments:[NSArray arrayWithObject:collectionRootPath]];
	[rebuiltSpotlightProgressIndicator startAnimation:self];
}


// ----------------------------------------------------------------------------
- (void) spotlightRebuildTaskFinished:(NSNotification*)aNotification
// ----------------------------------------------------------------------------
{
	NSTask* task = (NSTask*) [aNotification object];
	if (task != rebuildSpotlightTask)
		return;

	rebuildSpotlightTask = nil;
	[rebuiltSpotlightProgressIndicator stopAnimation:self];
}


// ----------------------------------------------------------------------------
- (void) updateTimeTextField:(int)timeInSeconds
// ----------------------------------------------------------------------------
{
	int minutes = timeInSeconds / 60;
	int seconds = timeInSeconds - (minutes * 60);
	
	if (minutes > 99)
		minutes = 99;

	if (seconds > 59)
		seconds = 59;
	
	[timeTextField setStringValue:[NSString stringWithFormat:@"%02d:%02d", minutes, seconds]];
}


// ----------------------------------------------------------------------------
- (IBAction) clickTimeStepper:(id)sender
// ----------------------------------------------------------------------------
{
	NSInteger timeInSeconds = [sender integerValue];
	gPreferences.mDefaultPlayTime = (int)timeInSeconds;
	[self updateTimeTextField:(int)timeInSeconds];
}


// ----------------------------------------------------------------------------
- (void) timeChangedNotification:(NSNotification*)notification
// ----------------------------------------------------------------------------
{
	if ([notification object] == timeTextField)
		[self timeChanged:timeTextField];
}


// ----------------------------------------------------------------------------
- (IBAction) timeChanged:(id)sender
// ----------------------------------------------------------------------------
{
	NSTextField* textField = sender != nil ? sender : timeTextField;

	NSString* timeString = [textField stringValue];
	if ([timeString length] == 5 && [timeString characterAtIndex:2] == ':')
	{
		NSString* minutesString = [timeString substringToIndex:2];
		NSString* secondsString = [timeString substringFromIndex:3];

		int minutes = [minutesString intValue];
		int seconds = [secondsString intValue];
		
		NSUInteger timeInSeconds = minutes * 60 + seconds;
		gPreferences.mDefaultPlayTime = (int)timeInSeconds;
		[timeStepper setIntegerValue:timeInSeconds];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) clickHideStilBrowserButton:(id)sender
// ----------------------------------------------------------------------------
{
	gPreferences.mHideStilBrowserOnLinkClicked = [sender state] == NSOnState;
}


// ----------------------------------------------------------------------------
- (IBAction) refreshRsyncMirrorsList:(id)sender
// ----------------------------------------------------------------------------
{
	[[SPCollectionUtilities sharedInstance] downloadRsyncMirrorsListAndNotify:@selector(fillRsyncMirrorPopupMenu) ofTarget:self];
}


// ----------------------------------------------------------------------------
- (void) fillRsyncMirrorPopupMenu
// ----------------------------------------------------------------------------
{
	BOOL preferredMirrorExists = NO;
	
	NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
	NSMutableArray* rsyncMirrorList = [[SPCollectionUtilities sharedInstance] rsyncMirrorList];
	
	for (NSString* rsyncMirror in rsyncMirrorList)
	{
		if ([rsyncMirror isEqualToString:gPreferences.mSyncUrl])
			preferredMirrorExists = YES;
		
		NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:rsyncMirror action:@selector(selectRsyncMirror:) keyEquivalent:@""];
		[menuItem setTarget:self];
		
		[menu addItem:menuItem];
	}
	
	[syncUrlPopup setMenu:menu];
	if (preferredMirrorExists)
		[syncUrlPopup selectItemWithTitle:gPreferences.mSyncUrl];
	else
		[syncUrlPopup selectItemAtIndex:0];
}


// ----------------------------------------------------------------------------
- (IBAction) clickAutoSyncButton:(id)sender
// ----------------------------------------------------------------------------
{
	gPreferences.mSyncAutomatically = [sender state] == NSOnState;
}


// ----------------------------------------------------------------------------
- (IBAction) selectAutoSyncInterval:(id)sender
// ----------------------------------------------------------------------------
{
	gPreferences.mSyncInterval = (SPSyncInterval) [sender tag];
}


// ----------------------------------------------------------------------------
- (IBAction) selectRsyncMirror:(id)sender
// ----------------------------------------------------------------------------
{
	gPreferences.mSyncUrl = [[sender title] mutableCopy];
}


// ----------------------------------------------------------------------------
- (void) fillSharedCollectionsPopup
// ----------------------------------------------------------------------------
{
	BOOL preferredCollectionExists = NO;

	NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
	SPSourceListItem* collectionsContainer = [sourceListDataSource collectionsContainerItem];
	if (collectionsContainer == nil)
		return;
	
	NSMutableArray* collectionItems = [collectionsContainer children];
	if ([collectionItems count] == 0)
	{
		[sharedCollectionsPopup setMenu:menu];
		return;
	}
	
	for (SPSourceListItem* collectionItem in collectionItems)
	{
		NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:[[collectionItem name] string] action:@selector(selectCollectionToShare:) keyEquivalent:@""];

		[menuItem setTarget:self];
		[menuItem setRepresentedObject:collectionItem];
		
		if ([[collectionItem path] caseInsensitiveCompare:gPreferences.mSharedCollectionPath] == NSOrderedSame)
		{
			preferredCollectionExists = YES;
			[menuItem setTag:1];
		}
		
		[menu addItem:menuItem];
	}
	
	[sharedCollectionsPopup setMenu:menu];
	if (preferredCollectionExists)
		[sharedCollectionsPopup selectItemWithTag:1];
	else
	{
		[sharedCollectionsPopup selectItemAtIndex:0];
		gPreferences.mSharedCollectionPath = [[[sharedCollectionsPopup itemAtIndex:0] representedObject] path];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) selectCollectionToShare:(id)sender
// ----------------------------------------------------------------------------
{
	SPSourceListItem* collectionItem = [sender representedObject];
	if (collectionItem == nil)
		return;
	
	//gPreferences.mSharedCollectionPath = [collectionItem path];
	//[sourceListDataSource publishSharedCollection:collectionItem];
}


// ----------------------------------------------------------------------------
- (IBAction) clickSearchForSharedCollectionsButton:(id)sender
// ----------------------------------------------------------------------------
{
	//gPreferences.mSearchForSharedCollections = [sender state] == NSOnState;
	//[sourceListDataSource searchForSharedCollections:gPreferences.mSearchForSharedCollections];
}


// ----------------------------------------------------------------------------
- (IBAction) clickPublishSharedCollectionButton:(id)sender
// ----------------------------------------------------------------------------
{
//	gPreferences.mPublishSharedCollection = [sender state] == NSOnState;
//	if (gPreferences.mPublishSharedCollection)
//		[sourceListDataSource publishSharedCollectionWithPath:gPreferences.mSharedCollectionPath];
//	else
//		[sourceListDataSource publishSharedCollectionWithPath:nil];
	
	[sharedCollectionsPopup setEnabled:gPreferences.mPublishSharedCollection];
}


// ----------------------------------------------------------------------------
- (IBAction) clickShareAllPlaylistsRadioButton:(id)sender
// ----------------------------------------------------------------------------
{
//	gPreferences.mShareAllPlaylists = [[sender selectedCell] tag];
//	[sharedPlaylistsTableView setEnabled:!gPreferences.mShareAllPlaylists];
//
//	[sourceListDataSource bumpUpdateRevision];
}


#pragma mark -
#pragma mark data source methods

// ----------------------------------------------------------------------------
- (int)numberOfRowsInTableView:(NSTableView*)tableView
// ----------------------------------------------------------------------------
{
	SPSourceListItem* playlistsContainerItem = [sourceListDataSource playlistsContainerItem];
	
    return (int)[[playlistsContainerItem children] count];
}


// ----------------------------------------------------------------------------
- (id)tableView:(NSTableView*)tableView objectValueForTableColumn:(NSTableColumn*)tableColumn row:(int)rowIndex
// ----------------------------------------------------------------------------
{
	SPSourceListItem* playlistsContainerItem = [sourceListDataSource playlistsContainerItem];
	SPSourceListItem* playlistItem = [playlistsContainerItem childAtIndex:rowIndex];
	SPPlaylist* playlist = [playlistItem playlist];
	if (playlist == nil)
		return @"";
	
	if ([[tableColumn identifier] isEqualToString:@"checkbox"])
	{
		//NSLog(@"shared: %@\n", gPreferences.mSharedPlaylists);
		BOOL isShared = [gPreferences.mSharedPlaylists containsObject:[playlist identifier]];
		return [NSNumber numberWithInt:isShared ? NSOnState : NSOffState];
	}
	else if ([[tableColumn identifier] isEqualToString:@"playlistname"])
	{
		if (playlist != nil)
			return [playlist name];
	}
	
	return @"";
}


// ----------------------------------------------------------------------------
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
// ----------------------------------------------------------------------------
{
	if ([[tableColumn identifier] isEqualToString:@"checkbox"])
	{
		SPSourceListItem* playlistsContainerItem = [sourceListDataSource playlistsContainerItem];
		SPSourceListItem* playlistItem = [playlistsContainerItem childAtIndex:(int)rowIndex];
		SPPlaylist* playlist = [playlistItem playlist];
		NSString* identifier = [playlist identifier];
		
		if ([anObject boolValue])
		{
			if (![gPreferences.mSharedPlaylists containsObject:identifier])
				[gPreferences.mSharedPlaylists addObject:identifier];
		}
		else
			[gPreferences.mSharedPlaylists removeObject:identifier];
		
		//[sourceListDataSource bumpUpdateRevision];
	}
}


// ----------------------------------------------------------------------------
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
// ----------------------------------------------------------------------------
{
	if ([[tableColumn identifier] isEqualToString:@"checkbox"])
		return YES;
	else
		return NO;
}


@end


@implementation SPSharedPlaylistsTableView

// ----------------------------------------------------------------------------
- (id)_highlightColorForCell:(NSCell *)cell
// ----------------------------------------------------------------------------
{
	return [NSColor whiteColor];
}


/*
// ----------------------------------------------------------------------------
- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend
// ----------------------------------------------------------------------------
{
	[super selectRowIndexes:indexes byExtendingSelection:extend];
	
	if ([indexes count] == 1)
	{
		NSTableColumn* column = [self tableColumnWithIdentifier:@"checkbox"];
		BOOL currentValue = [[[self dataSource] tableView:self objectValueForTableColumn:column row:[indexes firstIndex]] boolValue];
		NSNumber* value = [NSNumber numberWithBool:!currentValue];
		[[self dataSource] tableView:self setObjectValue:value forTableColumn:column row:[indexes firstIndex]];
	}
}
*/

@end
