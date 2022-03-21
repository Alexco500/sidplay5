#import "SPVisualizerView.h"
#import "SPPlayerWindow.h"
#import "PlayerLibSidplay.h"


@implementation SPVisualizerView


// ----------------------------------------------------------------------------
- (id) init
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		player = NULL;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTuneInfo:) name:SPTuneChangedNotification object:nil];
	}
	return self;
}



// ----------------------------------------------------------------------------
- (void) update:(const VisualizerState*) state
// ----------------------------------------------------------------------------
{
	[self setValue:[NSNumber numberWithBool:state->voice[0].Gatebit] forInputKey:@"Voice1Gate"];
	[self setValue:[NSNumber numberWithBool:state->voice[1].Gatebit] forInputKey:@"Voice2Gate"];
	[self setValue:[NSNumber numberWithBool:state->voice[2].Gatebit] forInputKey:@"Voice3Gate"];
	[self setValue:[NSNumber numberWithInt:state->voice[0].Frequency] forInputKey:@"Voice1Frequency"];
	[self setValue:[NSNumber numberWithInt:state->voice[1].Frequency] forInputKey:@"Voice2Frequency"];
	[self setValue:[NSNumber numberWithInt:state->voice[2].Frequency] forInputKey:@"Voice3Frequency"];
	[self setValue:[NSNumber numberWithInt:state->voice[0].Pulsewidth] forInputKey:@"Voice1Pulsewidth"];
	[self setValue:[NSNumber numberWithInt:state->voice[1].Pulsewidth] forInputKey:@"Voice2Pulsewidth"];
	[self setValue:[NSNumber numberWithInt:state->voice[2].Pulsewidth] forInputKey:@"Voice3Pulsewidth"];
	[self setValue:[NSNumber numberWithInt:state->voice[0].Waveform] forInputKey:@"Voice1Waveform"];
	[self setValue:[NSNumber numberWithInt:state->voice[1].Waveform] forInputKey:@"Voice2Waveform"];
	[self setValue:[NSNumber numberWithInt:state->voice[2].Waveform] forInputKey:@"Voice3Waveform"];
	[self setValue:[NSNumber numberWithInt:state->voice[0].Attack] forInputKey:@"Voice1Attack"];
	[self setValue:[NSNumber numberWithInt:state->voice[1].Attack] forInputKey:@"Voice2Attack"];
	[self setValue:[NSNumber numberWithInt:state->voice[2].Attack] forInputKey:@"Voice3Attack"];
	[self setValue:[NSNumber numberWithInt:state->voice[0].Decay] forInputKey:@"Voice1Decay"];
	[self setValue:[NSNumber numberWithInt:state->voice[1].Decay] forInputKey:@"Voice2Decay"];
	[self setValue:[NSNumber numberWithInt:state->voice[2].Decay] forInputKey:@"Voice3Decay"];
	[self setValue:[NSNumber numberWithInt:state->voice[0].Sustain] forInputKey:@"Voice1Sustain"];
	[self setValue:[NSNumber numberWithInt:state->voice[1].Sustain] forInputKey:@"Voice2Sustain"];
	[self setValue:[NSNumber numberWithInt:state->voice[2].Sustain] forInputKey:@"Voice3Sustain"];
	[self setValue:[NSNumber numberWithInt:state->voice[0].Release] forInputKey:@"Voice1Release"];
	[self setValue:[NSNumber numberWithInt:state->voice[1].Release] forInputKey:@"Voice2Release"];
	[self setValue:[NSNumber numberWithInt:state->voice[2].Release] forInputKey:@"Voice3Release"];

	[self setValue:[NSNumber numberWithInt:state->FilterCutoff] forInputKey:@"FilterCutoff"];
	[self setValue:[NSNumber numberWithInt:state->FilterResonance] forInputKey:@"FilterResonance"];
	[self setValue:[NSNumber numberWithInt:state->FilterVoices] forInputKey:@"FilterVoices"];
	[self setValue:[NSNumber numberWithInt:state->FilterMode] forInputKey:@"FilterMode"];
	[self setValue:[NSNumber numberWithInt:state->Volume] forInputKey:@"Volume"];
}


// ----------------------------------------------------------------------------
- (void) updateTuneInfo:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	if (player == NULL)
	{
		SPPlayerWindow* window = (SPPlayerWindow*) [self window];
		if (window == nil)
			return;
			
		player = (PlayerLibSidplay*) [window player];
	}

	if (player == NULL)
		return;
		
	[self setValue:[NSString stringWithCString:player->getCurrentTitle() encoding:NSISOLatin1StringEncoding] forInputKey:@"Title"];
	[self setValue:[NSString stringWithCString:player->getCurrentAuthor() encoding:NSISOLatin1StringEncoding] forInputKey:@"Author"];
	[self setValue:[NSString stringWithCString:player->getCurrentReleaseInfo() encoding:NSISOLatin1StringEncoding] forInputKey:@"Released"];
	[self setValue:[NSString stringWithCString:player->getCurrentChipModel() encoding:NSISOLatin1StringEncoding] forInputKey:@"ChipName"];
	
	[self setValue:[NSNumber numberWithBool:YES] forInputKey:@"TuneInfoSignal"];
	[NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(disableTuneInfoSignal) userInfo:nil repeats:NO];
}


// ----------------------------------------------------------------------------
- (void) disableTuneInfoSignal
// ----------------------------------------------------------------------------
{
	[self setValue:[NSNumber numberWithBool:NO] forInputKey:@"TuneInfoSignal"];
}


// ----------------------------------------------------------------------------
- (void) mouseDown:(NSEvent*)event
// ----------------------------------------------------------------------------
{

}

@end
