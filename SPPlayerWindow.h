#import <Cocoa/Cocoa.h>
#import "PlayerLibSidplay.h"
#import "SPExporter.h"


// Forward declares
class AudioDriver;
@class SPStatusDisplayView;
@class SPInfoWindowController;
@class SPInfoContainerView;
@class SPStilBrowserController;
@class SPPreferencesWindowController;
@class SPBrowserDataSource;
@class SPSourceListDataSource;
@class SPExportController;
@class SPGradientBox;
@class SPMiniPlayerWindow;
@class SPVisualizerView;
@class SPRemixKwedOrgController;


extern NSString* SPTuneChangedNotification;
extern NSString* SPPlayerInitializedNotification;

extern NSString* SPUrlRequestUserAgentString;


@interface SPPlayerWindow : NSWindow <NSSplitViewDelegate>
{
    IBOutlet id leftView;
    IBOutlet id rightView;
	IBOutlet NSSplitView* splitView;
	IBOutlet id infoView;
	IBOutlet SPBrowserDataSource* browserDataSource;
	IBOutlet NSScrollView* browserScrollView;
	IBOutlet SPSourceListDataSource* sourceListDataSource;
	IBOutlet SPGradientBox* boxView;
	
	IBOutlet NSButton* playPauseButton;
	IBOutlet NSSlider* volumeSlider;
	IBOutlet NSSlider* tempoSlider;
	IBOutlet SPStatusDisplayView* statusDisplay;
	
	IBOutlet NSPanel* openUrlSheetPanel;
	IBOutlet NSTextField* openUrlTextField;
	
	IBOutlet NSButton* addPlaylistButton;
	IBOutlet NSButton* addSmartPlaylistButton;
	
	IBOutlet NSMenu* dockTileMenu;
	
	IBOutlet SPExportController* exportController;
	
	IBOutlet NSButton* miniPlayPauseButton;
	IBOutlet NSSlider* miniVolumeSlider;
	IBOutlet SPStatusDisplayView* miniStatusDisplay;

    IBOutlet NSMenuItem* mainWindowMenuItem;
    IBOutlet NSMenuItem* infoWindowMenuItem;
	IBOutlet NSMenuItem* stilBrowserMenuItem;
	IBOutlet NSMenuItem* analyzerWindowMenuItem;
	IBOutlet NSMenuItem* exportTaskWindowMenuItem;
	
	PlayerLibSidplay* player;
	AudioDriver* audioDriver;
	NSString* currentTunePath;
	NSInteger currentTuneLengthInSeconds;
	CGFloat currentVolume;
	BOOL volumeIsMuted;
	BOOL fadeOutInProgress;
	float fadeOutVolume;
	
	NSDate* lastBufferUnderrunCheckReset;
	
	NSMutableData* urlDownloadData;
	NSURLConnection* urlDownloadConnection;
	NSInteger urlDownloadSubtuneIndex;
	
	SPInfoWindowController* infoWindowController;
	SPStilBrowserController* stilBrowserController;
	SPPreferencesWindowController* prefsWindowController;
	
	SPVisualizerView* visualizerView;
	NSMutableArray* visualizerCompositionPaths;
	IBOutlet NSMenu* visualizerMenu;
	
	IBOutlet NSMenu* subtuneSelectionMenu;
	
	IBOutlet SPRemixKwedOrgController* remixKwedOrgController;
    
    IBOutlet NSMenuItem* checkForUpdatesMenuItem;
}

- (void) playTuneAtPath:(NSString*)path;
- (void) playTuneAtPath:(NSString*)path subtune:(int)subtuneIndex;
- (void) playTuneAtURL:(NSString*)urlString;
- (void) playTuneAtURL:(NSString*)urlString subtune:(int)subtuneIndex;

- (void) setPlayPauseButtonToPause:(BOOL)pause;
- (void) switchToSubtune:(NSInteger)subtune;
- (void) updateTimer;
- (void) updateFastTimer;
- (void) updateSlowTimer;
- (void) updateTuneInfo;
@property (NS_NONATOMIC_IOSONLY) float fadeVolume;
- (void) startFadeOut;
- (void) stopFadeOut;

@property (NS_NONATOMIC_IOSONLY, readonly) AudioDriver *audioDriver;
@property (NS_NONATOMIC_IOSONLY, readonly) PlayerLibSidplay *player;

- (void) addInfoContainerView:(NSScrollView*)infoContainerScrollView;

- (void) addTopSubView:(NSView*)subView withHeight:(float)height;
- (void) removeTopSubView;

- (void) addRightSubView:(NSView*)subView withWidth:(float)width;
- (void) removeRightSubView;

- (void) addAlternateBoxView:(NSView*)subView;

@property (NS_NONATOMIC_IOSONLY, readonly, strong) SPBrowserDataSource *browserDataSource;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) SPExportController *exportController;
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger currentTuneLengthInSeconds;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMenuItem *mainWindowMenuItem;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMenuItem *infoWindowMenuItem;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMenuItem *stilBrowserMenuItem;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMenuItem *analyzerWindowMenuItem;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMenuItem *exportTaskWindowMenuItem;

@property (NS_NONATOMIC_IOSONLY, strong) SPStatusDisplayView *statusDisplay;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) SPStatusDisplayView *miniStatusDisplay;

@property (NS_NONATOMIC_IOSONLY, readonly, strong) SPRemixKwedOrgController *remixKwedOrgController;

- (void) populateVisualizerMenu;

- (IBAction) clickPlayPauseButton:(id)sender;
- (IBAction) clickStopButton:(id)sender;
- (IBAction) clickFastForwardButton:(id)sender;
- (IBAction) moveTempoSlider:(id)sender;
- (IBAction) moveVolumeSlider:(id)sender;
- (IBAction) increaseVolume:(id)sender;
- (IBAction) decreaseVolume:(id)sender;
- (IBAction) muteVolume:(id)sender;
- (IBAction) nextSubtune:(id)sender;
- (IBAction) previousSubtune:(id)sender;
- (IBAction) selectSubtune:(id)sender;

- (IBAction) showMainWindow:(id)sender;
- (IBAction) toggleInfoWindow:(id)sender;
- (IBAction) toggleInfoPane:(id)sender;
- (IBAction) toggleStilBrowser:(id)sender;
- (IBAction) toggleAnalyzer:(id)sender;
- (IBAction) moveFocusToSearchField:(id)sender;

- (IBAction) openFile:(id)sender;
- (IBAction) openUrl:(id)sender;
- (IBAction) dismissOpenUrlSheet:(id)sender;

- (IBAction) openSidplayHomepage:(id)sender;
- (IBAction) openHvscHomepage:(id)sender;

- (IBAction) showPreferencesWindow:(id)sender;
- (IBAction) playRandomTuneFromCollection:(id)sender;

- (IBAction) toggleVisualizerView:(id)sender;
- (IBAction) selectVisualizer:(id)sender;

@end


@interface SPWindowDelegate : NSObject
{
	IBOutlet SPPlayerWindow* mainPlayerWindow;
	IBOutlet SPMiniPlayerWindow* miniPlayerPanel;
}

- (BOOL) windowShouldZoom:(NSWindow *)window toFrame:(NSRect)proposedFrame;
@end
