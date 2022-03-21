#import "SPPlayerWindow.h"
#import "SPInfoWindowController.h"
#import "SPInfoContainerView.h"
#import "SPInfoView.h"
#import "SPPreferencesController.h"


@implementation SPInfoWindowController


// ----------------------------------------------------------------------------
- (id) init
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
	[[self window] setAlphaValue:0.0f];
	[[self window] orderOut:self];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowWillClose:)
												 name:NSWindowWillCloseNotification
											   object:[self window]];
}


// ----------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	[[ownerWindow infoWindowMenuItem] setTitle:@"Show Info Window"];
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
	infoScrollView = [containerView enclosingScrollView];
	infoScrollViewFrame = [infoScrollView frame];
	
	if (gPreferences.mInfoWindowVisible)
	{
		[[self window] setAlphaValue:1.0f];
		[[self window] orderFront:self];
	}
	else
	{
		[[self window] setAlphaValue:0.0f];
		[[self window] orderOut:self];
	}
}


// ----------------------------------------------------------------------------
- (void) toggleWindow:(id)sender
// ----------------------------------------------------------------------------
{
	if ([containerView attachedToMainWindow])
		[self togglePane:sender];
	
	NSArray* animations = nil;
	NSWindow* window = [self window];
	if ([window isVisible])
	{
		[sender setTitle:@"Show Info Window"];
		[window setAlphaValue:1.0f];
		NSDictionary* windowFadeOut = [NSDictionary dictionaryWithObjectsAndKeys:window, NSViewAnimationTargetKey,
																			NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
		animations = [NSArray arrayWithObjects:windowFadeOut, nil];	
		gPreferences.mInfoWindowVisible = NO;
	}	
	else
	{
		[sender setTitle:@"Hide Info Window"];
		[window setAlphaValue:0.0f];
		[window orderFront:self];
		NSDictionary* windowFadeIn = [NSDictionary dictionaryWithObjectsAndKeys:window, NSViewAnimationTargetKey,
																			NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil];
		animations = [NSArray arrayWithObjects:windowFadeIn, nil];	
		gPreferences.mInfoWindowVisible = YES;
	}
	
    NSViewAnimation* animation = [[NSViewAnimation alloc] initWithViewAnimations:animations];
    [animation setAnimationBlockingMode:NSAnimationNonblocking];
	
    [animation setDuration:0.2];
	[animation setDelegate:self];
    [animation startAnimation];
}


// ----------------------------------------------------------------------------
- (void) togglePane:(id)sender
// ----------------------------------------------------------------------------
{
	if ([containerView attachedToMainWindow])
	{
		[infoScrollView setFrame:infoScrollViewFrame];
		[containerView setHasDarkBackground:YES];
		[containerView setAttachedToMainWindow:NO];
		[ownerWindow removeRightSubView];
		[[[self window] contentView] addSubview:infoScrollView];
		[containerView positionSubviewsWithAnimation:NO];
	}
	else
	{
		[[self window] orderOut:self];
		infoScrollViewFrame = [infoScrollView frame];
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
	NSArray* animations = [(NSViewAnimation*)animation viewAnimations];
	NSDictionary* windowFade = [animations objectAtIndex:0];
	if ([windowFade objectForKey:NSViewAnimationEffectKey] == NSViewAnimationFadeOutEffect)
		[[self window] orderOut:self];
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
