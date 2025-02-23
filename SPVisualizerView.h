#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

#import "PlayerLibSidplayWrapper.h"

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
    struct VoiceState voice[3];
	int FilterCutoff;
	int FilterResonance;
	int FilterVoices;
	int FilterMode;
	int Volume;
};


@interface SPVisualizerView : QCView
{
    PlayerLibSidplayWrapper* player;
}

- (void) update:(const struct VisualizerState*) state;
- (void) updateTuneInfo:(NSNotification *)aNotification;
- (void) disableTuneInfoSignal;

@end
