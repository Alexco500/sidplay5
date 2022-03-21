#import <Cocoa/Cocoa.h>
#import "SPInfoView.h"
#import "PlayerLibSidplay.h"

@class SPFilterCurveView;

@interface SPFilterControlView : SPInfoView
{
	sid_filter_t filterSettings;
	PlayerLibSidplay* player;

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
	PlayerLibSidplay* player;
}

- (void) setPlayer:(PlayerLibSidplay*)thePlayer;

@end;