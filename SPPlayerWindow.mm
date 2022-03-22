#import "SPPlayerWindow.h"
#import "SPStatusDisplayView.h"
#import "SPPreferencesController.h"
#import "SPInfoWindowController.h"
#import "SPStilBrowserController.h"
#import "SPInfoContainerView.h"
#import "SPBrowserDataSource.h"
#import "SPExportController.h"
#import "SongLengthDatabase.h"
#import "SPCollectionUtilities.h"
#import "SPVisualizerView.h"
#import "SPApplicationStorageController.h"
#import "SPSourceListDataSource.h"
#import "SPAnalyzerWindowController.h"
#import "SPRemixKwedOrgController.h"
#import "SPGradientBox.h"
#import "SPMiniPlayerWindow.h"

//#import "AudioQueueDriver.h"
#import "AudioCoreDriver.h"
//#import "AudioSoundManager.h"


NSString* SPTuneChangedNotification = @"SPTuneChangedNotification";
NSString* SPPlayerInitializedNotification = @"SPPlayerInitializedNotification";

NSString* SPUrlRequestUserAgentString = nil;

@implementation SPPlayerWindow

// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[[SPPreferencesController sharedInstance] load];
	[remixKwedOrgController acquireDatabase];
	[remixKwedOrgController setOwnerWindow:self];
	
	if (gPreferences.mInfoWindowVisible)
	{
		infoWindowController = [[SPInfoWindowController alloc] init];
		[infoWindowController setOwnerWindow:self];
	}
	else
		infoWindowController = nil;

	stilBrowserController = nil;
	prefsWindowController = nil;
	analyzerWindowController = nil;
	
	player = new PlayerLibSidplay;
	audioDriver = new AudioCoreDriver;
	player->setAudioDriver(audioDriver);
	
	audioDriver->initialize(player);
	audioDriver->setVolume(gPreferences.mPlaybackVolume);
	gPreferences.mPlaybackSettings.mFrequency = audioDriver->getSampleRate();
	
	sid_filter_t filterSettings;
	PlayerLibSidplay::setFilterSettingsFromPlaybackSettings(filterSettings, &gPreferences.mPlaybackSettings);
	player->setFilterSettings(&filterSettings);
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPlayerInitializedNotification object:self];
	
	volumeSlider.floatValue = gPreferences.mPlaybackVolume * 100.0f;
	miniVolumeSlider.floatValue = gPreferences.mPlaybackVolume * 100.0f;
	volumeIsMuted = NO;
	fadeOutInProgress = NO;
	fadeOutVolume = 1.0f;
	
	currentTunePath = nil;
	currentTuneLengthInSeconds = 0;
	
	urlDownloadData = nil;
	urlDownloadConnection = nil;
	
	lastBufferUnderrunCheckReset = nil;
	
	[exportController setOwnerWindow:self];
	
	[self populateVisualizerMenu];
	
	visualizerView = nil;
    /*
	visualizerView = [[SPVisualizerView alloc] init];
	[visualizerView setFrame:[self frame]];
	[visualizerView setEraseColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:1.0f]];
	NSString* visualizerPath = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] resourcePath],@"/DefaultVisualizer.qtz"];
	[visualizerView loadCompositionFromFile:visualizerPath];
	[visualizerView setAutostartsRendering:YES];
	[visualizerView setAutoresizesSubviews:YES];
	[visualizerView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	*/
     
	NSDictionary* infoDictionary = [NSBundle mainBundle].infoDictionary;
	NSString* appNameString = infoDictionary[@"CFBundleName"];
	NSString* appVersionString = infoDictionary[@"CFBundleVersion"];
	NSString* osVersionString = [NSProcessInfo processInfo].operatingSystemVersionString;
	SPUrlRequestUserAgentString = [NSString stringWithFormat:@"%@/%@ (Mac OS X, %@)", appNameString, appVersionString, osVersionString];
    
    
    NSString* key = [NSString stringWithFormat:@"NSSplitView Subview Frames %@", splitView.autosaveName];
    NSArray* subviewFrames = [[NSUserDefaults standardUserDefaults] valueForKey:key];
    
    if (subviewFrames.count > 0)
    {
        // the last frame is skipped because I have one less divider than I have frames
        for (NSInteger i=0; i < (subviewFrames.count - 1); i++ )
        {
            // this is the saved frame data - it's an NSString
            NSString* frameString = subviewFrames[i];
            NSArray* components = [frameString componentsSeparatedByString:@", "];
            
            // only one component from the string is needed to set the position
            CGFloat position;
            
            if (splitView.vertical)
                position = [components[2] floatValue];
            else
                position = [components[3] floatValue];
            
            [splitView setPosition:position ofDividerAtIndex:i];
        }
    }
}


// ----------------------------------------------------------------------------
- (void) playTuneAtPath:(NSString*)path
// ----------------------------------------------------------------------------
{
	[self playTuneAtPath:path subtune:0];
}


// ----------------------------------------------------------------------------
- (void) playTuneAtPath:(NSString*)path subtune:(int)subtuneIndex
// ----------------------------------------------------------------------------
{
	gPreferences.mPlaybackSettings.mFrequency = audioDriver->getSampleRate();
	
	bool success = player->playTuneByPath([path cStringUsingEncoding:NSUTF8StringEncoding], subtuneIndex, &gPreferences.mPlaybackSettings);
	if (success)
	{
		if (fadeOutInProgress)
			[self stopFadeOut];

		currentTunePath = path;
		
		[self updateTuneInfo];
		[self setPlayPauseButtonToPause:YES];
	}
}


