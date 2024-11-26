#import "SPPreferencesController.h"
#import "SPPlayerWindow.h"
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
static NSString* SPDefaultKeyRepeatSingleActive             = @"RepeatSingleActive";
static NSString* SPDefaultKeyAllSubSongsActive              = @"AllSubSongsActive";
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

Preferences*	gPreferences;

@implementation Preferences

@synthesize    mPlaybackVolume;
@synthesize       mCollections;
@synthesize     mSearchType;
@synthesize    mInfoWindowVisible;
@synthesize    mTuneInfoCollapsed;
@synthesize    mOscilloscopeCollapsed;
@synthesize    mSidRegistersCollapsed;
@synthesize    mMixerCollapsed;
@synthesize    mFilterControlCollapsed;
@synthesize    mComposerPhotoCollapsed;
@synthesize    mLegacyPlaylistsMigrated;
@synthesize    mShuffleActive;
@synthesize    mFadeActive;
@synthesize    mRepeatActive;
@synthesize   mRepeatSingleActive;
@synthesize   mAllSubSongsActive;
@synthesize       mDefaultPlayTime;
@synthesize    mHideStilBrowserOnLinkClicked;
@synthesize     mSyncUrl;
@synthesize    mSyncAutomatically;
@synthesize       mLastSyncTime;
@synthesize       mSyncInterval;
@synthesize    mSearchForSharedCollections;
@synthesize    mPublishSharedCollection;
@synthesize     mSharedCollectionPath;
@synthesize    mShareAllPlaylists;
@synthesize       mSharedPlaylists;
@synthesize       mUpdateRevision;


// ----------------------------------------------------------------------------
-(void) initializeDefaults
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
    mRepeatSingleActive = NO;
    mAllSubSongsActive = NO;
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

    // manual override of SID model, not saved/loaded
    mPlaybackSettings.SIDselectorOverrideActive = NO;
    mPlaybackSettings.SIDselectorOverrideModel = 0;
    
    
    [self resetFilterDefaults];
}

// ----------------------------------------------------------------------------
-(void) resetFilterDefaults
{
    mPlaybackSettings.mFilterType = SID_FILTER_6581_Resid;
    [self setDistortionParametersBasedOnFilterType];

    mPlaybackSettings.mEnableFilterDistortion = true;

    mCustomFilterSettings = mPlaybackSettings;
}

// ----------------------------------------------------------------------------
-(void) setDistortionParametersBasedOnFilterType
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
- (void)    copyPlaybackSettings:(struct PlaybackSettings*)pbSettings
{
    mPlaybackSettings.mFrequency                = pbSettings->mFrequency;
    mPlaybackSettings.mBits                     = pbSettings->mBits;
    mPlaybackSettings.mStereo                   = pbSettings->mStereo;

    mPlaybackSettings.mOversampling             = pbSettings->mOversampling;
    mPlaybackSettings.mSidModel                 = pbSettings->mSidModel;
    mPlaybackSettings.mForceSidModel            = pbSettings->mForceSidModel;
    mPlaybackSettings.mClockSpeed               = pbSettings->mClockSpeed;
    mPlaybackSettings.mOptimization             = pbSettings->mOptimization;

    mPlaybackSettings.mFilterKinkiness          = pbSettings->mFilterKinkiness;
    mPlaybackSettings.mFilterBaseLevel          = pbSettings->mFilterBaseLevel;
    mPlaybackSettings.mFilterOffset             = pbSettings->mFilterOffset;
    mPlaybackSettings.mFilterOffset             = pbSettings->mFilterSteepness;
    mPlaybackSettings.mFilterRolloff            = pbSettings->mFilterRolloff;
    mPlaybackSettings.mFilterType               = pbSettings->mFilterType;

    mPlaybackSettings.mEnableFilterDistortion   = pbSettings->mEnableFilterDistortion;
    mPlaybackSettings.mDistortionRate           = pbSettings->mDistortionRate;
    mPlaybackSettings.mDistortionHeadroom       = pbSettings->mDistortionHeadroom;

    mPlaybackSettings.SIDselectorOverrideActive = pbSettings->SIDselectorOverrideActive;
    mPlaybackSettings.SIDselectorOverrideModel  = pbSettings->SIDselectorOverrideModel;
}

