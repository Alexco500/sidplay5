#import <Cocoa/Cocoa.h>
#import "SPExporter.h"

@class SPExportController;

@interface SPExportOptionsPanel : NSPanel
{
	IBOutlet NSTextField* timeTextField;
	IBOutlet NSStepper* timeStepper;
	IBOutlet NSTextField* fileSizeLabel;
	IBOutlet NSPopUpButton* subTunePopup;
	IBOutlet NSButton* fadeOutButton;
	IBOutlet NSSlider* fadeOutTimeSlider;

	IBOutlet NSPopUpButton* bitRatePopup;
	IBOutlet NSButton* variableBitrateButton;
	IBOutlet NSSlider* qualitySlider;
	
	IBOutlet NSTextField* mp3InfoText;
	
	IBOutlet NSTextView* exportFilesTextView;

	// PSID64 specific
	IBOutlet NSButton* includeStilCommentButton;
	IBOutlet NSButton* blankScreenButton;
	IBOutlet NSButton* useCompressionButton;
	
	SPExportController* exportController;
	ExportSettings* exportSettings;
}

@property (NS_NONATOMIC_IOSONLY, strong) SPExportController *exportController;

- (void) updateTimeTextField:(int)timeInSeconds;
- (void) updateFileSizeTextField;
- (void) updateFileListTextView:(NSArray*)exportItems;

@property (NS_NONATOMIC_IOSONLY, readonly) ExportSettings* exportSettings;

- (IBAction) clickTimeStepper:(id)sender;
- (IBAction) timeChanged:(id)sender;
- (IBAction) subTunePopupChanged:(id)sender;
- (IBAction) fadeOutButtonClicked:(id)sender;
- (IBAction) fadeOutTimeChanged:(id)sender;
- (IBAction) bitRatePopupChanged:(id)sender;
- (IBAction) variableBitrateButtonClicked:(id)sender;
- (IBAction) qualitySliderMoved:(id)sender;
- (IBAction) stilCommentButtonClicked:(id)sender;
- (IBAction) blankScreenButtonClicked:(id)sender;
- (IBAction) compressionButtonClicked:(id)sender;

- (void) timeChangedNotification:(NSNotification*)notification;

@end