// ----------------------------------------------------------------------------
- (void) playTuneAtURL:(NSString*)urlString
// ----------------------------------------------------------------------------
{
	[self playTuneAtURL:urlString subtune:0];
}


// ----------------------------------------------------------------------------
- (void) playTuneAtURL:(NSString*)urlString subtune:(int)subtuneIndex
// ----------------------------------------------------------------------------
{
	while (urlDownloadConnection != nil)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];

	urlDownloadSubtuneIndex = subtuneIndex;
	
	NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
	[request setValue:SPUrlRequestUserAgentString forHTTPHeaderField:@"User-Agent"];
	urlDownloadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (urlDownloadConnection != nil)
		urlDownloadData = [NSMutableData data];
}

// ----------------------------------------------------------------------------
- (void) connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
// ----------------------------------------------------------------------------
{
	urlDownloadData.length = 0;
}


// ----------------------------------------------------------------------------
- (void) connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
// ----------------------------------------------------------------------------
{
	[urlDownloadData appendData:data];
}


// ----------------------------------------------------------------------------
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
// ----------------------------------------------------------------------------
{
	bool success = player->playTuneFromBuffer((char*) urlDownloadData.bytes, (int)urlDownloadData.length, (int)urlDownloadSubtuneIndex, &gPreferences.mPlaybackSettings);
	if (success)
	{
		currentTunePath = nil;
		[self setFadeVolume:1.0f];
		[self setPlayPauseButtonToPause:YES];
		[self updateTuneInfo];
	}
	else
	{
		NSAlert* alert = [NSAlert alertWithMessageText:@"Invalid URL"
										 defaultButton:@"OK"
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:@"The URL did not contain a valid SID file."];
		
		[alert runModal];
	}
	
	urlDownloadData = nil;
	urlDownloadConnection = nil;
}


// ----------------------------------------------------------------------------
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
// ----------------------------------------------------------------------------
{
	NSAlert* alert = [NSAlert alertWithMessageText:@"Download failed"
									 defaultButton:@"OK"
								   alternateButton:nil
									   otherButton:nil
						 informativeTextWithFormat:@"The connection to the server failed, please check the URL or try again later."];
	
	[alert runModal];
}


// ----------------------------------------------------------------------------
- (void) setPlayPauseButtonToPause:(BOOL)pause
// ----------------------------------------------------------------------------
{
	if (pause)
	{
		playPauseButton.image = [NSImage imageNamed:@"hud_pause"];
		//[playPauseButton setAlternateImage:[NSImage imageNamed:@"pause_pressed"]];
		
		miniPlayPauseButton.image = [NSImage imageNamed:@"hud_pause"];
		//[miniPlayPauseButton setAlternateImage:[NSImage imageNamed:@"pause_pressed"]];
	}
	else
	{
		playPauseButton.image = [NSImage imageNamed:@"hud_play"];
		//[playPauseButton setAlternateImage:[NSImage imageNamed:@"play_pressed"]];

		miniPlayPauseButton.image = [NSImage imageNamed:@"hud_play"];
		//[miniPlayPauseButton setAlternateImage:[NSImage imageNamed:@"play_pressed"]];
	}
}


// ----------------------------------------------------------------------------
- (void) switchToSubtune:(NSInteger)subtune
// ----------------------------------------------------------------------------
{
	if (fadeOutInProgress)
		[self stopFadeOut];
	player->startSubtune((int)subtune);
	[self updateTuneInfo];
}


// ----------------------------------------------------------------------------
- (void) keyDown:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	NSString* characters = event.charactersIgnoringModifiers;
	unichar character = [characters characterAtIndex:0];

	switch(character)
	{
		case ' ':
			[self clickPlayPauseButton:self];
			break;
		default:
			[super keyDown:event];
	}
}


// ----------------------------------------------------------------------------
- (void) keyUp:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	NSString* characters = event.charactersIgnoringModifiers;
	unichar character = [characters characterAtIndex:0];

	switch(character)
	{
		case ' ':
			break;
		default:
			[super keyUp:event];
	}
}


// ----------------------------------------------------------------------------
- (void) updateTimer
// ----------------------------------------------------------------------------
{
	NSInteger seconds = player != NULL ? (NSInteger)player->getPlaybackSeconds() : 0;
	[statusDisplay setPlaybackSeconds:seconds];
	[miniStatusDisplay setPlaybackSeconds:seconds];
	[browserDataSource updateCurrentSong:seconds];
	
	if (player != NULL && [NSRunLoop currentRunLoop].currentMode != NSEventTrackingRunLoopMode)
	{
		int defaultTempo = 50;
		if (player->getTempo() != defaultTempo)
		{
			player->setTempo(defaultTempo);
			tempoSlider.integerValue = defaultTempo;
		}
	}
	
	static int updatesWithNoBufferUnderrun = 0;
	
	if (audioDriver != NULL)
	{
		if (audioDriver->getBufferUnderrunDetected())
		{
			updatesWithNoBufferUnderrun = 0;
			audioDriver->stopPlayback();
			audioDriver->setBufferUnderrunDetected(false);
			[self setPlayPauseButtonToPause:NO];
			
			NSAlert* alert = [NSAlert alertWithMessageText:@"Your Mac is too slow to play at the current emulation accuracy"
											 defaultButton:@"OK"
										   alternateButton:nil
											   otherButton:nil
								 informativeTextWithFormat:@"Please lower the emulation accuracy or turn off filter distortion in the playback preferences"];
			
			[alert runModal];
		}
		else
		{
			updatesWithNoBufferUnderrun++;
			if (updatesWithNoBufferUnderrun >= 100)
			{
				audioDriver->setBufferUnderrunDetected(false);
				updatesWithNoBufferUnderrun = 0;
			}
		}
	}
}


