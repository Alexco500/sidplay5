
#import "SPPlayerWindow.h"
#import "AudioDriver.h"
#import "SPPreferencesController.h"
#import "SongLengthDatabase.h"
#import "SPSynchronizedScrollView.h"
#import "SPAnalyzerFrequencyView.h"
#import "SPAnalyzerPulseWidthView.h"
#import "SPAnalyzerTimelineView.h"
#import "SPAnalyzerWaveformView.h"
#import "SPAnalyzerAdsrView.h"
#import "SPAnalyzerSampleView.h"
#import "SPAnalyzerWindowController.h"


@implementation SPAnalyzerWindowController


static SPAnalyzerWindowController* sharedInstance = nil;


// ----------------------------------------------------------------------------
+ (SPAnalyzerWindowController*) sharedInstance
// ----------------------------------------------------------------------------
{
	if (sharedInstance == nil)
		sharedInstance = [[SPAnalyzerWindowController alloc] init];
	
	return sharedInstance;
}


// ----------------------------------------------------------------------------
+ (BOOL) isInitialized
// ----------------------------------------------------------------------------
{
	return sharedInstance != nil;
}


// ----------------------------------------------------------------------------
- (id) init
// ----------------------------------------------------------------------------
{
	if (self = [super initWithWindowNibName:@"Analyzer"])
	{
		ownerWindow = nil;
		analyzeInProgress = NO;
		analyzeResultAvailable = NO;
		renderBuffer = NULL;
		renderBufferSampleCount = 0;
		player = NULL;
		audioDriver = NULL;
		totalCaptureTime = 400000;
		cycleToPixelRatio = 1.0;
		cursorPosition = 0;
		previousCursorPixelPosition = 0.0f;
		effectiveSampleRate = 0;
		effectiveCpuClockRate = 985248.4;
		voiceEnabled[0] = YES;
		voiceEnabled[1] = YES;
		voiceEnabled[2] = YES;
		timeUnit = SP_TIME_UNIT_SECONDS;
		
		filterSettingsStream = new SidFilterSettingsStream;
		filterResonanceStream = new SidFilterResonanceStream;
		filterCutoffStream = new SidFilterCutoffStream;
		volumeStream = new SidVolumeStream;
		
		playbackCursorUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f/20.0f target:self selector:@selector(updatePlaybackCursor) userInfo:nil repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:playbackCursorUpdateTimer forMode:NSEventTrackingRunLoopMode];
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

	[frequencyContentScrollView setVerticalMasterScrollView:frequencySideContentScrollView];
	[frequencySideContentScrollView setVerticalMasterScrollView:frequencyContentScrollView];
	[parameterContentScrollView setVerticalMasterScrollView:parameterSideContentScrollView];
	[parameterSideContentScrollView setVerticalMasterScrollView:parameterContentScrollView];

	[timelineScrollView setHorizontalMasterScrollView:parameterContentScrollView];
	[parameterContentScrollView setHorizontalMasterScrollView:frequencyContentScrollView];
	[frequencyContentScrollView setHorizontalMasterScrollView:sampleScrollView];
	[sampleScrollView setHorizontalMasterScrollView:timelineScrollView];
	
	[self adjustScrollViewContentSizes];
}


// ----------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	[[ownerWindow analyzerWindowMenuItem] setTitle:@"Show SID Analyzer"];
}	


// ----------------------------------------------------------------------------
- (void) toggleWindow:(id)sender
// ----------------------------------------------------------------------------
{
	NSWindow* window = [self window];
	
	if ([window isVisible])
	{
		[window orderOut:self];
		[sender setTitle:@"Show SID Analyzer"];
	}
	else
	{
		[window orderFront:self];
		[sender setTitle:@"Hide SID Analyzer"];
		[self showWindow:self];
	}
}


// ----------------------------------------------------------------------------
- (void) setOwnerWindow:(SPPlayerWindow*)window
// ----------------------------------------------------------------------------
{
	ownerWindow = window;
	[[self window] orderOut:self];
	
	audioDriver = [ownerWindow audioDriver];
}


