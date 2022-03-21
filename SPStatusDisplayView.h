#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>


@interface SPQCView : NSOpenGLView
{
	volatile QCRenderer* renderer;
	NSColor* eraseColor;
	volatile BOOL rendererActive;
    volatile BOOL rendererVisible;
}

- (void) loadCompositionFromFile:(NSString*)path;
- (void) setEraseColor:(NSColor*)color;
- (void) startRendering;
- (void) stopRendering;
- (void) renderThread:(id)object;
- (void) setRendererVisible:(BOOL)visible;
- (void) prepareForQuit;

@end


@interface SPStatusDisplayView : NSBox
{
	BOOL inStartState;
	BOOL displayVisible;
	BOOL logoVisible;
	BOOL showRemainingTime;
	BOOL resourcesLoaded;
	NSImage* leftBackGroundImage;
	NSImage* middleBackGroundImage;
	NSImage* rightBackGroundImage;
	NSImage* sidplayLogoImage;
	
	NSImage* smallNumberImages[10];
	NSImage* largeNumberImages[10];
	NSImage* timeDividerImage;
	NSImage* minusImage;
	
	NSImage* leftArrowImage;
	NSImage* rightArrowImage;	
	NSRect leftArrowFrame;
	NSRect rightArrowFrame;
	NSRect subtuneInfoFrame;
	NSRect timeDisplayFrame;
	BOOL mouseDownInLeftArrow;
	BOOL mouseDownInRightArrow;
	BOOL mouseDownInSubtuneInfo;

	NSInteger currentPlaybackSeconds;
	NSInteger currentSonglengthInSeconds;
	NSInteger currentTimeDigits[4];
	NSInteger currentSubtuneDigits[2];
	NSInteger subtuneCountDigits[2];
	
	NSMutableAttributedString* tuneInfo;
	NSMutableAttributedString* subtuneInfo;

	SPQCView* logoView;
}

- (void) loadResources;
- (BOOL) displayVisible;
- (void) setDisplayVisible:(BOOL)visible;
- (BOOL) logoVisible;
- (void) setLogoVisible:(BOOL)visible;
- (void) startLogoRendering;
- (NSOpenGLView*) logoView;
- (void) setPlaybackSeconds:(NSInteger)seconds;
- (void) setTitle:(NSString*)title andAuthor:(NSString*)author andReleaseInfo:(NSString*)releaseInfo andSubtune:(NSInteger)subtune ofSubtunes:(NSInteger)subtuneCount withSonglength:(int)timeInSeconds;
//- (void) updateUvMetersWithVoice1:(float)levelVoice1 andVoice2:(float)levelVoice2 andVoice3:(float)levelVoice3;
- (void) prepareForQuit;


@end