// ----------------------------------------------------------------------------
- (void) updateFastTimer
// ----------------------------------------------------------------------------
{
	if (infoWindowController != nil) 
		[[infoWindowController containerView] updateAnimatedViews];
	
	if (fadeOutInProgress)
	{
		fadeOutVolume -= 0.006f;
		if (fadeOutVolume < 0.0f)
			fadeOutVolume = 0.0f;
			
		[self setFadeVolume:fadeOutVolume];
	}
	
	BOOL isOptionPressed = NSApp.currentEvent.modifierFlags & NSAlternateKeyMask ? YES : NO;
	if (isOptionPressed)
	{
		[addPlaylistButton setHidden:YES];
		[addSmartPlaylistButton setHidden:NO];
	}
	else
	{
		[addPlaylistButton setHidden:NO];
		[addSmartPlaylistButton setHidden:YES];
	}

	if (player != NULL)
	{
		SIDPLAY2_NAMESPACE::SidRegisterFrame registerFrame = player->getCurrentSidRegisters();
		unsigned char* registers = registerFrame.mRegisters;
		
		/*
		 
		 if (audioDriver->getIsPlaying())
		 {
		 float levelVoice1 = (registers[0x04] & 0x01) ? float(registers[0x06] >> 4) / 15.0f : 0.0f;
		 float levelVoice2 = (registers[0x0b] & 0x01) ? float(registers[0x0d] >> 4) / 15.0f : 0.0f;
		 float levelVoice3 = (registers[0x12] & 0x01) ? float(registers[0x14] >> 4) / 15.0f : 0.0f;
		 
		 if ([statusDisplay logoVisible])
		 [statusDisplay updateUvMetersWithVoice1:levelVoice1 andVoice2:levelVoice2 andVoice3:levelVoice3];
		 
		 if ([miniStatusDisplay logoVisible])
		 [miniStatusDisplay updateUvMetersWithVoice1:levelVoice1 andVoice2:levelVoice2 andVoice3:levelVoice3];
		 }
		 else
		 {
		 if ([statusDisplay logoVisible])
		 [statusDisplay updateUvMetersWithVoice1:0.0f andVoice2:0.0f andVoice3:0.0f];
		 
		 if ([miniStatusDisplay logoVisible])
		 [miniStatusDisplay updateUvMetersWithVoice1:0.0f andVoice2:0.0f andVoice3:0.0f];
		 }
		 */
		
		if (visualizerView != nil && visualizerView.superview != nil)
		{
			VisualizerState state;
			
			int voiceRamOffset[3] = {0, 7, 14};
			
			for (int i = 0; i < 3; i++)
			{
				int ramoffset = voiceRamOffset[i];
				
				state.voice[i].Gatebit = registers[ ramoffset + 4 ] & 1;
				state.voice[i].Frequency = registers[ ramoffset ] + ( registers[ ramoffset + 1 ] << 8 );
				state.voice[i].Pulsewidth = ( registers[ ramoffset + 2 ] + ( registers[ ramoffset + 3 ] << 8 ) ) & 0x0FFF;
				state.voice[i].Waveform = registers[ ramoffset + 4 ] & 0xfe;
				state.voice[i].Attack = registers[ ramoffset + 5 ] >> 4;
				state.voice[i].Decay = registers[ ramoffset + 5 ] & 0x0f;
				state.voice[i].Sustain = registers[ ramoffset + 6 ] >> 4;
				state.voice[i].Release = registers[ ramoffset + 6 ] & 0x0f;
			}
			
			state.FilterCutoff = ( registers[ 0x15 ] + ( registers[ 0x16 ] << 8 ) ) >> 5;
			state.FilterResonance = registers[ 0x17 ] >> 4;
			state.FilterVoices = registers[ 0x17 ] & 0x07;
			state.FilterMode = registers[ 0x18 ] >> 4;
			state.Volume = registers[ 0x18 ] & 0x0f;
			
			[visualizerView update:&state];
		}
	}
}


// ----------------------------------------------------------------------------
- (void) updateSlowTimer
// ----------------------------------------------------------------------------
{
	//[sourceListDataSource checkForRemoteUpdateRevisionChange];
}