// ----------------------------------------------------------------------------
- (void) adjustScrollViewContentSizes
// ----------------------------------------------------------------------------
{
	NSRect frame = [timelineDocumentView frame];
	frame.size.width = double(totalCaptureTime) * cycleToPixelRatio;
	[timelineDocumentView setFrame:frame];

	frame = [sampleDocumentView frame];
	frame.size.width = double(totalCaptureTime) * cycleToPixelRatio;
	[sampleDocumentView setFrame:frame];
	
	frame = [frequencyDocumentView frame];
	frame.size.width = double(totalCaptureTime) * cycleToPixelRatio;
	[frequencyDocumentView setFrame:frame];

	frame = [parameterDocumentView frame];
	frame.size.width = double(totalCaptureTime) * cycleToPixelRatio;
	[parameterDocumentView setFrame:frame];
	
}


// ----------------------------------------------------------------------------
- (void) updateZoomFactor:(double)inZoomFactor
// ----------------------------------------------------------------------------
{
	float viewWidth = [timelineScrollView frame].size.width;

	NSRect visibleRect = [timelineScrollView documentVisibleRect];
	float middlePixel = visibleRect.origin.x + NSWidth(visibleRect) * 0.5f;
	
	//double timeAtCenter = gPixelToCycle(middlePixel, cycleToPixelRatio);
	//NSLog(@"visibleRect: %@, middlePixel: %f, timeAtCenter: %f\n", NSStringFromRect(visibleRect), middlePixel, timeAtCenter);
	
	cycleToPixelRatio = viewWidth / (double(totalCaptureTime) / inZoomFactor);

	//float newMiddlePixel = gCycleToPixel(timeAtCenter, cycleToPixelRatio);
	float newMiddlePixel= gCycleToPixel(cursorPosition, cycleToPixelRatio);
	
	//NSLog(@"newMiddlePixel: %f, inZoomFactor: %f\n", newMiddlePixel, inZoomFactor);
	
	[self adjustScrollViewContentSizes];
	
	if (inZoomFactor > 1.0f && newMiddlePixel != middlePixel)
	{
		visibleRect = [timelineScrollView documentVisibleRect];
		visibleRect.origin.x = floorf(newMiddlePixel - NSWidth(visibleRect) * 0.5f);
		visibleRect.origin = [[timelineScrollView contentView] constrainScrollPoint:visibleRect.origin];
		[[timelineScrollView contentView] scrollToPoint:visibleRect.origin];
		[timelineScrollView reflectScrolledClipView:[timelineScrollView contentView]];
	}
}


// ----------------------------------------------------------------------------
- (void) reloadData
// ----------------------------------------------------------------------------
{
	[frequencyView flushImageCache];
	[pulseWidthView flushImageCache];
	[sampleView flushImageCache];
	[waveformView flushImageCache];
	[adsrView flushImageCache];
	
	[[[self window] contentView] setNeedsDisplay:YES];
	
}


// ----------------------------------------------------------------------------
- (void) drawBackgroundInRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	[NSBezierPath setDefaultLineWidth:1.0f];
	
	NSColor* backgroundColor = [NSColor colorWithCalibratedWhite:0.250f alpha:1.0f];
	NSColor* topLineColor = [NSColor colorWithCalibratedWhite:0.32f alpha:1.0f];
	NSColor* leftLineColor = [NSColor colorWithCalibratedWhite:0.22f alpha:1.0f];
	NSColor* rightLineColor = [NSColor colorWithCalibratedWhite:0.17f alpha:1.0f];
	NSColor* rightLine2Color = [NSColor colorWithCalibratedWhite:0.29f alpha:1.0f];
	NSColor* bottomLineColor = [NSColor colorWithCalibratedWhite:0.14f alpha:1.0f];
	
	[backgroundColor set];
	NSRectFill(rect);
	
	NSPoint topLeft = NSMakePoint(rect.origin.x + 0.5f, rect.origin.y + rect.size.height - 0.5f);
	NSPoint topRight = NSMakePoint(rect.origin.x + rect.size.width - 0.5f, rect.origin.y + rect.size.height - 0.5f);
	NSPoint topRight2 = NSMakePoint(rect.origin.x + rect.size.width - 1.5f, rect.origin.y + rect.size.height - 0.5f);
	NSPoint bottomRight = NSMakePoint(rect.origin.x + rect.size.width - 0.5f, rect.origin.y + 0.5f);
	NSPoint bottomRight2 = NSMakePoint(rect.origin.x + rect.size.width - 1.5f, rect.origin.y + 0.5f);
	NSPoint bottomLeft = NSMakePoint(rect.origin.x + 0.5f, rect.origin.y + 0.5f);
	
	NSBezierPath* path = [NSBezierPath bezierPath];
	[topLineColor set];
	[path moveToPoint:topLeft];
	[path lineToPoint:topRight];
	[path stroke];
	
	path = [NSBezierPath bezierPath];
	[rightLineColor set];
	[path moveToPoint:topRight];
	[path lineToPoint:bottomRight];
	[path stroke];

	path = [NSBezierPath bezierPath];
	[rightLine2Color set];
	[path moveToPoint:topRight2];
	[path lineToPoint:bottomRight2];
	[path stroke];
	
	path = [NSBezierPath bezierPath];
	[bottomLineColor set];
	[path moveToPoint:bottomRight];
	[path lineToPoint:bottomLeft];
	[path stroke];
	
	path = [NSBezierPath bezierPath];
	[leftLineColor set];
	[path moveToPoint:bottomLeft];
	[path lineToPoint:topLeft];
	[path stroke];
}


