#import "SPInfoContainerView.h"
#import "SPOscilloscopeView.h"
#import "SPColorProvider.h"
#import "SPPlayerWindow.h"
#import "AudioDriver.h"


@implementation SPInfoContainerView

NSString* SPInfoContainerBackgroundChangedNotification = @"InfoContainerBackgroundChanged";

static const float desiredContainerWidth = 415.0f;


// ----------------------------------------------------------------------------
- (instancetype)initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{
		for (int i = 0; i < MAX_CONTAINER_INDEX; i++)
			infoViews[i] = nil;
			
		colorProvider = [SPColorProvider sharedInstance];

		[self setHasDarkBackground:YES];
		attachedToMainWindow = NO;
		ownerWindow = nil;
		oscilloscopeView = nil;
		animation = nil;
	}
    return self;
}


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	//[self setWantsLayer:YES];

	/*
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowDidResize:)
												 name:NSWindowDidResizeNotification
											   object:[self window]];
	*/
}


#define CALLIMP(imp,object,sel,args...) (*imp)(object, @selector(sel) , ##args)
#define GETIMP(class,sel) [class methodForSelector:@selector(sel)];

// ----------------------------------------------------------------------------
- (void) updateAnimatedViews
// ----------------------------------------------------------------------------
{
	if (self.hidden || !self.window.visible || ![NSApplication sharedApplication].active)
		return;
		
	AudioDriver* audioDriver = (AudioDriver*) [ownerWindow audioDriver];
	if (audioDriver == NULL)
		return;

	if (!audioDriver->getIsPlaying())
		return;
			
	//static IMP oscDisplayImp = GETIMP(oscilloscopeView, display);
	//static IMP sidRegisterDisplayImp = GETIMP(sidRegisterView, display);
																		
	SPInfoView* oscilloscopeInfoView = infoViews[OSCILLOSCOPE_CONTAINER_INDEX];
	if (oscilloscopeInfoView && ![oscilloscopeInfoView isCollapsed])
		[oscilloscopeView setNeedsDisplay:YES];
		//CALLIMP(oscDisplayImp, oscilloscopeView, display);

	SPInfoView* sidRegisterInfoView = infoViews[SIDREGISTER_CONTAINER_INDEX];
	if (sidRegisterInfoView && ![sidRegisterInfoView isCollapsed])
		[sidRegisterView setNeedsDisplay:YES];
		//CALLIMP(sidRegisterDisplayImp, sidRegisterView, display);
}


// ----------------------------------------------------------------------------
- (SPPlayerWindow*) ownerWindow
// ----------------------------------------------------------------------------
{
	return ownerWindow;
}


// ----------------------------------------------------------------------------
- (void) setOwnerWindow:(SPPlayerWindow*)window
// ----------------------------------------------------------------------------
{
	ownerWindow = window;
}


// ----------------------------------------------------------------------------
- (BOOL) isFlipped
// ----------------------------------------------------------------------------
{
	return YES;
}


// ----------------------------------------------------------------------------
- (BOOL) hasDarkBackground
// ----------------------------------------------------------------------------
{
	return hasDarkBackground;
}


// ----------------------------------------------------------------------------
- (void) setHasDarkBackground:(BOOL)darkBackground
// ----------------------------------------------------------------------------
{
	hasDarkBackground = darkBackground;
	[colorProvider setProvidesDarkColors:hasDarkBackground];
	[[NSNotificationCenter defaultCenter] postNotificationName:SPInfoContainerBackgroundChangedNotification object:self];
}


// ----------------------------------------------------------------------------
- (NSColor*) backgroundColor
// ----------------------------------------------------------------------------
{
	return [colorProvider backgroundColor];
}


// ----------------------------------------------------------------------------
- (BOOL) attachedToMainWindow
// ----------------------------------------------------------------------------
{
	return attachedToMainWindow;
}


// ----------------------------------------------------------------------------
- (void) setAttachedToMainWindow:(BOOL)attached
// ----------------------------------------------------------------------------
{
	attachedToMainWindow = attached;
}


// ----------------------------------------------------------------------------
- (void) addInfoView:(SPInfoView*)view atIndex:(NSInteger)index
// ----------------------------------------------------------------------------
{
	infoViews[index] = view;
	[self positionSubviewsWithAnimation:NO];
}