// ----------------------------------------------------------------------------
- (void) updateTuneInfo
// ----------------------------------------------------------------------------
{
	if (player == NULL)
		return;

	NSString* title = @"No information available";
	NSString* author = @"";
	NSString* releaseInfo = @"";

	if (player->hasTuneInformationStrings())
	{
		title = [NSString stringWithCString:player->getCurrentTitle() encoding:NSISOLatin1StringEncoding];
		author = [NSString stringWithCString:player->getCurrentAuthor() encoding:NSISOLatin1StringEncoding];
		releaseInfo = [NSString stringWithCString:player->getCurrentReleaseInfo() encoding:NSISOLatin1StringEncoding];
	}
	
	int currentSubtune = player->getCurrentSubtune();
	int subtuneCount = player->getSubtuneCount();

	int tuneLength = 0;
	char* tuneBuffer = player->getTuneBuffer(tuneLength);
	currentTuneLengthInSeconds = tuneBuffer == NULL ? 0 : [[SongLengthDatabase sharedInstance] getSongLengthFromBuffer:tuneBuffer withBufferLength:tuneLength andSubtune:currentSubtune];

	[statusDisplay setTitle:title andAuthor:author andReleaseInfo:releaseInfo andSubtune:currentSubtune ofSubtunes:subtuneCount withSonglength:(int)currentTuneLengthInSeconds];
	[miniStatusDisplay setTitle:title andAuthor:author andReleaseInfo:releaseInfo andSubtune:currentSubtune ofSubtunes:subtuneCount withSonglength:(int)currentTuneLengthInSeconds];
	
	[[SPPreferencesController sharedInstance] initializeFilterSettingsFromChipModelOfPlayer:player];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPTuneChangedNotification object:self];
	
	// update dock tile menu
	NSMenuItem* titleItem = [dockTileMenu itemWithTag:2];
	NSMenuItem* authorItem = [dockTileMenu itemWithTag:3];
	titleItem.title = [NSString stringWithFormat:@"   %@ (%d/%d)", title, currentSubtune, subtuneCount];
	authorItem.title = [NSString stringWithFormat:@"   %@", author];
	
	NSArray* menuItems = [subtuneSelectionMenu.itemArray copy];
	for (NSMenuItem* menuItem in menuItems)
		[subtuneSelectionMenu removeItem:menuItem];
	
	for (int i = 1; i < (subtuneCount + 1); i++)
	{
		NSString* subtuneString = [NSString stringWithFormat:@"%d", i];
		NSString* keyEquivalent = nil;
		if (i < 10)
			keyEquivalent = subtuneString;
		else if (i == 10)
			keyEquivalent = @"0";
		else
			keyEquivalent = @"";
		
		NSMenuItem* item = [subtuneSelectionMenu addItemWithTitle:subtuneString action:@selector(selectSubtune:) keyEquivalent:keyEquivalent];
		item.target = self;
		item.tag = i;
	}
	
}


// ----------------------------------------------------------------------------
- (AudioDriver*) audioDriver
// ----------------------------------------------------------------------------
{
	return audioDriver;
}


// ----------------------------------------------------------------------------
- (PlayerLibSidplay*) player;
// ----------------------------------------------------------------------------
{
	return player;
}


// ----------------------------------------------------------------------------
- (SPBrowserDataSource*) browserDataSource
// ----------------------------------------------------------------------------
{
	return browserDataSource;
}


// ----------------------------------------------------------------------------
- (SPExportController*) exportController
// ----------------------------------------------------------------------------
{
	return exportController;
}


// ----------------------------------------------------------------------------
- (NSInteger) currentTuneLengthInSeconds
// ----------------------------------------------------------------------------
{
	return currentTuneLengthInSeconds;
}


// ----------------------------------------------------------------------------
- (void) addInfoContainerView:(NSScrollView*)infoContainerScrollView
// ----------------------------------------------------------------------------
{
	infoView = infoContainerScrollView;

	[self addRightSubView:infoView withWidth:400.0f];

	/*
	NSRect frame = [infoView frame];
	frame.size.width = 400.0f;
	[infoView setFrame:frame];
	[infoView setNeedsDisplay:YES];

	[splitView addSubview:(NSView*)infoView];
	*/
}


// ----------------------------------------------------------------------------
- (void) addTopSubView:(NSView*)subView withHeight:(float)height
// ----------------------------------------------------------------------------
{
	NSRect browserFrame = browserScrollView.frame;
	browserFrame.size.height = [rightView frame].size.height - boxView.frame.size.height;
	NSRect subViewFrame;
	NSRect newBrowserFrame;
	NSDivideRect(browserFrame, &subViewFrame, &newBrowserFrame, height, NSMaxYEdge);

	subView.frame = subViewFrame;
	browserScrollView.frame = newBrowserFrame;
	if (subView.window != self)
		[rightView addSubview:subView];
	[subView setNeedsDisplay:YES];
}


// ----------------------------------------------------------------------------
- (void) removeTopSubView
// ----------------------------------------------------------------------------
{
	NSRect browserFrame = browserScrollView.frame;
	browserFrame.size.height = [rightView frame].size.height - boxView.frame.size.height;
	browserScrollView.frame = browserFrame;
}


// ----------------------------------------------------------------------------
- (void) addRightSubView:(NSView*)subView withWidth:(float)width
// ----------------------------------------------------------------------------
{
	NSRect splitViewFrame = splitView.frame;
	NSRect subViewFrame;
	NSRect newSplitViewFrame;
	NSDivideRect(splitViewFrame, &subViewFrame, &newSplitViewFrame, width, NSMaxXEdge);

	subView.frame = subViewFrame;
	splitView.frame = newSplitViewFrame;
	if (subView.window != self)
		[self.contentView addSubview:subView];
	[subView setNeedsDisplay:YES];
}


// ----------------------------------------------------------------------------
- (void) removeRightSubView
// ----------------------------------------------------------------------------
{
	splitView.frame = self.contentView.frame;
}


// ----------------------------------------------------------------------------
- (void) addAlternateBoxView:(NSView*)subView
// ----------------------------------------------------------------------------
{
	NSRect boxFrame = boxView.frame;

	subView.frame = boxFrame;
	[rightView addSubview:subView];
	[subView setNeedsDisplay:YES];
}


// ----------------------------------------------------------------------------
- (float) fadeVolume
// ----------------------------------------------------------------------------
{
	return fadeOutVolume;
}