// ----------------------------------------------------------------------------
- (void) drawCursorInRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	float xPos = floorf(cursorPosition * cycleToPixelRatio) + 0.5f;
	if (xPos > NSMinX(rect) && xPos < NSMaxX(rect))
	{
		[NSBezierPath setDefaultLineWidth:1.0f];
		NSColor* cursorColor = [NSColor colorWithCalibratedRed:0.99f green:0.11f blue:0.0f alpha:1.0f];
		NSBezierPath* path = [NSBezierPath bezierPath];
		[cursorColor set];
		[path moveToPoint:NSMakePoint(xPos, NSMinY(rect))];
		[path lineToPoint:NSMakePoint(xPos, NSMaxY(rect))];
		[path stroke];
	}
}


// ----------------------------------------------------------------------------
- (void) updatePlaybackCursor
// ----------------------------------------------------------------------------
{
	if (audioDriver->getIsPlayingPreRenderedBuffer())
	{
		double sampleToCycleRatio = float(effectiveSampleRate) / effectiveCpuClockRate;
		[self setCursorPosition:audioDriver->getPreRenderedBufferPlaybackPosition() / sampleToCycleRatio andUpdateScrollViews:YES];
	}
}


// ----------------------------------------------------------------------------
- (NSInteger) cursorPosition
// ----------------------------------------------------------------------------
{
	return cursorPosition;
}


// ----------------------------------------------------------------------------
- (void) setCursorPosition:(NSInteger)inCursorPosition
// ----------------------------------------------------------------------------
{
	[self setCursorPosition:inCursorPosition andUpdateScrollViews:NO];
}


// ----------------------------------------------------------------------------
- (void) setCursorPosition:(NSInteger)inCursorPosition andUpdateScrollViews:(BOOL)scrollToCursor
// ----------------------------------------------------------------------------
{
	cursorPosition = inCursorPosition;

	if (cursorPosition < 0)
		cursorPosition = 0;
	else if (cursorPosition >= totalCaptureTime)
	{
		cursorPosition = totalCaptureTime - 1;
		[self setPlayPauseButtonToPause:NO];
	}
	
	// Update the playback position of the audio driver
	double sampleToCycleRatio = float(effectiveSampleRate) / effectiveCpuClockRate;
	int samplePosition = cursorPosition * sampleToCycleRatio;
	audioDriver->setPreRenderedBufferPlaybackPosition(samplePosition);

	// Update the toolbar display
	[self updateToolbarTimeDisplay];
	
	// Move the scroll views to the new position if desired
	float cursorPixelPosition = cursorPosition * cycleToPixelRatio;

	if (fabs(cursorPixelPosition - previousCursorPixelPosition) >= 0.9f)
	{
		if (scrollToCursor)
		{
			NSPoint scrollPoint = NSMakePoint(floorf(cursorPixelPosition - NSWidth([timelineScrollView frame]) * 0.5f), 0.0f);
			scrollPoint = [[timelineScrollView contentView] constrainScrollPoint:scrollPoint];
			[[timelineScrollView contentView] scrollToPoint:scrollPoint];
			[timelineScrollView reflectScrolledClipView:[timelineScrollView contentView]];
		}
		
		[timelineScrollView setNeedsDisplay:YES];
		[sampleScrollView setNeedsDisplay:YES];
		[frequencyContentScrollView setNeedsDisplay:YES];
		[parameterContentScrollView setNeedsDisplay:YES];
		
		previousCursorPixelPosition = cursorPixelPosition;
	}
}


