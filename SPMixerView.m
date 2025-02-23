#import "SPInfoContainerView.h"
#import "SPMixerView.h"
#import "SPPlayerWindow.h"
#import "PlayerLibSidplayWrapper.h"
#import "SPPreferencesController.h"


@implementation SPMixerView

// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[super awakeFromNib];

	index = MIXER_CONTAINER_INDEX;
	height = 120.0f;
	[self setCollapsed:gPreferences.mMixerCollapsed];

	[self containerBackgroundChanged:nil];
	
	for (int i = 0; i < 3; i++)
	{
		voiceMuted[i] = NO;
		voiceSoloed[i] = NO;
		currentVolumes[i] = 1.0f;
		preMuteVolumes[i] = 1.0f;
	}

	voiceSliders[0] = voice1Slider;
	voiceSliders[1] = voice2Slider;
	voiceSliders[2] = voice3Slider;

	player = NULL;

	[container addInfoView:self atIndex:index];
}


// ----------------------------------------------------------------------------
- (void) containerBackgroundChanged:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	[super containerBackgroundChanged:aNotification];

	if ([container hasDarkBackground])
	{
		voice1Label.textColor = [NSColor whiteColor];
		voice2Label.textColor = [NSColor whiteColor];
		voice3Label.textColor = [NSColor whiteColor];
	}
	else
	{
		voice1Label.textColor = [NSColor blackColor];
		voice2Label.textColor = [NSColor blackColor];
		voice3Label.textColor = [NSColor blackColor];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) changeVoice1Volume:(id)sender
// ----------------------------------------------------------------------------
{
	currentVolumes[0] = [sender floatValue];
	[self setVoice:0 toVolume:currentVolumes[0]];
}


// ----------------------------------------------------------------------------
- (IBAction) changeVoice2Volume:(id)sender
// ----------------------------------------------------------------------------
{
	currentVolumes[1] = [sender floatValue];
	[self setVoice:1 toVolume:currentVolumes[1]];
}


// ----------------------------------------------------------------------------
- (IBAction) changeVoice3Volume:(id)sender
// ----------------------------------------------------------------------------
{
	currentVolumes[2] = [sender floatValue];
	[self setVoice:2 toVolume:currentVolumes[2]];
}


// ----------------------------------------------------------------------------
- (IBAction) clickVoice1Mute:(id)sender
// ----------------------------------------------------------------------------
{
	[self toggleMute:0];
}


// ----------------------------------------------------------------------------
- (IBAction) clickVoice2Mute:(id)sender
// ----------------------------------------------------------------------------
{
	[self toggleMute:1];
}


// ----------------------------------------------------------------------------
- (IBAction) clickVoice3Mute:(id)sender
// ----------------------------------------------------------------------------
{
	[self toggleMute:2];
}


// ----------------------------------------------------------------------------
- (IBAction) clickVoice1Solo:(id)sender
// ----------------------------------------------------------------------------
{
	[self toggleSolo:0];
}


// ----------------------------------------------------------------------------
- (IBAction) clickVoice2Solo:(id)sender
// ----------------------------------------------------------------------------
{
	[self toggleSolo:1];
}


// ----------------------------------------------------------------------------
- (IBAction) clickVoice3Solo:(id)sender
// ----------------------------------------------------------------------------
{
	[self toggleSolo:2];
}


// ----------------------------------------------------------------------------
- (void) setVoice:(int)voice toVolume:(float)volume
// ----------------------------------------------------------------------------
{
	if (!player)
		player = (PlayerLibSidplayWrapper*) [[container ownerWindow] player];

	if (player)
        [player setVoiceVolume:volume forVoice:voice];
}