- (void)    copyCustomFilterSettings:(struct PlaybackSettings*)filterSettings
{
    mCustomFilterSettings.mFrequency                = filterSettings->mFrequency;
    mCustomFilterSettings.mBits                     = filterSettings->mBits;
    mCustomFilterSettings.mStereo                   = filterSettings->mStereo;

    mCustomFilterSettings.mOversampling             = filterSettings->mOversampling;
    mCustomFilterSettings.mSidModel                 = filterSettings->mSidModel;
    mCustomFilterSettings.mForceSidModel            = filterSettings->mForceSidModel;
    mCustomFilterSettings.mClockSpeed               = filterSettings->mClockSpeed;
    mCustomFilterSettings.mOptimization             = filterSettings->mOptimization;

    mCustomFilterSettings.mFilterKinkiness          = filterSettings->mFilterKinkiness;
    mCustomFilterSettings.mFilterBaseLevel          = filterSettings->mFilterBaseLevel;
    mCustomFilterSettings.mFilterOffset             = filterSettings->mFilterOffset;
    mCustomFilterSettings.mFilterOffset             = filterSettings->mFilterSteepness;
    mCustomFilterSettings.mFilterRolloff            = filterSettings->mFilterRolloff;
    mCustomFilterSettings.mFilterType               = filterSettings->mFilterType;

    mCustomFilterSettings.mEnableFilterDistortion   = filterSettings->mEnableFilterDistortion;
    mCustomFilterSettings.mDistortionRate           = filterSettings->mDistortionRate;
    mCustomFilterSettings.mDistortionHeadroom       = filterSettings->mDistortionHeadroom;

    mCustomFilterSettings.SIDselectorOverrideActive = filterSettings->SIDselectorOverrideActive;
    mCustomFilterSettings.SIDselectorOverrideModel  = filterSettings->SIDselectorOverrideModel;
}
- (void)    getPlaybackSettings:(struct PlaybackSettings*)pbSettings
{
    pbSettings->mFrequency                = mPlaybackSettings.mFrequency;
    pbSettings->mBits                     = mPlaybackSettings.mBits;
    pbSettings->mStereo                   = mPlaybackSettings.mStereo;

    pbSettings->mOversampling             = mPlaybackSettings.mOversampling;
    pbSettings->mSidModel                 = mPlaybackSettings.mSidModel;
    pbSettings->mForceSidModel            = mPlaybackSettings.mForceSidModel;
    pbSettings->mClockSpeed               = mPlaybackSettings.mClockSpeed;
    pbSettings->mOptimization             = mPlaybackSettings.mOptimization;

    pbSettings->mFilterKinkiness          = mPlaybackSettings.mFilterKinkiness;
    pbSettings->mFilterBaseLevel          = mPlaybackSettings.mFilterBaseLevel;
    pbSettings->mFilterOffset             = mPlaybackSettings.mFilterOffset;
    pbSettings->mFilterOffset             = mPlaybackSettings.mFilterSteepness;
    pbSettings->mFilterRolloff            = mPlaybackSettings.mFilterRolloff;
    pbSettings->mFilterType               = mPlaybackSettings.mFilterType;

    pbSettings->mEnableFilterDistortion   = mPlaybackSettings.mEnableFilterDistortion;
    pbSettings->mDistortionRate           = mPlaybackSettings.mDistortionRate;
    pbSettings->mDistortionHeadroom       = mPlaybackSettings.mDistortionHeadroom;

    pbSettings->SIDselectorOverrideActive = mPlaybackSettings.SIDselectorOverrideActive;
    pbSettings->SIDselectorOverrideModel  = mPlaybackSettings.SIDselectorOverrideModel;
}

