#import <Cocoa/Cocoa.h>
#import "PlayerLibSidplay.h"
#import "AudioDriver.h"

@class SPPlayerWindow;
@class SPSynchronizedScrollView;
@class SPAnalyzerFrequencyView;
@class SPAnalyzerPulseWidthView;
@class SPAnalyzerTimelineView;
@class SPAnalyzerSampleView;
@class SPAnalyzerWaveformView;
@class SPAnalyzerAdsrView;

template <typename taStreamType>
struct SidRegisterState
{
	SidRegisterState() : mTimeStamp(0) { }
	SidRegisterState(taStreamType inValue, unsigned int inTimeStamp) : mValue(inValue), mTimeStamp(inTimeStamp) { }
	
	taStreamType mValue;
	unsigned int mTimeStamp;
};

typedef SidRegisterState<unsigned int>			SidFrequencyState;
typedef SidRegisterState<unsigned short>		SidPulseWidthState;
typedef SidRegisterState<bool>					SidGateState;
typedef SidRegisterState<unsigned char>			SidWaveformState;
typedef SidRegisterState<unsigned short>		SidAdsrState;
typedef SidRegisterState<unsigned char>			SidFilterSettingsState;
typedef SidRegisterState<unsigned char>			SidFilterResonanceState;
typedef SidRegisterState<unsigned short>		SidFilterCutoffState;
typedef SidRegisterState<unsigned char>			SidVolumeState;

typedef std::vector< SidFrequencyState >		SidFrequencyStream;
typedef std::vector< SidPulseWidthState >		SidPulseWidthStream;
typedef std::vector< SidGateState >				SidGateStream;
typedef std::vector< SidWaveformState >			SidWaveformStream;
typedef std::vector< SidAdsrState >				SidAdsrStream;
typedef std::vector< SidFilterSettingsState >	SidFilterSettingsStream;
typedef std::vector< SidFilterResonanceState >	SidFilterResonanceStream;
typedef std::vector< SidFilterCutoffState >		SidFilterCutoffStream;
typedef std::vector< SidVolumeState >			SidVolumeStream;


#define SID_VOICE_COUNT 3


inline double gPixelToCycle(double inPixel, double inCycleToPixelRatio)		{ return inPixel / inCycleToPixelRatio; }
inline double gCycleToPixel(double inCycle, double inCycleToPixelRatio)		{ return inCycle * inCycleToPixelRatio; }

enum SPAnalyzerTimeUnit
{
	SP_TIME_UNIT_SECONDS = 0,
	SP_TIME_UNIT_CYCLES
};


@interface SPAnalyzerWindowController : NSWindowController
{
	SPPlayerWindow* ownerWindow;
	PlayerLibSidplay* player;
	AudioDriver* audioDriver;
	BOOL analyzeInProgress;
	char* renderBuffer;
	int renderBufferSampleCount;
	BOOL analyzeResultAvailable;
	
	SidFrequencyStream frequencyStream[SID_VOICE_COUNT];
	SidPulseWidthStream pulseWidthStream[SID_VOICE_COUNT];
	SidGateStream gateStream[SID_VOICE_COUNT];
	SidWaveformStream waveformStream[SID_VOICE_COUNT];
	SidAdsrStream adsrStream[SID_VOICE_COUNT];
	SidFilterSettingsStream* filterSettingsStream;
	SidFilterResonanceStream* filterResonanceStream;
	SidFilterCutoffStream* filterCutoffStream;
	SidVolumeStream* volumeStream;
	
	BOOL voiceEnabled[SID_VOICE_COUNT];
	SPAnalyzerTimeUnit timeUnit;
	
	NSUInteger totalCaptureTime;
	double cycleToPixelRatio;
	NSInteger cursorPosition;
	float previousCursorPixelPosition;
	
	NSUInteger effectiveSampleRate;
	double effectiveCpuClockRate;

	NSTimer* playbackCursorUpdateTimer;
	
	IBOutlet NSButton* playPauseButton;
	IBOutlet NSTextField* playbackPositionTextField;
	
	IBOutlet NSTextView* dumpTextView;
	IBOutlet NSProgressIndicator* analyzeProgressIndicator;

