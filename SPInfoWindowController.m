#import "SPPlayerWindow.h"
#import "SPInfoWindowController.h"
#import "SPInfoContainerView.h"
#import "SPInfoView.h"
#import "SPPreferencesController.h"


@implementation SPInfoWindowController


// ----------------------------------------------------------------------------
- (instancetype) init
// ----------------------------------------------------------------------------
{
	if (self = [super initWithWindowNibName:@"InfoWindow"])
	{
		ownerWindow = nil;
		infoScrollView = nil;
		[self showWindow:self];
	}
	
	return self;
}


// ----------------------------------------------------------------------------
- (void) windowDidLoad
// ----------------------------------------------------------------------------
{
	self.window.alphaValue = 0.0f;
	[self.window orderOut:self];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowWillClose:)
												 name:NSWindowWillCloseNotification
											   object:self.window];
}


// ----------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	[ownerWindow infoWindowMenuItem].title = @"Show Info Window";
	gPreferences.mInfoWindowVisible = NO;
}	


// ----------------------------------------------------------------------------
- (NSString*) windowFrameAutosaveName
// ----------------------------------------------------------------------------
{
	return @"Sidplay Info Panel";
}


// ----------------------------------------------------------------------------
- (void) setOwnerWindow:(SPPlayerWindow*)window
// ----------------------------------------------------------------------------
{
	ownerWindow = window;
	[containerView setOwnerWindow:ownerWindow];
	infoScrollView = containerView.enclosingScrollView;
	infoScrollViewFrame = infoScrollView.frame;
	
	if (gPreferences.mInfoWindowVisible)
	{
		self.window.alphaValue = 1.0f;
		[self.window orderFront:self];
	}
	else
	{
		self.window.alphaValue = 0.0f;
		[self.window orderOut:self];
	}
}


// ----------------------------------------------------------------------------
- (void) toggleWindow:(id)sender
// ----------------------------------------------------------------------------
{
	if ([containerView attachedToMainWindow])
		[self togglePane:sender];
	
	NSArray* animations = nil;
	NSWindow* window = self.window;
	if (window.visible)
	{
		[sender setTitle:@"Show Info Window"];
		window.alphaValue = 1.0f;
		NSDictionary* windowFadeOut = @{NSViewAnimationTargetKey: window,
																			NSViewAnimationEffectKey: NSViewAnimationFadeOutEffect};
		animations = @[windowFadeOut];	
		gPreferences.mInfoWindowVisible = NO;
	}	
	else
	{
		[sender setTitle:@"Hide Info Window"];
		window.alphaValue = 0.0f;
		[window orderFront:self];
		NSDictionary* windowFadeIn = @{NSViewAnimationTargetKey: window,
																			NSViewAnimationEffectKey: NSViewAnimationFadeInEffect};
		animations = @[windowFadeIn];	
		gPreferences.mInfoWindowVisible = YES;
	}
	
    NSViewAnimation* animation = [[NSViewAnimation alloc] initWithViewAnimations:animations];
    animation.animationBlockingMode = NSAnimationNonblocking;
	
    animation.duration = 0.2;
	animation.delegate = self;
    [animation startAnimation];
}


// ----------------------------------------------------------------------------
- (void) togglePane:(id)sender
// ----------------------------------------------------------------------------
{
	if ([containerView attachedToMainWindow])
	{
		infoScrollView.frame = infoScrollViewFrame;
		[containerView setHasDarkBackground:YES];
		[containerView setAttachedToMainWindow:NO];
		[ownerWindow removeRightSubView];
		[self.window.contentView addSubview:infoScrollView];
		[containerView positionSubviewsWithAnimation:NO];
	}
	else
	{
		[self.window orderOut:self];
		infoScrollViewFrame = infoScrollView.frame;
		[containerView setHasDarkBackground:NO];
		[containerView setAttachedToMainWindow:YES];
		[ownerWindow addInfoContainerView:infoScrollView];
		[containerView positionSubviewsWithAnimation:NO];
	}
}


// ----------------------------------------------------------------------------
- (SPInfoContainerView*) containerView
// ----------------------------------------------------------------------------
{
	return containerView;
}


#pragma mark -
#pragma mark NSAnimation delegate methods

// ----------------------------------------------------------------------------
- (void) animationDidEnd:(NSAnimation *)animation
// ----------------------------------------------------------------------------
{
	NSArray* animations = ((NSViewAnimation*)animation).viewAnimations;
	NSDictionary* windowFade = animations[0];
	if (windowFade[NSViewAnimationEffectKey] == NSViewAnimationFadeOutEffect)
		[self.window orderOut:self];
}


@end


#pragma mark -
@implementation SPInfoPanel


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[self setFloatingPanel:YES];
}


// ----------------------------------------------------------------------------
- (BOOL) canBecomeKeyWindow
// ----------------------------------------------------------------------------
{
	return NO;
}


@end