- (void)    getCustomFilterSettings:(struct PlaybackSettings*)filterSettings
{
    filterSettings->mFrequency                = mCustomFilterSettings.mFrequency;
    filterSettings->mBits                     = mCustomFilterSettings.mBits;
    filterSettings->mStereo                   = mCustomFilterSettings.mStereo;

    filterSettings->mOversampling             = mCustomFilterSettings.mOversampling;
    filterSettings->mSidModel                 = mCustomFilterSettings.mSidModel;
    filterSettings->mForceSidModel            = mCustomFilterSettings.mForceSidModel;
    filterSettings->mClockSpeed               = mCustomFilterSettings.mClockSpeed;
    filterSettings->mOptimization             = mCustomFilterSettings.mOptimization;

    filterSettings->mFilterKinkiness          = mCustomFilterSettings.mFilterKinkiness;
    filterSettings->mFilterBaseLevel          = mCustomFilterSettings.mFilterBaseLevel;
    filterSettings->mFilterOffset             = mCustomFilterSettings.mFilterOffset;
    filterSettings->mFilterOffset             = mCustomFilterSettings.mFilterSteepness;
    filterSettings->mFilterRolloff            = mCustomFilterSettings.mFilterRolloff;
    filterSettings->mFilterType               = mCustomFilterSettings.mFilterType;

    filterSettings->mEnableFilterDistortion   = mCustomFilterSettings.mEnableFilterDistortion;
    filterSettings->mDistortionRate           = mCustomFilterSettings.mDistortionRate;
    filterSettings->mDistortionHeadroom       = mCustomFilterSettings.mDistortionHeadroom;

    filterSettings->SIDselectorOverrideActive = mCustomFilterSettings.SIDselectorOverrideActive;
    filterSettings->SIDselectorOverrideModel  = mCustomFilterSettings.SIDselectorOverrideModel;
}
@end
@implementation SPPreferencesController

static SPPreferencesController* sharedInstance = nil;