// ----------------------------------------------------------------------------
- (void) setFadeVolume:(float)volume
// ----------------------------------------------------------------------------
{
	if (volumeIsMuted)
		return;
		
	float fadeVolume = gPreferences.mPlaybackVolume * volume;
	audioDriver->setVolume(fadeVolume);
}


// ----------------------------------------------------------------------------
- (void) startFadeOut
// ----------------------------------------------------------------------------
{
	if (!fadeOutInProgress)
	{
		fadeOutVolume = 1.0f;
		fadeOutInProgress = YES;
	}
}


// ----------------------------------------------------------------------------
- (void) stopFadeOut
// ----------------------------------------------------------------------------
{
	if (fadeOutInProgress)
		fadeOutInProgress = NO;
		
	fadeOutVolume = 1.0f;
	[self setFadeVolume:fadeOutVolume];
}


// ----------------------------------------------------------------------------
- (NSMenuItem*) infoWindowMenuItem
// ----------------------------------------------------------------------------
{
	return infoWindowMenuItem;
}


// ----------------------------------------------------------------------------
- (NSMenuItem*) stilBrowserMenuItem
// ----------------------------------------------------------------------------
{
	return stilBrowserMenuItem;
}


// ----------------------------------------------------------------------------
- (NSMenuItem*) analyzerWindowMenuItem
// ----------------------------------------------------------------------------
{
	return analyzerWindowMenuItem;
}


// ----------------------------------------------------------------------------
- (NSMenuItem*) exportTaskWindowMenuItem;
// ----------------------------------------------------------------------------
{
	return exportTaskWindowMenuItem;
}


// ----------------------------------------------------------------------------
- (SPStatusDisplayView*) statusDisplay
// ----------------------------------------------------------------------------
{
	return statusDisplay;
}


// ----------------------------------------------------------------------------
- (void) setStatusDisplay:(SPStatusDisplayView*)view
// ----------------------------------------------------------------------------
{
	statusDisplay = view;
	[self updateTuneInfo];
}


// ----------------------------------------------------------------------------
- (SPStatusDisplayView*) miniStatusDisplay
// ----------------------------------------------------------------------------
{
	return miniStatusDisplay;
}


// ----------------------------------------------------------------------------
- (SPRemixKwedOrgController*) remixKwedOrgController
// ----------------------------------------------------------------------------
{
	return remixKwedOrgController;
}


#pragma mark -
#pragma mark UI action methods


// ----------------------------------------------------------------------------
- (IBAction) clickPlayPauseButton:(id)sender
// ----------------------------------------------------------------------------
{
	if (!player->isTuneLoaded())
	{
		BOOL foundPlayableItem = [browserDataSource playSelectedItem];
		if (foundPlayableItem)
			[self setPlayPauseButtonToPause:YES];
		return;
	}

	if (audioDriver->getIsPlaying())
	{
		audioDriver->stopPlayback();
		[self setPlayPauseButtonToPause:NO];
	}
	else
	{
		audioDriver->startPlayback();
		[self setPlayPauseButtonToPause:YES];
	}
	
	[[SPPreferencesController sharedInstance] save];
}


// ----------------------------------------------------------------------------
- (IBAction) clickStopButton:(id)sender
// ----------------------------------------------------------------------------
{
	if (audioDriver == NULL)
		return;
		
	audioDriver->stopPlayback();
	[self setPlayPauseButtonToPause:NO];

	player->initCurrentSubtune();

	[[SPPreferencesController sharedInstance] save];
}


// ----------------------------------------------------------------------------
- (IBAction) clickFastForwardButton:(id)sender
// ----------------------------------------------------------------------------
{
	BOOL isOptionPressed = NSApp.currentEvent.modifierFlags & NSAlternateKeyMask ? YES : NO;
	int tempo = isOptionPressed ? 88 : 75;
	player->setTempo(tempo);
	tempoSlider.integerValue = tempo;
}


// ----------------------------------------------------------------------------
- (IBAction) moveTempoSlider:(id)sender
// ----------------------------------------------------------------------------
{
	player->setTempo((int)[sender integerValue]);
}


// ----------------------------------------------------------------------------
- (IBAction) moveVolumeSlider:(id)sender
// ----------------------------------------------------------------------------
{
	gPreferences.mPlaybackVolume = [sender floatValue] / 100.0f;
	audioDriver->setVolume(gPreferences.mPlaybackVolume);
	volumeIsMuted = NO;
	if (sender == miniVolumeSlider)
		volumeSlider.floatValue = [sender floatValue];
	else if (sender == volumeSlider)
		miniVolumeSlider.floatValue = [sender floatValue];
}


// ----------------------------------------------------------------------------
- (IBAction) increaseVolume:(id)sender
// ----------------------------------------------------------------------------
{
	gPreferences.mPlaybackVolume += 0.05f;
	if (gPreferences.mPlaybackVolume > 1.0f)
		gPreferences.mPlaybackVolume = 1.0f;
	audioDriver->setVolume(gPreferences.mPlaybackVolume);
	volumeSlider.floatValue = gPreferences.mPlaybackVolume * 100.0f;
	miniVolumeSlider.floatValue = gPreferences.mPlaybackVolume * 100.0f;
	volumeIsMuted = NO;
}


// ----------------------------------------------------------------------------
- (IBAction) decreaseVolume:(id)sender
// ----------------------------------------------------------------------------
{
	gPreferences.mPlaybackVolume -= 0.05f;
	if (gPreferences.mPlaybackVolume < 0.0f)
		gPreferences.mPlaybackVolume = 0.0f;
	audioDriver->setVolume(gPreferences.mPlaybackVolume);
	volumeSlider.floatValue = gPreferences.mPlaybackVolume * 100.0f;
	miniVolumeSlider.floatValue = gPreferences.mPlaybackVolume * 100.0f;
}


