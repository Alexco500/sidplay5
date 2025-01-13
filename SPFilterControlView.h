#import <Cocoa/Cocoa.h>
#import "SPInfoView.h"
#import "PlayerLibSidplayWrapper.h"

@class SPFilterCurveView;

@interface SPFilterControlView : SPInfoView
{
	/* FIXME: filter settings
    sid_filter_t filterSettings;
     */
	PlayerLibSidplayWrapper* player;

	IBOutlet NSTextField* distortionLabel;
	IBOutlet NSTextField* typeLabel;

	//IBOutlet NSTextField* baseLevelLabel;
	IBOutlet NSTextField* offsetLabel;
	IBOutlet NSTextField* steepnessLabel;
	IBOutlet NSTextField* strengthLabel;
	IBOutlet NSTextField* rateLabel;
	IBOutlet NSTextField* headroomLabel;
	
	//IBOutlet NSSlider* baseLevelSlider;
	IBOutlet NSSlider* offsetSlider;
	IBOutlet NSSlider* steepnessSlider;
	IBOutlet NSSlider* rateSlider;
	IBOutlet NSSlider* headroomSlider;
	
	IBOutlet NSButton* resetButton;
	
	IBOutlet NSPopUpButton* typePopUpButton;
	
	IBOutlet SPFilterCurveView* filterCurveView;
}

- (void) applyFilterSettings;
- (void) setFilterPreferencesFromTypeDefaults;

- (IBAction) parameterChanged:(id)sender;
- (IBAction) filterTypeChanged:(id)sender;
- (IBAction) resetToDefaults:(id)sender;


@end


@interface SPFilterCurveView : NSView
{
    PlayerLibSidplayWrapper* player;
}

- (void) setPlayer:(PlayerLibSidplayWrapper*)thePlayer;

@end;