// ----------------------------------------------------------------------------
+ (void) initialize
// ----------------------------------------------------------------------------
{
    gPreferences = [[Preferences alloc] init];
    [gPreferences initializeDefaults];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *appDefaults = [[NSMutableDictionary alloc] init];
    
    appDefaults[SPDefaultKeyCollections] = [[NSArray alloc] init];
    appDefaults[SPDefaultKeyVolume] = @(gPreferences.mPlaybackVolume);
    appDefaults[SPDefaultKeySearchType] = [NSNumber numberWithInt:gPreferences.mSearchType];

    appDefaults[SPDefaultKeyInfoWindowVisible] = @(gPreferences.mInfoWindowVisible);
    appDefaults[SPDefaultKeyTuneInfoCollapsed] = @(gPreferences.mTuneInfoCollapsed);
    appDefaults[SPDefaultKeyOscilloscopeCollapsed] = @(gPreferences.mOscilloscopeCollapsed);
    appDefaults[SPDefaultKeySidRegistersCollapsed] = @(gPreferences.mSidRegistersCollapsed);
    appDefaults[SPDefaultKeyMixerCollapsed] = @(gPreferences.mMixerCollapsed);
    appDefaults[SPDefaultKeyFilterControlCollapsed] = @(gPreferences.mFilterControlCollapsed);
    appDefaults[SPDefaultKeyComposerPhotoCollapsed] = @(gPreferences.mComposerPhotoCollapsed);
    appDefaults[SPDefaultKeyLegacyPlaylistsMigrated] = @(gPreferences.mLegacyPlaylistsMigrated);
    appDefaults[SPDefaultKeyShuffleActive] = @(gPreferences.mShuffleActive);
    appDefaults[SPDefaultKeyFadeActive] = @(gPreferences.mFadeActive);
    appDefaults[SPDefaultKeyRepeatActive] = @(gPreferences.mRepeatActive);
    appDefaults[SPDefaultKeyRepeatSingleActive] = @(gPreferences.mRepeatSingleActive);

    appDefaults[SPDefaultKeyAllSubSongsActive] =@(gPreferences.mAllSubSongsActive);
    appDefaults[SPDefaultKeyPlayTime] = @(gPreferences.mDefaultPlayTime);
    appDefaults[SPDefaultKeyHideStilBrowserAutomatically] = @(gPreferences.mHideStilBrowserOnLinkClicked);

    appDefaults[SPDefaultKeySyncUrl] = SPDefaultRsyncUrl;
    appDefaults[SPDefaultKeyAutoSync] = @(gPreferences.mSyncAutomatically);
    appDefaults[SPDefaultKeyLastSyncTime] = gPreferences.mLastSyncTime;
    appDefaults[SPDefaultKeySyncInterval] = [NSNumber numberWithInt:gPreferences.mSyncInterval];

    appDefaults[SPDefaultKeySearchForSharedCollections] = @(gPreferences.mSearchForSharedCollections);
    appDefaults[SPDefaultKeyPublishSharedCollection] = @(gPreferences.mPublishSharedCollection);
    appDefaults[SPDefaultKeySharedCollectionPath] = @"";
    appDefaults[SPDefaultKeyShareAllPlaylists] = @(gPreferences.mShareAllPlaylists);
    appDefaults[SPDefaultKeySharedPlaylists] = [[NSArray alloc] init];
    appDefaults[SPDefaultKeyUpdateRevision] = @(gPreferences.mUpdateRevision);

    struct PlaybackSettings dummySettings;
    [gPreferences getPlaybackSettings:&dummySettings];
    appDefaults[SPDefaultKeyEnableFilterDistortion] = [NSNumber numberWithBool:dummySettings.mEnableFilterDistortion];
    appDefaults[SPDefaultKeyOversampling] = @(dummySettings.mOversampling);
    appDefaults[SPDefaultKeySidModel] = @(dummySettings.mSidModel);
    appDefaults[SPDefaultKeyForceSidModel] = @(dummySettings.mForceSidModel);
    appDefaults[SPDefaultKeyTiming] = @(dummySettings.mClockSpeed);
    appDefaults[SPDefaultKeyOptimization] = @(dummySettings.mOptimization);
    appDefaults[SPDefaultKeyFilterType] = [NSNumber numberWithInt:dummySettings.mFilterType];

    [gPreferences getCustomFilterSettings:&dummySettings];
    appDefaults[SPDefaultKeyFilterSteepness] = @(dummySettings.mFilterSteepness);
    appDefaults[SPDefaultKeyFilterOffset] = @(dummySettings.mFilterOffset);
    appDefaults[SPDefaultKeyFilterDistortionRate] = @(dummySettings.mDistortionRate);
    appDefaults[SPDefaultKeyFilterDistortionHeadroom] = @(dummySettings.mDistortionHeadroom);

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
- (instancetype) init
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
    gPreferences.mSearchType = (enum SPSearchType) [defaults integerForKey:SPDefaultKeySearchType];
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
    gPreferences.mRepeatSingleActive = [defaults boolForKey:SPDefaultKeyRepeatSingleActive];
    gPreferences.mAllSubSongsActive = [defaults boolForKey:SPDefaultKeyAllSubSongsActive];
    gPreferences.mDefaultPlayTime = (int)[defaults integerForKey:SPDefaultKeyPlayTime];
    gPreferences.mHideStilBrowserOnLinkClicked = [defaults boolForKey:SPDefaultKeyHideStilBrowserAutomatically];

    gPreferences.mSyncUrl = [[defaults stringForKey:SPDefaultKeySyncUrl] mutableCopy];
    gPreferences.mSyncAutomatically = [defaults boolForKey:SPDefaultKeyAutoSync];
    gPreferences.mLastSyncTime = [defaults objectForKey:SPDefaultKeyLastSyncTime];
    gPreferences.mSyncInterval = (enum SPSyncInterval) [defaults integerForKey:SPDefaultKeySyncInterval];

    gPreferences.mSearchForSharedCollections = [defaults boolForKey:SPDefaultKeySearchForSharedCollections];
    gPreferences.mPublishSharedCollection = [defaults boolForKey:SPDefaultKeyPublishSharedCollection];
    gPreferences.mSharedCollectionPath = [[defaults stringForKey:SPDefaultKeySharedCollectionPath] mutableCopy];
    gPreferences.mShareAllPlaylists = [defaults boolForKey:SPDefaultKeyShareAllPlaylists];
    gPreferences.mSharedPlaylists = [[defaults arrayForKey:SPDefaultKeySharedPlaylists] mutableCopy];
    gPreferences.mUpdateRevision = (int)[defaults integerForKey:SPDefaultKeyUpdateRevision];

    struct PlaybackSettings dummy;
    [gPreferences getPlaybackSettings:&dummy];
    dummy.mEnableFilterDistortion = [defaults boolForKey:SPDefaultKeyEnableFilterDistortion];
    dummy.mOversampling = (int)[defaults integerForKey:SPDefaultKeyOversampling];
    dummy.mSidModel = (int)[defaults integerForKey:SPDefaultKeySidModel];
    dummy.mForceSidModel = [defaults boolForKey:SPDefaultKeyForceSidModel];
    dummy.mClockSpeed = (int)[defaults integerForKey:SPDefaultKeyTiming];
    dummy.mOptimization = (int)[defaults integerForKey:SPDefaultKeyOptimization];
    dummy.mFilterType = (enum SPFilterType) [defaults integerForKey:SPDefaultKeyFilterType];
    [gPreferences copyPlaybackSettings:&dummy];
    
    [gPreferences getCustomFilterSettings:&dummy];
    dummy.mFilterSteepness = [defaults floatForKey:SPDefaultKeyFilterSteepness];
    dummy.mFilterOffset = [defaults floatForKey:SPDefaultKeyFilterOffset];
    dummy.mDistortionRate = (int)[defaults integerForKey:SPDefaultKeyFilterDistortionRate];
    dummy.mDistortionHeadroom = (int)[defaults integerForKey:SPDefaultKeyFilterDistortionHeadroom];
    [gPreferences copyCustomFilterSettings:&dummy];
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
    [defaults setBool:gPreferences.mAllSubSongsActive forKey:SPDefaultKeyAllSubSongsActive];
    [defaults setBool:gPreferences.mRepeatActive forKey:SPDefaultKeyRepeatActive];
    [defaults setBool:gPreferences.mRepeatSingleActive forKey:SPDefaultKeyRepeatSingleActive];
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

    struct PlaybackSettings dummy;
    [gPreferences getPlaybackSettings:&dummy];
    [defaults setBool:dummy.mEnableFilterDistortion forKey:SPDefaultKeyEnableFilterDistortion];
    [defaults setInteger:dummy.mOversampling forKey:SPDefaultKeyOversampling];
    [defaults setInteger:dummy.mSidModel forKey:SPDefaultKeySidModel];
    [defaults setBool:dummy.mForceSidModel forKey:SPDefaultKeyForceSidModel];
    [defaults setInteger:dummy.mClockSpeed forKey:SPDefaultKeyTiming];
    [defaults setInteger:dummy.mOptimization forKey:SPDefaultKeyOptimization];
    [defaults setInteger:dummy.mFilterType forKey:SPDefaultKeyFilterType];

    [gPreferences getCustomFilterSettings:&dummy];
    [defaults setFloat:dummy.mFilterSteepness forKey:SPDefaultKeyFilterSteepness];
    [defaults setFloat:dummy.mFilterOffset forKey:SPDefaultKeyFilterOffset];
    [defaults setInteger:dummy.mDistortionRate forKey:SPDefaultKeyFilterDistortionRate];
    [defaults setInteger:dummy.mDistortionHeadroom forKey:SPDefaultKeyFilterDistortionHeadroom];

    [defaults synchronize];
}