// ----------------------------------------------------------------------------
- (IBAction) muteVolume:(id)sender
// ----------------------------------------------------------------------------
{
	if (volumeIsMuted)
	{
		volumeIsMuted = NO;
		audioDriver->setVolume(gPreferences.mPlaybackVolume);
		volumeSlider.floatValue = gPreferences.mPlaybackVolume * 100.0f;
		miniVolumeSlider.floatValue = gPreferences.mPlaybackVolume * 100.0f;
	}
	else
	{
		volumeIsMuted = YES;
		audioDriver->setVolume(0.0f);
		volumeSlider.floatValue = 0.0f;
		miniVolumeSlider.floatValue = 0.0f;
	}
}


// ----------------------------------------------------------------------------
- (IBAction) nextSubtune:(id)sender
// ----------------------------------------------------------------------------
{
	if (fadeOutInProgress)
		[self stopFadeOut];
	player->startNextSubtune();
	[self updateTuneInfo];
}

// ----------------------------------------------------------------------------
- (IBAction) previousSubtune:(id)sender
// ----------------------------------------------------------------------------
{
	if (fadeOutInProgress)
		[self stopFadeOut];
	player->startPrevSubtune();
	[self updateTuneInfo];
}


// ----------------------------------------------------------------------------
- (IBAction) selectSubtune:(id)sender
// ----------------------------------------------------------------------------
{
	[self switchToSubtune:[sender tag]];
}


// ----------------------------------------------------------------------------
- (IBAction) toggleInfoWindow:(id)sender
// ----------------------------------------------------------------------------
{
	if (infoWindowController == nil)
	{
		infoWindowController = [[SPInfoWindowController alloc] init];
		[infoWindowController setOwnerWindow:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:SPTuneChangedNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:SPPlayerInitializedNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:SPPlaybackSettingsChangedNotification object:self];
	}
	
	[infoWindowController toggleWindow:sender];
}


// ----------------------------------------------------------------------------
- (IBAction) toggleInfoPane:(id)sender
// ----------------------------------------------------------------------------
{
	if (infoWindowController == nil)
	{
		infoWindowController = [[SPInfoWindowController alloc] init];
		[infoWindowController setOwnerWindow:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:SPTuneChangedNotification object:self];
	}

	[infoWindowController togglePane:sender];
}


// ----------------------------------------------------------------------------
- (IBAction) toggleStilBrowser:(id)sender
// ----------------------------------------------------------------------------
{
	if (stilBrowserController == nil)
	{
		stilBrowserController = [SPStilBrowserController sharedInstance];
		[stilBrowserController setOwnerWindow:self];
	}
	
	[stilBrowserController toggleWindow:sender];
}


// ----------------------------------------------------------------------------
- (IBAction) toggleAnalyzer:(id)sender
// ----------------------------------------------------------------------------
{
	if (analyzerWindowController == nil)
	{
		analyzerWindowController = [SPAnalyzerWindowController sharedInstance];
		[analyzerWindowController setOwnerWindow:self];
	}
	
	[analyzerWindowController toggleWindow:sender];
}



// ----------------------------------------------------------------------------
- (IBAction) openFile:(id)sender
// ----------------------------------------------------------------------------
{
	if (!self.visible)
		return;

	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	openPanel.allowedFileTypes = @[@"sid"];
	
    [openPanel beginSheetModalForWindow:self completionHandler:^(NSInteger result)
     {
         if (result == NSFileHandlingPanelOKButton)
         {
             NSArray* urlsToOpen = openPanel.URLs;
             NSString* file = [urlsToOpen[0] path];
             
             NSString* relativePath = [[SPCollectionUtilities sharedInstance] makePathRelativeToCollectionRoot:file];
             if (relativePath != nil)
                 [[SPStilBrowserController sharedInstance] displayEntryForRelativePath:relativePath];
             
             [self playTuneAtPath:file];
         }
     }
     ];
    
}


// ----------------------------------------------------------------------------
- (IBAction) openUrl:(id)sender
// ----------------------------------------------------------------------------
{
	if (!self.visible)
		return;
		
	[NSApp beginSheet:openUrlSheetPanel modalForWindow:self modalDelegate:self didEndSelector:@selector(didEndOpenUrlSheet:returnCode:contextInfo:) contextInfo:nil];
}


// ----------------------------------------------------------------------------
- (void) didEndOpenUrlSheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
// ----------------------------------------------------------------------------
{
    [sheet orderOut:self];
}


// ----------------------------------------------------------------------------
- (IBAction) dismissOpenUrlSheet:(id)sender
// ----------------------------------------------------------------------------
{
	if ([[sender title] isEqualToString:@"OK"])
	{
		NSString* urlString = openUrlTextField.stringValue;

		[self playTuneAtURL:urlString];
	}

	[NSApp endSheet:openUrlSheetPanel];
}


// ----------------------------------------------------------------------------
- (IBAction) openSidplayHomepage:(id)sender
// ----------------------------------------------------------------------------
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.sidmusic.org/sidplay/mac/"]];
}


// ----------------------------------------------------------------------------
- (IBAction) openHvscHomepage:(id)sender
// ----------------------------------------------------------------------------
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://hvsc.c64.org/"]];
}