// ----------------------------------------------------------------------------
- (void) toggleMute:(int)voice
// ----------------------------------------------------------------------------
{
	if (voiceMuted[voice])
	{
		voiceMuted[voice] = false;
		[self setVoice:voice toVolume:preMuteVolumes[voice]];
		//removed, volume per voice is not supported
        //[voiceSliders[voice] setEnabled:YES];
		voiceSliders[voice].floatValue = preMuteVolumes[voice];
	} 
	else
	{
		voiceMuted[voice] = true;
		preMuteVolumes[voice] = currentVolumes[voice];
		[self setVoice:voice toVolume:0.0f];
		[voiceSliders[voice] setEnabled:NO];
		voiceSliders[voice].floatValue = 0.0f;
	}
}


// ----------------------------------------------------------------------------
- (void) toggleSolo:(int)voice
// ----------------------------------------------------------------------------
{
	voiceSoloed[voice] = !voiceSoloed[voice];
	
	switch ( voice )
	{
		case 0:
			if (voiceSoloed[voice])
			{
				if (voiceSoloed[1]) [self toggleSolo:1];
				if (voiceSoloed[2])	[self toggleSolo:2];

				voice1Mute.state = NSOffState;
				voice2Mute.state = NSOnState;
				voice3Mute.state = NSOnState;
				voice1Solo.state = NSOnState;
				voice2Solo.state = NSOffState;
				voice3Solo.state = NSOffState;

				if (voiceMuted[0]) [self toggleMute:0];
				if (!voiceMuted[1]) [self toggleMute:1];
				if (!voiceMuted[2]) [self toggleMute:2];
			} 
			else
			{
				voice1Mute.state = NSOffState;
				voice2Mute.state = NSOffState;
				voice3Mute.state = NSOffState;
				voice1Solo.state = NSOffState;
				voice2Solo.state = NSOffState;
				voice3Solo.state = NSOffState;

				if (voiceMuted[0]) [self toggleMute:0];
				if (voiceMuted[1]) [self toggleMute:1];
				if (voiceMuted[2]) [self toggleMute:2];
			}
			break;

		case 1:
			if (voiceSoloed[voice])
			{
				if (voiceSoloed[0]) [self toggleSolo:0];
				if (voiceSoloed[2])	[self toggleSolo:2];

				voice1Mute.state = NSOnState;
				voice2Mute.state = NSOffState;
				voice3Mute.state = NSOnState;
				voice1Solo.state = NSOffState;
				voice2Solo.state = NSOnState;
				voice3Solo.state = NSOffState;

				if (!voiceMuted[0]) [self toggleMute:0];
				if (voiceMuted[1]) [self toggleMute:1];
				if (!voiceMuted[2]) [self toggleMute:2];
			} 
			else
			{
				voice1Mute.state = NSOffState;
				voice2Mute.state = NSOffState;
				voice3Mute.state = NSOffState;
				voice1Solo.state = NSOffState;
				voice2Solo.state = NSOffState;
				voice3Solo.state = NSOffState;

				if (voiceMuted[0]) [self toggleMute:0];
				if (voiceMuted[1]) [self toggleMute:1];
				if (voiceMuted[2]) [self toggleMute:2];
			}
			break;

		case 2:
			if (voiceSoloed[voice])
			{
				if (voiceSoloed[0]) [self toggleSolo:0];
				if (voiceSoloed[1])	[self toggleSolo:1];

				voice1Mute.state = NSOnState;
				voice2Mute.state = NSOnState;
				voice3Mute.state = NSOffState;
				voice1Solo.state = NSOffState;
				voice2Solo.state = NSOffState;
				voice3Solo.state = NSOnState;

				if (!voiceMuted[0]) [self toggleMute:0];
				if (!voiceMuted[1]) [self toggleMute:1];
				if (voiceMuted[2]) [self toggleMute:2];
			} 
			else
			{
				voice1Mute.state = NSOffState;
				voice2Mute.state = NSOffState;
				voice3Mute.state = NSOffState;
				voice1Solo.state = NSOffState;
				voice2Solo.state = NSOffState;
				voice3Solo.state = NSOffState;

				if (voiceMuted[0]) [self toggleMute:0];
				if (voiceMuted[1]) [self toggleMute:1];
				if (voiceMuted[2]) [self toggleMute:2];
			}
			break;
	}
}



@end