// ----------------------------------------------------------------------------
- (void) initializeFilterSettingsFromChipModelOfPlayer:(PlayerLibSidplayWrapper*)player
// ----------------------------------------------------------------------------
{
    static enum SPFilterType oldFilterType = SID_FILTER_6581_Resid;

    bool use8580 = false;
    struct PlaybackSettings dummy;
    
    [gPreferences getPlaybackSettings:&dummy];
    if (dummy.mForceSidModel)
    {
        if (dummy.mSidModel == 1)
            use8580 = true;
        else
            use8580 = false;
    }
    else
    {
        if (player && [player getCurrentChipModel] == [player sChipModel8580])
            use8580 = true;
        else
            use8580 = false;
    }
    // manual override
    if (dummy.SIDselectorOverrideActive) {
        if (dummy.SIDselectorOverrideModel == 1) {
            use8580 = true;
        }
        else {
            use8580 = false;
        }
    }

    enum SPFilterType currentFilterType = dummy.mFilterType;

    if (use8580)
    {
        if (dummy.mFilterType != SID_FILTER_8580)
        {
            oldFilterType = dummy.mFilterType;
            dummy.mFilterType = SID_FILTER_8580;
            [gPreferences copyPlaybackSettings:&dummy];
        }
    }
    else if (dummy.mFilterType == SID_FILTER_8580)
    {
        dummy.mFilterType = oldFilterType;
        [gPreferences copyPlaybackSettings:&dummy];
    }

    if (dummy.mFilterType != currentFilterType)
        [gPreferences setDistortionParametersBasedOnFilterType];
    /* FIXME: filter settings
     sid_filter_t filterSettings;
     PlayerLibSidplay::setFilterSettingsFromPlaybackSettings(filterSettings, &gPreferences.mPlaybackSettings);
     if (player != NULL)
     player->setFilterSettings(&filterSettings);
     */
}