// ----------------------------------------------------------------------------
- (IBAction) moveFocusToSearchField:(id)sender
// ----------------------------------------------------------------------------
{
	if (stilBrowserController == nil)
		return;
	
	if (stilBrowserController.window.visible)
	{
		[stilBrowserController.window makeKeyWindow];
		[stilBrowserController.window makeFirstResponder:[stilBrowserController searchField]];
	}
	else
		[self makeFirstResponder:[browserDataSource toolbarSearchField]];
}


// ----------------------------------------------------------------------------
- (IBAction) showPreferencesWindow:(id)sender
// ----------------------------------------------------------------------------
{
	NSWindow* syncProgressDialog = [sourceListDataSource syncProgressDialog];
	if (syncProgressDialog != nil && syncProgressDialog.visible)
		return;

	if (prefsWindowController == nil)
	{
		prefsWindowController = [[SPPreferencesWindowController alloc] init];
		[prefsWindowController setOwnerWindow:self];
		[prefsWindowController setSourceListDataSource:sourceListDataSource];
	}
	
	[prefsWindowController showWindow:sender];
}


// ----------------------------------------------------------------------------
- (IBAction) playRandomTuneFromCollection:(id)sender
// ----------------------------------------------------------------------------
{
	NSString* path = [[SPCollectionUtilities sharedInstance] pathOfRandomCollectionItemInPath:nil];
	if (path != nil)
	{
		//NSLog(@"random tune: %@\n", path);
		[self playTuneAtPath:path];
		[browserDataSource browseToFile:path andSetAsCurrentItem:YES];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) toggleVisualizerView:(id)sender
// ----------------------------------------------------------------------------
{
	if (visualizerView == nil)
		return;
		
	if (visualizerView.superview != nil)
	{
		//NSView* contentView = [self contentView];
		//[contentView addSubview:splitView];
		[visualizerView removeFromSuperview];
	}
	else
	{
		NSRect frame = splitView.frame;
		visualizerView.frame = frame;
		NSView* contentView = self.contentView;
		[contentView addSubview:visualizerView];
		//[splitView removeFromSuperview];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) selectVisualizer:(id)sender
// ----------------------------------------------------------------------------
{
	if (visualizerView == nil)
		return;
		
	NSInteger index = [sender tag];
	NSArray* menuItems = [sender menu].itemArray;
	for (NSMenuItem* menuItem in menuItems)
		menuItem.state = NSOffState;
		
	[sender setState:NSOnState];

	NSString* visualizerPath = visualizerCompositionPaths[index];
	[visualizerView loadCompositionFromFile:visualizerPath];
}


// ----------------------------------------------------------------------------
- (void) populateVisualizerMenu
// ----------------------------------------------------------------------------
{
	NSString* defaultVisualizerPath = [NSString stringWithFormat:@"%@%@",[NSBundle mainBundle].resourcePath,@"/DefaultVisualizer.qtz"];
	visualizerCompositionPaths = [NSMutableArray arrayWithCapacity:3];
	[visualizerCompositionPaths addObject:defaultVisualizerPath];

	NSInteger index = 1;
	NSArray* visualizerFiles = [[NSFileManager defaultManager] directoryContentsAtPath:[SPApplicationStorageController visualizerPath]];
	for (NSString* visualizerFile in visualizerFiles)
	{
		if ([visualizerFile characterAtIndex:0] == '.')
			continue;

		if (![visualizerFile.pathExtension isEqualToString:@"qtz"])
			continue;

		NSString* visualizerCompositionPath = [[SPApplicationStorageController visualizerPath] stringByAppendingPathComponent:visualizerFile];
		[visualizerCompositionPaths addObject:visualizerCompositionPath];
		
		NSString* name = visualizerFile.stringByDeletingPathExtension;
		NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:name action:@selector(selectVisualizer:) keyEquivalent:@""];
		menuItem.target = self;
		menuItem.tag = index;
		[visualizerMenu addItem:menuItem];
		
		index++;
	}
}

#pragma mark -
#pragma mark application delegate methods


// ----------------------------------------------------------------------------
- (BOOL) application:(NSApplication*)theApplication openFile:(NSString*)filename
// ----------------------------------------------------------------------------
{
	NSString* relativePath = [[SPCollectionUtilities sharedInstance] makePathRelativeToCollectionRoot:filename];
	if (relativePath != nil)
		[[SPStilBrowserController sharedInstance] displayEntryForRelativePath:relativePath];

	[self playTuneAtPath:filename];
	return YES;
}


// ----------------------------------------------------------------------------
- (void) applicationDidFinishLaunching:(NSNotification*)notification
// ----------------------------------------------------------------------------
{
	NSTimer* slowTimer = [NSTimer scheduledTimerWithTimeInterval:10.0f target:self selector:@selector(updateSlowTimer) userInfo:nil repeats:YES];
	NSTimer* normalTimer = [NSTimer scheduledTimerWithTimeInterval:0.05f target:self selector:@selector(updateTimer) userInfo:nil repeats:YES];
	NSTimer* fastTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f/60.0f target:self selector:@selector(updateFastTimer) userInfo:nil repeats:YES];

	[[NSRunLoop currentRunLoop] addTimer:slowTimer forMode:NSEventTrackingRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:normalTimer forMode:NSEventTrackingRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:fastTimer forMode:NSEventTrackingRunLoopMode];

	//[NSTimer scheduledTimerWithTimeInterval:1.0f target:statusDisplay selector:@selector(startLogoRendering) userInfo:nil repeats:NO];

	NSWindow* syncProgressDialog = [sourceListDataSource syncProgressDialog];
	if (syncProgressDialog != nil && !syncProgressDialog.visible)
		[self makeKeyAndOrderFront:self];
}


// ----------------------------------------------------------------------------
- (void) applicationDidResignActive:(NSNotification*)notification
// ----------------------------------------------------------------------------
{

}


// ----------------------------------------------------------------------------
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)application
// ----------------------------------------------------------------------------
{
	return NO;
}


