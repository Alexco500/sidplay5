#import "SPInfoContainerView.h"
#import "SPFilterControlView.h"
#import "SPPreferencesController.h"
#import "SPPlayerWindow.h"
#import "SPColorProvider.h"



@implementation SPFilterControlView

// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[super awakeFromNib];

	index = FILTER_CONTAINER_INDEX;
	height = 185.0f;
	//[self setCollapsed:gPreferences.mFilterControlCollapsed];
    [self setCollapsed:YES];

	[self containerBackgroundChanged:nil];
	
	player = NULL;
	
	[self resetToDefaults:self];

	[container addInfoView:self atIndex:index];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tuneInfoChanged:) name:SPTuneChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackSettingsChanged:) name:SPPlaybackSettingsChangedNotification object:nil];	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerInitialized:) name:SPPlayerInitializedNotification object:nil];	
}


// ----------------------------------------------------------------------------
- (void) tuneInfoChanged:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	[self applyFilterSettings];
}


// ----------------------------------------------------------------------------
- (void) playerInitialized:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	player = (PlayerLibSidplayWrapper*) [[container ownerWindow] player];
	if (player != NULL)
	{
		[filterCurveView setPlayer:player];
		[self applyFilterSettings];
	}
}


// ----------------------------------------------------------------------------
- (void) playbackSettingsChanged:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
    struct PlaybackSettings dummySettings;
    [gPreferences getPlaybackSettings:&dummySettings];
    BOOL enableFilterSliders = dummySettings.mFilterType != SID_FILTER_8580;
	offsetSlider.enabled = enableFilterSliders;
	steepnessSlider.enabled = enableFilterSliders;

    BOOL enableDistortionSliders = enableFilterSliders && dummySettings.mEnableFilterDistortion;
	rateSlider.enabled = enableDistortionSliders;
	headroomSlider.enabled = enableDistortionSliders;
	
	[self tuneInfoChanged:aNotification];
}


// ----------------------------------------------------------------------------
- (void) containerBackgroundChanged:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	[super containerBackgroundChanged:aNotification];

	if ([container hasDarkBackground])
	{
		distortionLabel.textColor = [NSColor whiteColor];
		typeLabel.textColor = [NSColor whiteColor];
		
		offsetLabel.textColor = [NSColor whiteColor];
		steepnessLabel.textColor = [NSColor whiteColor];
		strengthLabel.textColor = [NSColor whiteColor];
		rateLabel.textColor = [NSColor whiteColor];
		headroomLabel.textColor = [NSColor whiteColor];
	}
	else
	{
		distortionLabel.textColor = [NSColor blackColor];
		typeLabel.textColor = [NSColor blackColor];
		
		offsetLabel.textColor = [NSColor blackColor];
		steepnessLabel.textColor = [NSColor blackColor];
		strengthLabel.textColor = [NSColor blackColor];
		rateLabel.textColor = [NSColor blackColor];
		headroomLabel.textColor = [NSColor blackColor];
	}
}


// ----------------------------------------------------------------------------
- (void) applyFilterSettings
// ----------------------------------------------------------------------------
{
    struct PlaybackSettings dummySettings;
    [gPreferences getPlaybackSettings:&dummySettings];
    [typePopUpButton selectItemWithTag:dummySettings.mFilterType];
	
    offsetSlider.floatValue = dummySettings.mFilterOffset;
    steepnessSlider.floatValue = dummySettings.mFilterSteepness;

    rateSlider.intValue = dummySettings.mDistortionRate;
    headroomSlider.intValue = dummySettings.mDistortionHeadroom;

    BOOL enableFilterSliders = dummySettings.mFilterType != SID_FILTER_8580;
	offsetSlider.enabled = enableFilterSliders;
	steepnessSlider.enabled = enableFilterSliders;

    BOOL enableDistortionSliders = enableFilterSliders && dummySettings.mEnableFilterDistortion;
	rateSlider.enabled = enableDistortionSliders;
	headroomSlider.enabled = enableDistortionSliders;

	/* FIXME: filter settings
    if (player != NULL)
	{
		PlayerLibSidplay::setFilterSettingsFromPlaybackSettings(filterSettings, &gPreferences.mPlaybackSettings);
		player->setFilterSettings(&filterSettings);
	}
	*/
	[filterCurveView setNeedsDisplay:YES];
}


// ----------------------------------------------------------------------------
- (IBAction) parameterChanged:(id)sender
// ----------------------------------------------------------------------------
{
    struct PlaybackSettings dummySettings;
    struct PlaybackSettings dummyFilter;
    
    [gPreferences getPlaybackSettings:&dummySettings];
    [gPreferences getCustomFilterSettings:&dummyFilter];
    
    dummySettings.mFilterType = SID_FILTER_CUSTOM;
	
    dummySettings.mFilterOffset = offsetSlider.floatValue;
    dummySettings.mFilterSteepness = steepnessSlider.floatValue;

    dummySettings.mDistortionRate = rateSlider.intValue;
    dummySettings.mDistortionHeadroom = headroomSlider.intValue;
	
    dummyFilter.mFilterKinkiness = dummySettings.mFilterKinkiness;
    dummyFilter.mFilterBaseLevel = dummySettings.mFilterBaseLevel;
    dummyFilter.mFilterOffset = dummySettings.mFilterOffset;
    dummyFilter.mFilterSteepness = dummySettings.mFilterSteepness;
    dummyFilter.mFilterRolloff = dummySettings.mFilterRolloff;
    dummyFilter.mDistortionRate = dummySettings.mDistortionRate;
    dummyFilter.mDistortionHeadroom = dummySettings.mDistortionHeadroom;
	
    [gPreferences copyPlaybackSettings:&dummySettings];
    [gPreferences copyCustomFilterSettings:&dummyFilter];
	[self applyFilterSettings];
}