@end


@implementation SPPreferencesWindowController


// ----------------------------------------------------------------------------
- (instancetype) init
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
                                               object:self.window];
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

    struct PlaybackSettings dummy;
    [gPreferences getPlaybackSettings:&dummy];
    
    [optimizationPopup selectItemWithTag:dummy.mOptimization];
    filterDistortionButton.state = dummy.mEnableFilterDistortion ? NSOnState : NSOffState;
    [oversamplingPopup selectItemWithTag:dummy.mOversampling];
    [sidModelRadioButton selectCellWithTag:dummy.mSidModel];
    forceSidModelButton.state = dummy.mForceSidModel ? NSOnState : NSOffState;
    [timingRadioButton selectCellWithTag:dummy.mClockSpeed];
    [self updateStateOfPlaybackControls:NO];

    [self updateTimeTextField:gPreferences.mDefaultPlayTime];
    timeStepper.integerValue = gPreferences.mDefaultPlayTime;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(timeChangedNotification:)
                                                 name:NSControlTextDidChangeNotification
                                               object:nil];

    hideStilBrowserButton.state = gPreferences.mHideStilBrowserOnLinkClicked ? NSOnState : NSOffState;

    [self switchToPreferencePane:PREFS_GENERAL];
    prefsToolbar.selectedItemIdentifier = defaultPrefsPaneItem.itemIdentifier;

    [[NSNotificationCenter defaultCenter] postNotificationName:SPPlaybackSettingsChangedNotification object:self];

    [self refreshRsyncMirrorsList:self];
    autoSyncButton.state = gPreferences.mSyncAutomatically ? NSOnState : NSOffState;
    [autoSyncIntervalPopup selectItemWithTag:gPreferences.mSyncInterval];

    [self fillSharedCollectionsPopup];
    searchForSharedCollectionsButton.state = gPreferences.mSearchForSharedCollections ? NSOnState : NSOffState;
    publishSharedCollectionButton.state = gPreferences.mPublishSharedCollection ? NSOnState : NSOffState;
    sharedCollectionsPopup.enabled = gPreferences.mPublishSharedCollection;
    [playlistSharingRadioButton selectCellWithTag:gPreferences.mShareAllPlaylists];
    sharedPlaylistsTableView.enabled = !gPreferences.mShareAllPlaylists;
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
- (void) switchToPreferencePane:(enum SPPreferencePane)pane
// ----------------------------------------------------------------------------
{
    NSWindow* window = self.window;

    NSView* tempView = [[NSView alloc] initWithFrame:window.contentView.frame];
    window.contentView = tempView;

    NSView* prefsView = preferencePanes[pane];

    NSRect newFrame = window.frame;
    newFrame.size.height = prefsView.frame.size.height + (window.frame.size.height - window.contentView.frame.size.height);
    newFrame.size.width = prefsView.frame.size.width;
    newFrame.origin.y += (window.contentView.frame.size.height - prefsView.frame.size.height);

    [window setFrame:newFrame display:YES animate:YES];
    window.contentView = prefsView;
    window.title = SPPreferencePaneNames[pane];
}


