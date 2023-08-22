#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>


@class SPInfoView;
@class SPPlayerWindow;
@class SPColorProvider;

extern NSString* SPInfoContainerBackgroundChangedNotification;

enum
{
	TUNEINFO_CONTAINER_INDEX = 0,
	OSCILLOSCOPE_CONTAINER_INDEX,
	SIDREGISTER_CONTAINER_INDEX,
	MIXER_CONTAINER_INDEX,
	COMPOSER_CONTAINER_INDEX,
    FILTER_CONTAINER_INDEX,

	MAX_CONTAINER_INDEX 
};


@interface SPInfoContainerView : NSView <NSAnimationDelegate>
{
	BOOL hasDarkBackground;
	BOOL attachedToMainWindow;
	SPPlayerWindow* ownerWindow;
	SPColorProvider* colorProvider;
	
	SPInfoView* infoViews[MAX_CONTAINER_INDEX];
	NSRect infoViewTargetFrames[MAX_CONTAINER_INDEX];
	NSRect containerTargetFrame;
	NSRect windowTargetFrame;
	NSRect unrestrictedWindowFrame;
	NSViewAnimation* animation;

	IBOutlet NSView* oscilloscopeView;
	IBOutlet NSView* sidRegisterView;
}

- (void) updateAnimatedViews;

- (void) addInfoView:(SPInfoView*)view atIndex:(NSInteger)index;
- (void) positionSubviewsWithAnimation:(BOOL)animate;
- (void) startResizeAnimation;
- (void) adjustConstraintsOfWindow:(NSWindow*)window withMaxWidth:(float)maxWidth andMaxHeight:(float)maxHeight;

@property (NS_NONATOMIC_IOSONLY, strong) SPPlayerWindow *ownerWindow;

@property (NS_NONATOMIC_IOSONLY) BOOL hasDarkBackground;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSColor *backgroundColor;

@property (NS_NONATOMIC_IOSONLY) BOOL attachedToMainWindow;

@property (NS_NONATOMIC_IOSONLY, getter=isAnimating, readonly) BOOL animating;

@end
