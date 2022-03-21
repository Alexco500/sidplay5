#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

struct VoiceState
{
	bool Gatebit;
	int	Frequency;
	int Pulsewidth;
	int Waveform;
	int Attack;
	int Decay;
	int Sustain;
	int Release;
};


struct VisualizerState
{
	VoiceState voice[3];
	int FilterCutoff;
	int FilterResonance;
	int FilterVoices;
	int FilterMode;
	int Volume;
};


class PlayerLibSidplay;

@interface SPVisualizerView : QCView
{
	PlayerLibSidplay* player;
}

- (void) update:(const VisualizerState*) state;
- (void) updateTuneInfo:(NSNotification *)aNotification;
- (void) disableTuneInfoSignal;

@end
