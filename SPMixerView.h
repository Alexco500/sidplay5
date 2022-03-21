#import <Cocoa/Cocoa.h>
#import "SPInfoView.h"


class PlayerLibSidplay;


@interface SPMixerView : SPInfoView
{
	IBOutlet NSTextField* voice1Label;
	IBOutlet NSTextField* voice2Label;
	IBOutlet NSTextField* voice3Label;
	
	IBOutlet NSSlider* voice1Slider;
	IBOutlet NSSlider* voice2Slider;
	IBOutlet NSSlider* voice3Slider;
	
	IBOutlet NSButton* voice1Mute;
	IBOutlet NSButton* voice2Mute;
	IBOutlet NSButton* voice3Mute;

	IBOutlet NSButton* voice1Solo;
	IBOutlet NSButton* voice2Solo;
	IBOutlet NSButton* voice3Solo;
	
	BOOL voiceMuted[3];
	BOOL voiceSoloed[3];
	float currentVolumes[3];
	float preMuteVolumes[3];
	NSSlider* voiceSliders[3];
	PlayerLibSidplay* player;
}

- (void) containerBackgroundChanged:(NSNotification *)aNotification;

- (IBAction) changeVoice1Volume:(id)sender;
- (IBAction) changeVoice2Volume:(id)sender;
- (IBAction) changeVoice3Volume:(id)sender;

- (IBAction) clickVoice1Mute:(id)sender;
- (IBAction) clickVoice2Mute:(id)sender;
- (IBAction) clickVoice3Mute:(id)sender;

- (IBAction) clickVoice1Solo:(id)sender;
- (IBAction) clickVoice2Solo:(id)sender;
- (IBAction) clickVoice3Solo:(id)sender;

- (void) setVoice:(int)voice toVolume:(float)volume;
- (void) toggleMute:(int)voice;
- (void) toggleSolo:(int)voice;


@end