// ----------------------------------------------------------------------------
- (IBAction) toolbarItemClicked:(id)sender
// ----------------------------------------------------------------------------
{
    [self switchToPreferencePane:(enum SPPreferencePane)[sender tag]];
    NSString* identifier = [sender itemIdentifier];
    prefsToolbar.selectedItemIdentifier = identifier;
}


// ----------------------------------------------------------------------------
- (NSArray*) toolbarSelectableItemIdentifiers:(NSToolbar*)toolbar
// ----------------------------------------------------------------------------
{
    NSArray* selectableItems = toolbar.items;
    NSMutableArray* selectableItemIdentifiers = [NSMutableArray arrayWithCapacity:selectableItems.count];
    for (NSToolbarItem* item in selectableItems)
        [selectableItemIdentifiers addObject:item.itemIdentifier];

    return selectableItemIdentifiers;
}


// ----------------------------------------------------------------------------
- (void) updateStateOfPlaybackControls:(BOOL)resetOldState
// ----------------------------------------------------------------------------
{
    static int oldDistortionState = NSOnState;
    static int oldOversamplingFactor = 1;
    struct PlaybackSettings dummy;
    
    [gPreferences getPlaybackSettings:&dummy];
    if (dummy.mOptimization != 0)
    {
        oldDistortionState = (int)filterDistortionButton.state;
        filterDistortionButton.state = NSOffState;
        [filterDistortionButton setEnabled:NO];
        dummy.mEnableFilterDistortion = false;

        if (resetOldState)
        {
            [oversamplingPopup selectItemWithTag:oldOversamplingFactor];
            [oversamplingPopup setEnabled:YES];
            dummy.mOversampling = oldOversamplingFactor;
            [gPreferences copyPlaybackSettings:&dummy];
        }
    }
    else
    {
        if (resetOldState)
        {
            filterDistortionButton.state = oldDistortionState;
            [filterDistortionButton setEnabled:YES];
            dummy.mEnableFilterDistortion = oldDistortionState == NSOnState;
            [gPreferences copyPlaybackSettings:&dummy];
        }

        oldOversamplingFactor = (int)oversamplingPopup.selectedItem.tag;
        [oversamplingPopup selectItemWithTag:1];
        [oversamplingPopup setEnabled:NO];
        dummy.mOversampling = 1;
        [gPreferences copyPlaybackSettings:&dummy];
    }
}