// ----------------------------------------------------------------------------
- (void) positionSubviewsWithAnimation:(BOOL)animate
// ----------------------------------------------------------------------------
{
	if ([self isAnimating])
		return;

	float footerHeight = 18.0f;
	float totalHeight = 0.0f;

	float containerWidth = attachedToMainWindow ? self.frame.size.width : desiredContainerWidth;

	// Add up heights of all views currently in container, to get the desired height
	for (int i = 0; i < MAX_CONTAINER_INDEX; i++)
	{
		SPInfoView* infoView = infoViews[i];
		if (infoView == nil)
			continue;
			
		float viewHeight = [infoView currentHeight];
		
		NSRect frame = NSMakeRect(0.0f, totalHeight, containerWidth, viewHeight);
		if (animate)
			infoViewTargetFrames[i] = frame;
		else
			infoView.frame = frame;
		
		totalHeight += viewHeight;
	}

	NSRect containerFrame = self.frame;
	containerFrame.origin.y = 0.0f;
	containerFrame.size.height = attachedToMainWindow ? self.enclosingScrollView.frame.size.height : totalHeight;
	containerFrame.size.width = containerWidth;
	if (animate)
		containerTargetFrame = containerFrame;
	else
		self.frame = containerFrame;

	[self setNeedsDisplay:YES];

	NSWindow* window = self.window;
	NSRect desiredWindowFrame;
	
	if (!attachedToMainWindow)
	{
		float idealWindowHeight = totalHeight + footerHeight;
		NSRect currentWindowFrame = window.frame;
		NSRect windowContentFrame = [window contentRectForFrameRect:currentWindowFrame];
		windowContentFrame.size.height = idealWindowHeight;

		desiredWindowFrame = [window frameRectForContentRect:windowContentFrame];
		float diff = desiredWindowFrame.size.height - currentWindowFrame.size.height;
		desiredWindowFrame.origin.y -= diff;
		unrestrictedWindowFrame = desiredWindowFrame;

		NSScreen* screen = [NSScreen mainScreen];
		NSRect screenFrame = screen.frame;
		NSRect screenVisibleFrame = screen.visibleFrame;
		
		//NSLog(@"screen: %@, visible: %@\n", NSStringFromRect(screenFrame), NSStringFromRect(screenVisibleFrame));
		
		if (desiredWindowFrame.origin.y < screenVisibleFrame.origin.y)
		{
			float overlap = screenVisibleFrame.origin.y - desiredWindowFrame.origin.y;
			desiredWindowFrame.origin.y = screenVisibleFrame.origin.y;
			desiredWindowFrame.size.height -= overlap;
		}

		//NSLog(@"desiredWindowFrame: %@\n", NSStringFromRect(desiredWindowFrame));

		if (animate)
			windowTargetFrame = desiredWindowFrame;
		else
			[window setFrame:desiredWindowFrame display:YES animate:NO];

		if (animate)
			[self startResizeAnimation];
		else 
			[self adjustConstraintsOfWindow:window withMaxWidth:unrestrictedWindowFrame.size.width andMaxHeight:unrestrictedWindowFrame.size.height];
	}
}


// ----------------------------------------------------------------------------
- (void) adjustConstraintsOfWindow:(NSWindow*)window withMaxWidth:(float)maxWidth andMaxHeight:(float)maxHeight
// ----------------------------------------------------------------------------
{
	if (attachedToMainWindow)
		return;

	NSSize maxSize = window.maxSize;
	maxSize.width = maxWidth;
	maxSize.height = maxHeight;

	NSSize minSize = maxSize;
	minSize.height = 128.0f;
	
	window.maxSize = maxSize;
	window.minSize = minSize;
	
	//NSLog(@"maxWidth/minWidth: %f, maxHeight: %f, minHeight: %f\n", maxSize.width, maxSize.height, minSize.height);
}



/*
// ----------------------------------------------------------------------------
- (void)windowDidResize:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	NSWindow* window = [aNotification object];
}	
*/	
	
// ----------------------------------------------------------------------------
- (void)drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
//	[[self backgroundColor] set];
//	rect = NSInsetRect([self bounds], 1.0f, 0.0f);
//	NSRectFill(rect);

	[super drawRect:rect];
}


// ----------------------------------------------------------------------------
- (void) startResizeAnimation
// ----------------------------------------------------------------------------
{
	[self.enclosingScrollView setHasVerticalScroller:NO];
	
	NSMutableArray* animations = [NSMutableArray arrayWithCapacity:MAX_CONTAINER_INDEX + 1];
	for (int i = 0; i < MAX_CONTAINER_INDEX; i++)
	{
		SPInfoView* infoView = infoViews[i];
		if (infoView == nil)
			continue;
		
		NSDictionary* viewResize = @{NSViewAnimationTargetKey: infoView, 
																			  NSViewAnimationEndFrameKey: [NSValue valueWithRect:infoViewTargetFrames[i]]};
		[animations addObject:viewResize];
	}

	NSDictionary* viewResize = @{NSViewAnimationTargetKey: self, 
																		  NSViewAnimationEndFrameKey: [NSValue valueWithRect:containerTargetFrame]};
	[animations addObject:viewResize];

	if (!attachedToMainWindow)
	{
		NSWindow* window = self.window;
		NSDictionary* windowResize = @{NSViewAnimationTargetKey: window,
																				NSViewAnimationEndFrameKey: [NSValue valueWithRect:windowTargetFrame]};

		[animations addObject:windowResize];
	}
	
    animation = [[NSViewAnimation alloc] initWithViewAnimations:animations];
    animation.animationBlockingMode = NSAnimationNonblocking;
	
	BOOL isShiftPressed = NSApp.currentEvent.modifierFlags & NSShiftKeyMask ? YES : NO;

    animation.duration = isShiftPressed ? 3.0 : 0.2;
	animation.delegate = self;
    [animation startAnimation];
}


// ----------------------------------------------------------------------------
- (BOOL) isAnimating
// ----------------------------------------------------------------------------
{
	return (animation != nil && animation.animating);
}


#pragma mark -
#pragma mark NSAnimation delegate methods

// ----------------------------------------------------------------------------
- (void) animationDidEnd:(NSAnimation *)animation
// ----------------------------------------------------------------------------
{
	[self.enclosingScrollView setHasVerticalScroller:YES];

	for (int i = 0; i < MAX_CONTAINER_INDEX; i++)
	{
		SPInfoView* infoView = infoViews[i];
		if (infoView == nil)
			continue;

		[[infoView disclosureTriangle] setEnabled:YES];
	}

	if (!attachedToMainWindow)
	{
		NSWindow* window = self.window;
		float currentMaxWidth = window.maxSize.width;
		float currentMaxHeight = unrestrictedWindowFrame.size.height;
		[self adjustConstraintsOfWindow:window withMaxWidth:currentMaxWidth andMaxHeight:currentMaxHeight];

		if (unrestrictedWindowFrame.size.height > windowTargetFrame.size.height)
		{
			NSRect frame = window.frame;
			NSRect origFrame = frame;
			frame.size.height -= 1.0f;
			[window setFrame:frame display:YES animate:NO];
			[window setFrame:origFrame display:YES animate:NO];
		}
	}
}


@end