// ----------------------------------------------------------------------------
- (void) updateToolbarTimeDisplay
// ----------------------------------------------------------------------------
{
	if (timeUnit == SP_TIME_UNIT_SECONDS)
	{
		double timeInSeconds = double(cursorPosition) / effectiveCpuClockRate;
		int minutes = floor(timeInSeconds / 60);
		timeInSeconds -= minutes * 60;
		int seconds = floor(timeInSeconds);
		timeInSeconds -= seconds;
		int milliseconds = floor(timeInSeconds * 1000);
		NSString* cursorPositionString = [NSString stringWithFormat:@"%02d'%02d\"%03d", minutes, seconds, milliseconds];
		[playbackPositionTextField setStringValue:cursorPositionString];
	}
	else
	{
		NSString* cursorPositionString = [NSString stringWithFormat:@"%ld", (long)cursorPosition];
		[playbackPositionTextField setStringValue:cursorPositionString];
	}
}


// ----------------------------------------------------------------------------
- (void) setPlayPauseButtonToPause:(BOOL)pause
// ----------------------------------------------------------------------------
{
	if (pause)
	{
		[playPauseButton setImage:[NSImage imageNamed:@"pause"]];
		[playPauseButton setAlternateImage:[NSImage imageNamed:@"pause_pressed"]];
	}
	else
	{
		[playPauseButton setImage:[NSImage imageNamed:@"play"]];
		[playPauseButton setAlternateImage:[NSImage imageNamed:@"play_pressed"]];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) clickCaptureButton:(id)sender
// ----------------------------------------------------------------------------
{
	if (analyzeInProgress)
		return;
	
	analyzeInProgress = YES;
	analyzeResultAvailable = NO;
	
	for (int i = 0; i < SID_VOICE_COUNT; i++)
	{
		frequencyStream[i].clear();
		pulseWidthStream[i].clear();
		gateStream[i].clear();
		waveformStream[i].clear();
		adsrStream[i].clear();
	}

	filterSettingsStream->clear();
	filterResonanceStream->clear();
	filterCutoffStream->clear();
	volumeStream->clear();
	
	renderBufferSampleCount = 0;
	if (renderBuffer != NULL)
	{
		delete[] renderBuffer;
		renderBuffer = NULL;
	}
	
	[self reloadData];
	
	[NSThread detachNewThreadSelector:@selector(analyzeThread:) toTarget:self withObject:nil];
}


// ----------------------------------------------------------------------------
- (IBAction) clickPlayPauseButton:(id)sender
// ----------------------------------------------------------------------------
{
	if (analyzeResultAvailable && (renderBuffer == NULL || renderBufferSampleCount == 0))
		return;

	if (audioDriver != NULL)
	{
		if (audioDriver->getIsPlayingPreRenderedBuffer())
		{
			audioDriver->stopPreRenderedBufferPlayback();
			[self setPlayPauseButtonToPause:NO];
		}
		else
		{
			//audioDriver->setPreRenderedBufferPlaybackPosition(cursorPosition);
			audioDriver->setPreRenderedBuffer((short*)renderBuffer, renderBufferSampleCount);
			audioDriver->startPreRenderedBufferPlayback();
			[self setPlayPauseButtonToPause:YES];
		}
	}
}


// ----------------------------------------------------------------------------
- (IBAction) clickReverseButton:(id)sender
// ----------------------------------------------------------------------------
{
	[self setCursorPosition:cursorPosition - 500000 andUpdateScrollViews:YES];
}


// ----------------------------------------------------------------------------
- (IBAction) clickFastForwardButton:(id)sender
// ----------------------------------------------------------------------------
{
	[self setCursorPosition:cursorPosition + 500000 andUpdateScrollViews:YES];
	
	//audioDriver->startPreRenderedBufferPlayback();
}


// ----------------------------------------------------------------------------
- (IBAction) clickTimeUnitControl:(id)sender
// ----------------------------------------------------------------------------
{
	if ([sender isSelectedForSegment:0])
		timeUnit = SP_TIME_UNIT_SECONDS;
	else if ([sender isSelectedForSegment:1])
		timeUnit = SP_TIME_UNIT_CYCLES;
	
	[timelineView setShowTimeInSeconds:timeUnit == SP_TIME_UNIT_SECONDS];
	[self updateToolbarTimeDisplay];
}


// ----------------------------------------------------------------------------
- (IBAction) moveVolumeSlider:(id)sender
// ----------------------------------------------------------------------------
{
	audioDriver->setPreRenderedBufferVolume([sender floatValue] / 100.0f);
}


// ----------------------------------------------------------------------------
- (IBAction) changeHorizontalZoomFactor:(id)sender
// ----------------------------------------------------------------------------
{
	double zoomFactor = pow(10, [sender doubleValue]);
	
	[self updateZoomFactor:zoomFactor];
}


// ----------------------------------------------------------------------------
- (IBAction) clickVoice1State:(id)sender
// ----------------------------------------------------------------------------
{
	voiceEnabled[0] = [sender state] == NSOnState;
	[self reloadData];
}


// ----------------------------------------------------------------------------
- (IBAction) clickVoice2State:(id)sender
// ----------------------------------------------------------------------------
{
	voiceEnabled[1] = [sender state] == NSOnState;
	[self reloadData];
}


// ----------------------------------------------------------------------------
- (IBAction) clickVoice3State:(id)sender
// ----------------------------------------------------------------------------
{
	voiceEnabled[2] = [sender state] == NSOnState;
	[self reloadData];
}


// ----------------------------------------------------------------------------
- (void) analyzeThread:(id)inObject
// ----------------------------------------------------------------------------
{
	PlayerLibSidplay* mainPlayer = [ownerWindow player];
	if (mainPlayer == NULL)
		return;
	
	player = new PlayerLibSidplay;
	
	int bufferSize = 0;
	char* buffer = mainPlayer->getTuneBuffer(bufferSize);
	int subtune = mainPlayer->getCurrentSubtune();
	PlaybackSettings settings = gPreferences.mPlaybackSettings;
	
	player->loadTuneFromBuffer(buffer, bufferSize, subtune, &settings);
	player->enableRegisterLogging(true);
	
	NSString* title = [NSString stringWithCString:player->getCurrentTitle() encoding:NSISOLatin1StringEncoding];
	NSString* author = [NSString stringWithCString:player->getCurrentAuthor() encoding:NSISOLatin1StringEncoding];
	int currentSubtune = player->getCurrentSubtune();
	
	NSString* windowTitle = [NSString stringWithFormat:@"SID Tune Analyzer - \"%@\" by \"%@\" (song %d)", title, author, currentSubtune];
	[[self window] setTitle:windowTitle];
	
	effectiveSampleRate = audioDriver->getSampleRate();
	effectiveCpuClockRate = player->getCurrentCpuClockRate();
	
	NSInteger timeInSeconds = [[SongLengthDatabase sharedInstance] getSongLengthFromBuffer:buffer withBufferLength:bufferSize andSubtune:subtune];
	if (timeInSeconds == 0)
		timeInSeconds = gPreferences.mDefaultPlayTime;
	
	NSInteger samplesRemaining = timeInSeconds * settings.mFrequency;
	NSInteger samplesCompleted = 0;
	const int maxSamplesPerSlice = 64 * 1024;
	renderBufferSampleCount = samplesRemaining;
	if (renderBuffer != NULL)
		delete[] renderBuffer;
	renderBuffer = new char[renderBufferSampleCount * sizeof(short)];
	char* renderBufferSlice = renderBuffer;
	
	while (samplesRemaining > 0)
	{
		UInt32 numSamplesThisSlice = samplesRemaining;
		if (numSamplesThisSlice > maxSamplesPerSlice)
			numSamplesThisSlice = maxSamplesPerSlice;
		
		if (numSamplesThisSlice > 0)
		{
			int renderBufferSliceSize = numSamplesThisSlice * sizeof(short);
			player->fillBuffer(renderBufferSlice, renderBufferSliceSize);
			renderBufferSlice += renderBufferSliceSize;
		}
		
		samplesRemaining -= numSamplesThisSlice;
		samplesCompleted += numSamplesThisSlice;

		NSNumber* progress = [NSNumber numberWithFloat:(float)samplesCompleted / float(samplesCompleted + samplesRemaining)];
		[self performSelectorOnMainThread:@selector(analyzeProgressNotification:) withObject:progress waitUntilDone:NO];
	}
	
	const SidRegisterLog& registerLog = player->getRegisterLog();

	totalCaptureTime = registerLog[registerLog.size() - 1].mTimeStamp;

	unsigned int frequency[SID_VOICE_COUNT] = { 0, 0, 0 };
	unsigned short pulseWidth[SID_VOICE_COUNT] = { 0, 0, 0 };
	bool gate[SID_VOICE_COUNT] = { false, false, false };
	unsigned char waveform[SID_VOICE_COUNT] = { 0, 0, 0 };
	unsigned short adsr[SID_VOICE_COUNT] = { 0, 0, 0 };
	
	unsigned char filterSettings = 0;
	unsigned char filterResonance = 0;
	unsigned short filterCutoff = 0;
	unsigned char volume = 0;
	
	unsigned int newFrequency[SID_VOICE_COUNT];
	unsigned short newPulseWidth[SID_VOICE_COUNT];
	bool newGate[SID_VOICE_COUNT];
	unsigned char newWaveform[SID_VOICE_COUNT];
	unsigned short newAdsr[SID_VOICE_COUNT];

	unsigned char newFilterSettings = 0;
	unsigned char newFilterResonance = 0;
	unsigned short newFilterCutoff = 0;
	unsigned char newVolume = 0;
	
	// Preprocess the register stream into individual parameter streams
	
	for (std::vector<SIDPLAY2_NAMESPACE::SidRegisterFrame>::const_iterator it = registerLog.begin(); it != registerLog.end(); ++it)
	{
		std::vector<SIDPLAY2_NAMESPACE::SidRegisterFrame>::const_iterator next_it = (it + 1) < registerLog.end() ? it + 1 : it;

		/*
		printf("Frame %d: ", it->mTimeStamp);
		for (int i = 0; i < SIDPLAY2_NAMESPACE::SidRegisterFrame::SID_REGISTER_COUNT; i++)
			printf("%02x ", it->mRegisters[i]);
		printf("\n");
		*/
		 
		for (int i = 0; i < SID_VOICE_COUNT; i++)
		{
			int registerBlock = i*7;
			
			newFrequency[i] = it->mRegisters[registerBlock] | (it->mRegisters[registerBlock + 1] << 8) | it->mRegisters[registerBlock + 4] << 31;
			 
			if (newFrequency[i] != frequency[i])
			{
				frequencyStream[i].push_back(SidFrequencyState(newFrequency[i], it->mTimeStamp));
				frequency[i] = newFrequency[i];
			}
			
			newPulseWidth[i] = (it->mRegisters[registerBlock + 2] | (it->mRegisters[registerBlock + 3] << 8)) & 0x0FFF;
			
			if (newPulseWidth[i] != pulseWidth[i])
			{
				pulseWidthStream[i].push_back(SidPulseWidthState(newPulseWidth[i], it->mTimeStamp));
				pulseWidth[i] = newPulseWidth[i];
			}
			
			newGate[i] = it->mRegisters[registerBlock + 4] & 1;
			
			if (newGate[i] != gate[i])
			{
				gateStream[i].push_back(SidGateState(newGate[i], it->mTimeStamp));
				gate[i] = newGate[i];
			}
			
			newWaveform[i] = it->mRegisters[registerBlock + 4] & 0xfe;

			if (newWaveform[i] != waveform[i])
			{
				waveformStream[i].push_back(SidWaveformState(newWaveform[i], it->mTimeStamp));
				waveform[i] = newWaveform[i];
			}
			
			newAdsr[i] = (it->mRegisters[registerBlock + 5] << 8) | it->mRegisters[registerBlock + 6];
			
			if (newAdsr[i] != adsr[i])
			{
				adsrStream[i].push_back(SidAdsrState(newAdsr[i], it->mTimeStamp));
				adsr[i] = newAdsr[i];
			}
		}
		
		newFilterSettings = (it->mRegisters[0x17] & 0x0f) | (it->mRegisters[0x18] & 0xf0);
		
		if (newFilterSettings != filterSettings)
		{
			filterSettingsStream->push_back(SidFilterSettingsState(newFilterSettings, it->mTimeStamp));
			filterSettings = newFilterSettings;
		}

		newFilterResonance = it->mRegisters[0x17] >> 4;
		
		if (newFilterResonance != filterResonance)
		{
			filterResonanceStream->push_back(SidFilterResonanceState(newFilterResonance, it->mTimeStamp));
			filterResonance = newFilterResonance;
		}

		newFilterCutoff = (it->mRegisters[0x15] + (it->mRegisters[0x16] << 8)) >> 5;
		
		if (newFilterCutoff != filterCutoff)
		{
			filterCutoffStream->push_back(SidFilterCutoffState(newFilterCutoff, it->mTimeStamp));
			filterCutoff = newFilterCutoff;
		}

		newVolume = it->mRegisters[0x18] & 0x0f;
		
		if (newVolume != volume)
		{
			volumeStream->push_back(SidVolumeState(newVolume, it->mTimeStamp));
			volume = newVolume;
		}
	}
	
	[self performSelectorOnMainThread:@selector(analyzeComplete:)
						   withObject:(id)nil
						waitUntilDone:NO];
	
	delete player;
}	


// ----------------------------------------------------------------------------
- (void) analyzeComplete:(id)inObject
// ----------------------------------------------------------------------------
{
	analyzeInProgress = NO;
	analyzeResultAvailable = YES;
	
	[self updateZoomFactor:1.0f];
	[horizontalZoomSlider setDoubleValue:0.0];
	
	[self reloadData];
}


// ----------------------------------------------------------------------------
- (void) analyzeProgressNotification:(id)progress
// ----------------------------------------------------------------------------
{
	[analyzeProgressIndicator setDoubleValue:[progress floatValue]];
}


// ----------------------------------------------------------------------------
- (NSUInteger) totalCaptureTime
// ----------------------------------------------------------------------------
{
	return totalCaptureTime;
}


// ----------------------------------------------------------------------------
- (double) cycleToPixelRatio
// ----------------------------------------------------------------------------
{
	return cycleToPixelRatio;
}


// ----------------------------------------------------------------------------
- (BOOL) analyzeResultAvailable
// ----------------------------------------------------------------------------
{
	return analyzeResultAvailable;
}


// ----------------------------------------------------------------------------
- (SidFrequencyStream*) frequencyStream:(int)inVoice
// ----------------------------------------------------------------------------
{
	return &frequencyStream[inVoice];
}


// ----------------------------------------------------------------------------
- (SidPulseWidthStream*) pulseWidthStream:(int)inVoice
// ----------------------------------------------------------------------------
{
	return &pulseWidthStream[inVoice];
}


// ----------------------------------------------------------------------------
- (SidGateStream*) gateStream:(int)inVoice
// ----------------------------------------------------------------------------
{
	return &gateStream[inVoice];
}


// ----------------------------------------------------------------------------
- (SidWaveformStream*) waveformStream:(int)inVoice
// ----------------------------------------------------------------------------
{
	return &waveformStream[inVoice];
}


// ----------------------------------------------------------------------------
- (SidAdsrStream*) adsrStream:(int)inVoice
// ----------------------------------------------------------------------------
{
	return &adsrStream[inVoice];
}


// ----------------------------------------------------------------------------
- (SidFilterSettingsStream*) filterSettingsStream
// ----------------------------------------------------------------------------
{
	return filterSettingsStream;
}


// ----------------------------------------------------------------------------
- (SidFilterResonanceStream*) filterResonanceStream
// ----------------------------------------------------------------------------
{
	return filterResonanceStream;
}


// ----------------------------------------------------------------------------
- (SidFilterCutoffStream*) filterCutoffStream
// ----------------------------------------------------------------------------
{
	return filterCutoffStream;
}


// ----------------------------------------------------------------------------
- (SidVolumeStream*) volumeStream
// ----------------------------------------------------------------------------
{
	return volumeStream;
}


// ----------------------------------------------------------------------------
- (short*) renderBufferSamples
// ----------------------------------------------------------------------------
{
	return (short*) renderBuffer;
}


// ----------------------------------------------------------------------------
- (int) renderBufferSampleCount
// ----------------------------------------------------------------------------
{
	return renderBufferSampleCount;
}


// ----------------------------------------------------------------------------
- (BOOL) voiceEnabled:(int)inVoice
// ----------------------------------------------------------------------------
{
	return voiceEnabled[inVoice];
}


// ----------------------------------------------------------------------------
- (NSUInteger) effectiveSampleRate
// ----------------------------------------------------------------------------
{
	return effectiveSampleRate;
}


// ----------------------------------------------------------------------------
- (double) effectiveCpuClockRate
// ----------------------------------------------------------------------------
{
	return effectiveCpuClockRate;
}



#pragma mark -
#pragma mark split view delegate methods


// ----------------------------------------------------------------------------
- (BOOL) splitView:(NSSplitView*)splitView canCollapseSubview:(NSView*) subview
// ----------------------------------------------------------------------------
{
    return NO;
}


// ----------------------------------------------------------------------------
- (float) splitView:(NSSplitView*)sender constrainSplitPosition:(float) proposedPosition ofSubviewAt:(int) offset
// ----------------------------------------------------------------------------
{
	float position = proposedPosition;
	
	if (offset == 0)
		position = fmaxf(proposedPosition, 30.0f);
	else if (offset == 1)
	{
		position = fmaxf(proposedPosition, [sender frame].size.height - 202.0f);
		position = fminf(position, [sender frame].size.height - 20.0f);
	}
	
	return position;
}

@end


@implementation SPAnalyzerWindow


// ----------------------------------------------------------------------------
- (void) keyDown:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	NSString* characters = [event charactersIgnoringModifiers];
	unichar character = [characters characterAtIndex:0];
	
	switch(character)
	{
		case ' ':
			[(SPAnalyzerWindowController*)[self delegate] clickPlayPauseButton:self];
			break;
		default:
			[super keyDown:event];
	}
}