// ----------------------------------------------------------------------------
- (IBAction) playbackSettingsChanged:(id)sender
// ----------------------------------------------------------------------------
{
    struct PlaybackSettings dummy;
    [gPreferences getPlaybackSettings:&dummy];
    
    int oldOptimization = dummy.mOptimization;

    dummy.mOptimization = (int)optimizationPopup.selectedItem.tag;
    dummy.mEnableFilterDistortion = filterDistortionButton.state == NSOnState;
    dummy.mOversampling = (int)oversamplingPopup.selectedItem.tag;
    dummy.mSidModel = (int)sidModelRadioButton.selectedCell.tag;
    dummy.mForceSidModel = forceSidModelButton.state == NSOnState;
    dummy.mClockSpeed = (int)timingRadioButton.selectedCell.tag;

    BOOL optimizationChanged = oldOptimization != dummy.mOptimization;

    if (optimizationChanged)
        [self updateStateOfPlaybackControls:YES];

    [gPreferences copyPlaybackSettings:&dummy];
    PlayerLibSidplayWrapper* player = [ownerWindow player];
    AudioDriver* audioDriver = [ownerWindow audioDriver];
    bool isPlaying = audioDriver->getIsPlaying();
    if (isPlaying)
        audioDriver->stopPlayback();
    [player initEmuEngineWithSettings:&dummy];
    [player initCurrentSubtune];
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
    rebuildSpotlightTask = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/mdimport" arguments:@[collectionRootPath]];
    [rebuiltSpotlightProgressIndicator startAnimation:self];
}


// ----------------------------------------------------------------------------
- (void) spotlightRebuildTaskFinished:(NSNotification*)aNotification
// ----------------------------------------------------------------------------
{
    NSTask* task = (NSTask*) aNotification.object;
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

    timeTextField.stringValue = [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];
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
    if (notification.object == timeTextField)
        [self timeChanged:timeTextField];
}


// ----------------------------------------------------------------------------
- (IBAction) timeChanged:(id)sender
// ----------------------------------------------------------------------------
{
    NSTextField* textField = sender != nil ? sender : timeTextField;

    NSString* timeString = textField.stringValue;
    if (timeString.length == 5 && [timeString characterAtIndex:2] == ':')
    {
        NSString* minutesString = [timeString substringToIndex:2];
        NSString* secondsString = [timeString substringFromIndex:3];

        int minutes = minutesString.intValue;
        int seconds = secondsString.intValue;

        NSUInteger timeInSeconds = minutes * 60 + seconds;
        gPreferences.mDefaultPlayTime = (int)timeInSeconds;
        timeStepper.integerValue = timeInSeconds;
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
        menuItem.target = self;

        [menu addItem:menuItem];
    }

    syncUrlPopup.menu = menu;
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
    gPreferences.mSyncInterval = (enum SPSyncInterval) [sender tag];
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
    if (collectionItems.count == 0)
    {
        sharedCollectionsPopup.menu = menu;
        return;
    }

    for (SPSourceListItem* collectionItem in collectionItems)
    {
        NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:[collectionItem name].string action:@selector(selectCollectionToShare:) keyEquivalent:@""];

        menuItem.target = self;
        menuItem.representedObject = collectionItem;

        if ([[collectionItem path] caseInsensitiveCompare:gPreferences.mSharedCollectionPath] == NSOrderedSame)
        {
            preferredCollectionExists = YES;
            menuItem.tag = 1;
        }

        [menu addItem:menuItem];
    }

    sharedCollectionsPopup.menu = menu;
    if (preferredCollectionExists)
        [sharedCollectionsPopup selectItemWithTag:1];
    else
    {
        [sharedCollectionsPopup selectItemAtIndex:0];
        gPreferences.mSharedCollectionPath = [[sharedCollectionsPopup itemAtIndex:0].representedObject path];
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

    sharedCollectionsPopup.enabled = gPreferences.mPublishSharedCollection;
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

    return (int)[playlistsContainerItem children].count;
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

    if ([tableColumn.identifier isEqualToString:@"checkbox"])
    {
        //NSLog(@"shared: %@\n", gPreferences.mSharedPlaylists);
        BOOL isShared = [gPreferences.mSharedPlaylists containsObject:[playlist identifier]];
        return [NSNumber numberWithInt:isShared ? NSOnState : NSOffState];
    }
    else if ([tableColumn.identifier isEqualToString:@"playlistname"])
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
    if ([tableColumn.identifier isEqualToString:@"checkbox"])
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
    if ([tableColumn.identifier isEqualToString:@"checkbox"])
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