// ----------------------------------------------------------------------------
- (IBAction) filterTypeChanged:(id)sender
// ----------------------------------------------------------------------------
{
    struct PlaybackSettings dummySettings;
    [gPreferences getPlaybackSettings:&dummySettings];
    dummySettings.mFilterType = (SPFilterType) [sender tag];
    [gPreferences copyPlaybackSettings:&dummySettings];
	[self setFilterPreferencesFromTypeDefaults];
	[self applyFilterSettings];
}


// ----------------------------------------------------------------------------
- (void) setFilterPreferencesFromTypeDefaults
// ----------------------------------------------------------------------------
{
    struct PlaybackSettings dummySettings;
    [gPreferences getPlaybackSettings:&dummySettings];
    [gPreferences setDistortionParametersBasedOnFilterType];
	
    BOOL enableFilterSliders = dummySettings.mFilterType != SID_FILTER_8580;
	offsetSlider.enabled = enableFilterSliders;
	steepnessSlider.enabled = enableFilterSliders;
	rateSlider.enabled = enableFilterSliders;
	headroomSlider.enabled = enableFilterSliders;
}


// ----------------------------------------------------------------------------
- (IBAction) resetToDefaults:(id)sender
// ----------------------------------------------------------------------------
{
	[self setFilterPreferencesFromTypeDefaults];
	[self applyFilterSettings];
}


@end


@implementation SPFilterCurveView


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	player = NULL;
}


// ----------------------------------------------------------------------------
- (void) setPlayer:(PlayerLibSidplayWrapper*)thePlayer
// ----------------------------------------------------------------------------
{
	player = thePlayer;
}


// ----------------------------------------------------------------------------
- (void) drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	NSRect bounds = self.bounds;

	NSColor* darkColor = nil;
	NSColor* brightColor = nil;
	darkColor = [NSColor colorWithDeviceRed:0.117f green:0.117f blue:0.117f alpha:1.0f];
	brightColor = [NSColor colorWithDeviceRed:0.321f green:0.321f blue:0.321f alpha:1.0f];

	//NSColor* fillColor = [[[SPColorProvider sharedInstance] alternatingRowBackgroundColors] objectAtIndex:0];
    NSColor* fillColor = [NSColor colorWithDeviceRed:0.2f green:0.2f blue:0.2f alpha:0.96f];

	[darkColor set];
	NSFrameRect(bounds);
	bounds = NSInsetRect(bounds, 1.0f, 1.0f);
	[brightColor set];
	NSFrameRect(bounds);
	bounds = NSInsetRect(bounds, 1.0f, 1.0f);
	[fillColor set];
	NSRectFill(bounds);
	
	NSColor* drawColor = [NSColor colorWithCalibratedWhite:0.8f	alpha:0.9f];
	[drawColor set];

	//float width = bounds.size.width - 1.0f;
	//float height = bounds.size.height - 1.0f;
	
    /* FIXME: filter settings
	sid_filter_t* filterSettings = NULL;
	
	if (player)
		filterSettings = player->getFilterSettings();
	
	if (filterSettings)
	{
		[NSBezierPath setDefaultLineWidth:1.0f];
		NSBezierPath* path = [NSBezierPath bezierPath];

		sid_fc_t* cutoffTable = filterSettings->cutoff;
		int maximum = 0;
		int minimum = 20000;
		
		for (int i = 0; i < filterSettings->points; i++)
		{
			int value = (*cutoffTable)[1];
			if (value < minimum)
				minimum = value;
			if (value > maximum)
				maximum = value;
				
			cutoffTable++;
		}
		
		minimum = MAX(minimum, 1);
		
		cutoffTable = filterSettings->cutoff;
		float scaleY = logf(maximum);
		float offset = logf(minimum) / scaleY;

		int increment = (filterSettings->points > 100) ? 2 : 1; 

		for (int i = 0; i < filterSettings->points; i += increment)
		{
			float xposNormalized = MIN(float((*cutoffTable)[0]) / 2048.0f, 1.0f);
			float value = float((*cutoffTable)[1]);
			float logValueScaled = (value > 0) ? logf(value) / scaleY : 0.0f;
			float yposNormalized = MIN((logValueScaled - offset) / (1.0f - offset), 1.0f);
		
			if (i == 0)
				[path moveToPoint:NSMakePoint(bounds.origin.x + xposNormalized * width, bounds.origin.y + yposNormalized * height + 0.5f)];
			else
				[path lineToPoint:NSMakePoint(bounds.origin.x + xposNormalized * width, bounds.origin.y + yposNormalized * height + 0.5f)];
				
			cutoffTable += increment;
		}
		
		[path stroke];
	}
	*/
	[super drawRect:rect];
}
@end