	IBOutlet SPSynchronizedScrollView* timelineScrollView;
	IBOutlet NSView* timelineDocumentView;

	IBOutlet SPSynchronizedScrollView* sampleScrollView;
	IBOutlet NSView* sampleDocumentView;
	
	IBOutlet SPSynchronizedScrollView* frequencyContentScrollView;
	IBOutlet NSView* frequencyDocumentView;
	IBOutlet SPSynchronizedScrollView* frequencySideContentScrollView;
	IBOutlet NSView* frequencySideDocumentView;

	IBOutlet NSView* parameterDocumentView;
	IBOutlet SPSynchronizedScrollView* parameterContentScrollView;
	IBOutlet NSView* parameterSideDocumentView;
	IBOutlet SPSynchronizedScrollView* parameterSideContentScrollView;

	IBOutlet NSSlider* horizontalZoomSlider;

	IBOutlet SPAnalyzerTimelineView* timelineView;
	IBOutlet SPAnalyzerFrequencyView* frequencyView;
	IBOutlet SPAnalyzerPulseWidthView* pulseWidthView;
	IBOutlet SPAnalyzerSampleView* sampleView;
	IBOutlet SPAnalyzerWaveformView* waveformView;
	IBOutlet SPAnalyzerAdsrView* adsrView;
}

+ (SPAnalyzerWindowController*) sharedInstance;
+ (BOOL) isInitialized;

- (void) toggleWindow:(id)sender;
- (void) setOwnerWindow:(SPPlayerWindow*)window;
- (void) adjustScrollViewContentSizes;
- (void) updateZoomFactor:(double)inZoomFactor;
- (void) updateToolbarTimeDisplay;
- (void) setPlayPauseButtonToPause:(BOOL)pause;
- (void) reloadData;

- (void) drawBackgroundInRect:(NSRect)rect;
- (void) drawCursorInRect:(NSRect)rect;

- (IBAction) clickCaptureButton:(id)sender;
- (IBAction) clickReverseButton:(id)sender;
- (IBAction) clickPlayPauseButton:(id)sender;
- (IBAction) clickFastForwardButton:(id)sender;
- (IBAction) clickVoice1State:(id)sender;
- (IBAction) clickVoice2State:(id)sender;
- (IBAction) clickVoice3State:(id)sender;
- (IBAction) clickTimeUnitControl:(id)sender;
- (IBAction) moveVolumeSlider:(id)sender;
- (IBAction) changeHorizontalZoomFactor:(id)sender;

- (void) analyzeThread:(id)inObject;
- (void) analyzeComplete:(id)inObject;
- (void) analyzeProgressNotification:(id)progress;

- (NSUInteger) totalCaptureTime;
- (double) cycleToPixelRatio;

- (NSInteger) cursorPosition;
- (void) setCursorPosition:(NSInteger)inCursorPosition;
- (void) setCursorPosition:(NSInteger)inCursorPosition andUpdateScrollViews:(BOOL)scrollToCursor;

- (BOOL) voiceEnabled:(int)inVoice;

- (BOOL) analyzeResultAvailable;
- (SidFrequencyStream*) frequencyStream:(int)inVoice;
- (SidPulseWidthStream*) pulseWidthStream:(int)inVoice;
- (SidGateStream*) gateStream:(int)inVoice;
- (SidWaveformStream*) waveformStream:(int)inVoice;
- (SidAdsrStream*) adsrStream:(int)inVoice;
- (SidFilterSettingsStream*) filterSettingsStream;
- (SidFilterResonanceStream*) filterResonanceStream;
- (SidFilterCutoffStream*) filterCutoffStream;
- (SidVolumeStream*) volumeStream;

- (short*) renderBufferSamples;
- (int) renderBufferSampleCount;

- (NSUInteger) effectiveSampleRate;
- (double) effectiveCpuClockRate;


@end


@interface SPAnalyzerWindow : NSWindow
{
	
}

@end


@interface SPAnalyzerSplitView : NSSplitView
{
	
}
	
@end


@interface SPAnalyzerRectView : NSView
{
	
}

@end