// ----------------------------------------------------------------------------
- (void) keyUp:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	NSString* characters = [event charactersIgnoringModifiers];
	unichar character = [characters characterAtIndex:0];
	
	switch(character)
	{
		case ' ':
			break;
		default:
			[super keyUp:event];
	}
}

@end


@implementation SPAnalyzerSplitView


// ----------------------------------------------------------------------------
- (CGFloat) dividerThickness
// ----------------------------------------------------------------------------
{
	return 4.0f;
}


// ----------------------------------------------------------------------------
- (void) drawDividerInRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	NSColor* backgroundColor = [NSColor colorWithCalibratedWhite:0.250f alpha:1.0f];
	NSColor* lineColor1 = [NSColor colorWithCalibratedWhite:0.32f alpha:1.0f];
	NSColor* lineColor2 = [NSColor colorWithCalibratedWhite:0.14f alpha:1.0f];
	
	[backgroundColor set];
	NSRectFill(rect);
	
	NSBezierPath* path = [NSBezierPath bezierPath];
	[lineColor1 set];
	[path moveToPoint:NSMakePoint(rect.origin.x, rect.origin.y + 0.5f)];
	[path lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + 0.5f)];
	[path stroke];
	
	path = [NSBezierPath bezierPath];
	[lineColor2 set];
	[path moveToPoint:NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height - 0.5f)];
	[path lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height - 0.5f)];
	[path stroke];
	
	//[super drawDividerInRect:rect];
}


@end


@implementation SPAnalyzerRectView


// ----------------------------------------------------------------------------
- (void)drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	NSRect bounds = [self bounds];
	
	[[SPAnalyzerWindowController sharedInstance] drawBackgroundInRect:bounds];
}	

@end

	