// ----------------------------------------------------------------------------
- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication*)sender
// ----------------------------------------------------------------------------
{
	if ([exportController activeExportTasksCount] > 0)
	{
		NSAlert* alert = [NSAlert alertWithMessageText:@"You have active export tasks, do you really want to quit SIDPLAY?"
										 defaultButton:@"Don't Quit"
									   alternateButton:@"Quit"
										   otherButton:nil
							 informativeTextWithFormat:@"If you decide to quit, the files that are currently being exported will be incomplete or damaged."];

		NSInteger result = [alert runModal];
		
		if (result == NSAlertDefaultReturn)
			return NSTerminateCancel;
	}

    [statusDisplay prepareForQuit];
    
	return NSTerminateNow;
}


// ----------------------------------------------------------------------------
- (void) applicationWillTerminate:(NSNotification*)aNotification
// ----------------------------------------------------------------------------
{
	//NSLog(@"Shutting down");
	[[SPPreferencesController sharedInstance] save];
}


// ----------------------------------------------------------------------------
- (NSMenu*) applicationDockMenu:(NSApplication*)sender
// ----------------------------------------------------------------------------
{
	return dockTileMenu;
}


#pragma mark -
#pragma mark split view delegate methods

// ----------------------------------------------------------------------------
- (NSRect )splitView:(NSSplitView *)theSplitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex
// ----------------------------------------------------------------------------
{
	if (dividerIndex == 0)
	{
		NSRect leftViewFrame = [leftView frame];
		const int bottom_bar_height = 23;
		NSRect gripRect = NSMakeRect(NSWidth(leftViewFrame) - 17, NSHeight(leftViewFrame) - bottom_bar_height, 17, bottom_bar_height);
		
		return gripRect;
	}
	
	return NSZeroRect;
}


// ----------------------------------------------------------------------------
- (BOOL) splitView:(NSSplitView*)splitView canCollapseSubview:(NSView*) subview
// ----------------------------------------------------------------------------
{
    return NO;
}


// ----------------------------------------------------------------------------
- (CGFloat) splitView:(NSSplitView*)sender constrainSplitPosition:(CGFloat) proposedPosition ofSubviewAt:(NSInteger) offset
// ----------------------------------------------------------------------------
{
	if (offset == 0)
	{
		float position = fminf(proposedPosition, 400.0f);
		position = fmaxf(position, 100.0f);

		return position;
	}
	
    /*
	if (offset == 1)
	{
		float idealPosition = [sender frame].size.width - 400.0f;
		return idealPosition;
		//return fminf(idealPosition, proposedPosition);
	}

	if (offset == 2)
	{
		return 400.0f;
		//return fminf(idealPosition, proposedPosition);
	}
	*/
    
	return proposedPosition;
}


// ----------------------------------------------------------------------------
- (NSRect) splitView:(NSSplitView *)sender effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex
// ----------------------------------------------------------------------------
{
	return NSInsetRect(proposedEffectiveRect, -2.0f, 0.0f);
}



// ----------------------------------------------------------------------------
- (BOOL) splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)subview
// ----------------------------------------------------------------------------
{
    return NO;
}


// ----------------------------------------------------------------------------
- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType
// ----------------------------------------------------------------------------
{
	return nil;
}

@end


@implementation SPWindowDelegate


// ----------------------------------------------------------------------------
- (BOOL) windowShouldZoom:(NSWindow*)window toFrame:(NSRect)proposedFrame
// ----------------------------------------------------------------------------
{
	if (window == mainPlayerWindow)
	{
		BOOL logoVisible = [[mainPlayerWindow statusDisplay] logoVisible];
		BOOL displayVisible = [[mainPlayerWindow statusDisplay] displayVisible];
		[[mainPlayerWindow miniStatusDisplay] setLogoVisible:logoVisible];
		[[mainPlayerWindow miniStatusDisplay] setDisplayVisible:displayVisible];
		
		[window setIsVisible:NO];
		[miniPlayerPanel setIsVisible:YES];
	}
	else
	{
		BOOL logoVisible = [[mainPlayerWindow miniStatusDisplay] logoVisible];
		BOOL displayVisible = [[mainPlayerWindow miniStatusDisplay] displayVisible];
		[[mainPlayerWindow statusDisplay] setLogoVisible:logoVisible];
		[[mainPlayerWindow statusDisplay] setDisplayVisible:displayVisible];

		[window setIsVisible:NO];
		[mainPlayerWindow setIsVisible:YES];
	}
	
	return NO;
}


// ----------------------------------------------------------------------------
- (NSSize) windowWillResize:(NSWindow*)window toSize:(NSSize)proposedFrameSize
// ----------------------------------------------------------------------------
{
	if (window == (NSWindow*)miniPlayerPanel)
	{
		if (proposedFrameSize.width < 310.0f)
			proposedFrameSize.width = 131.0f;

		if (proposedFrameSize.width > 300.0f)
			proposedFrameSize.width = 506.0f;
	}
	
	return proposedFrameSize;
}


@end

