#import "SPInfoContainerView.h"
#import "SPColorProvider.h"
#import "SPPreferencesController.h"
#import "SPInfoView.h"


@implementation SPInfoView


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[[SPPreferencesController sharedInstance] load];
	
	index = 0;
	collapsedHeight = 19.0f;
	height = 128.0f;
	container = (SPInfoContainerView*) [self superview];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(containerBackgroundChanged:) name:SPInfoContainerBackgroundChangedNotification object:nil];
	[self containerBackgroundChanged:nil];
}


// ----------------------------------------------------------------------------
- (void) mouseDown:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	NSPoint mousePosition = [event locationInWindow];
	NSPoint mousePositionInView = [self convertPoint:mousePosition fromView:nil];
	
	if ((mousePositionInView.y > ([self currentHeight] - 15.0f)) && ([event clickCount] > 1))
	{
		BOOL collapsed = !isCollapsed;
		[disclosureTriangle setState:collapsed ? 0 : 1];
		[self collapse:disclosureTriangle];
	}
}


// ----------------------------------------------------------------------------
- (void) drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
//	rect = [self bounds];
//
//	NSColor* darkColor = nil;
//	NSColor* brightColor = nil;
//	if ([container hasDarkBackground])
//	{
//		darkColor = [NSColor colorWithDeviceRed:0.117f green:0.117f blue:0.117f alpha:1.0f];
//		brightColor = [NSColor colorWithDeviceRed:0.321f green:0.321f blue:0.321f alpha:1.0f];
//	}
//	else
//	{
//		darkColor = [NSColor colorWithDeviceRed:0.381f green:0.381f blue:0.381f alpha:1.0f];
//		brightColor = [NSColor colorWithDeviceRed:0.838f green:0.838f blue:0.838f alpha:1.0f];
//	}
//
//	float middle = rect.size.width * 0.5f;
//	float ditchSize = 5.5f;
//	float ypos = rect.origin.y + rect.size.height - 1.5f;
//
//	[NSBezierPath setDefaultLineWidth:1.0f];
//	NSBezierPath* path = [NSBezierPath bezierPath];
//	
//	[path moveToPoint:NSMakePoint(rect.origin.x, ypos)];
//	[path lineToPoint:NSMakePoint(rect.origin.x + (middle - ditchSize), ypos)];
//	[path lineToPoint:NSMakePoint(rect.origin.x + middle, ypos - ditchSize)];
//	[path lineToPoint:NSMakePoint(rect.origin.x + (middle + ditchSize), ypos)];
//	[path lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, ypos)];
//	
//	[darkColor set];	
//	[path stroke];
//
//	ypos -= 1.0f;
//	path = [NSBezierPath bezierPath];
//	[path moveToPoint:NSMakePoint(rect.origin.x, ypos)];
//	[path lineToPoint:NSMakePoint(rect.origin.x + (middle - ditchSize), ypos)];
//	[path lineToPoint:NSMakePoint(rect.origin.x + middle, ypos - ditchSize)];
//	[path lineToPoint:NSMakePoint(rect.origin.x + (middle + ditchSize), ypos)];
//	[path lineToPoint:NSMakePoint(rect.origin.x + rect.size.width - 1.0f, ypos)];
//
//	[brightColor set];	
//	[path stroke];
    
	[super drawRect:rect];
}


// ----------------------------------------------------------------------------
- (IBAction) collapse:(id)sender
// ----------------------------------------------------------------------------
{
	int state = [sender state];

	// Better solution: disable disclosure cells of all info views during animation
	if ([container isAnimating])
	{
		[sender setState:(state == NSOnState) ? NSOffState : NSOnState];
		return;
	}
		
	if (state == NSOnState)
		[self setCollapsed:NO];
	else
		[self setCollapsed:YES];

	switch (index)
	{
		case TUNEINFO_CONTAINER_INDEX:
			gPreferences.mTuneInfoCollapsed = isCollapsed;
			break;
		case OSCILLOSCOPE_CONTAINER_INDEX:
			gPreferences.mOscilloscopeCollapsed = isCollapsed;
			break;
		case SIDREGISTER_CONTAINER_INDEX:
			gPreferences.mSidRegistersCollapsed = isCollapsed;
			break;
		case MIXER_CONTAINER_INDEX:
			gPreferences.mMixerCollapsed = isCollapsed;
			break;
		case FILTER_CONTAINER_INDEX:
			gPreferences.mFilterControlCollapsed = isCollapsed;
			break;
//		case COMPOSER_CONTAINER_INDEX:
//			gPreferences.mComposerPhotoCollapsed = isCollapsed;
			break;
	}

	[disclosureTriangle setEnabled:NO];
	[container positionSubviewsWithAnimation:YES];	
}


// ----------------------------------------------------------------------------
- (BOOL) isCollapsed
// ----------------------------------------------------------------------------
{
	return isCollapsed;
}


// ----------------------------------------------------------------------------
- (void) setCollapsed:(BOOL)flag
// ----------------------------------------------------------------------------
{
	isCollapsed = flag;
	[disclosureTriangle setState:flag ? 0 : 1];
}


// ----------------------------------------------------------------------------
- (float) currentHeight
// ----------------------------------------------------------------------------
{
	return isCollapsed ? collapsedHeight : height;
}


// ----------------------------------------------------------------------------
- (float) collapsedHeight
// ----------------------------------------------------------------------------
{
	return collapsedHeight;
}


// ----------------------------------------------------------------------------
- (float) height
// ----------------------------------------------------------------------------
{
	return height;
}


// ----------------------------------------------------------------------------
- (SPInfoContainerView*) container
// ----------------------------------------------------------------------------
{
	return container;
}


// ----------------------------------------------------------------------------
- (NSButton*) disclosureTriangle;
// ----------------------------------------------------------------------------
{
	return disclosureTriangle;
}


// ----------------------------------------------------------------------------
- (void) containerBackgroundChanged:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	if ([[disclosureTriangle cell] class] == [SPDisclosureCell class])
	{
		SPDisclosureCell* cell = [disclosureTriangle cell];

		if ([container hasDarkBackground])
		{
			[cell setBackgroundIsDark:YES];
			[cell setBackgroundColor:[container backgroundColor]];

			[titleText setTextColor:[NSColor whiteColor]];
		}
		else
		{
			[cell setBackgroundIsDark:NO];
			[titleText setTextColor:[NSColor blackColor]];
		}
	}
}

@end

#pragma mark -
@implementation SPDisclosureCell


static NSImage* SPHudDisclosureCollapsed = nil;
static NSImage* SPHudDisclosureExpanded = nil;
static NSImage* SPHudDisclosureTransient = nil;


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	if (SPHudDisclosureCollapsed == nil)
	{
		SPHudDisclosureCollapsed = [NSImage imageNamed:@"disclosure_collapsed"];
		SPHudDisclosureExpanded = [NSImage imageNamed:@"disclosure_expanded"];
		SPHudDisclosureTransient = [NSImage imageNamed:@"disclosure_transient"];
	}
}


// ----------------------------------------------------------------------------
- (void) setBackgroundIsDark:(BOOL)flag
// ----------------------------------------------------------------------------
{
	backgroundIsDark = flag;
}


// ----------------------------------------------------------------------------
- (void) highlight:(BOOL)flag withFrame:(NSRect)cellFrame inView:(NSView *)controlView
// ----------------------------------------------------------------------------
{
	if (backgroundIsDark)
	{
		NSImage* image = [(NSButton*)controlView state] == 1 ? SPHudDisclosureExpanded : SPHudDisclosureCollapsed;
		NSRect imageRect = NSMakeRect(0.0f, 0.0f, [image size].width, [image size].height);
		NSRect imageFrame = imageRect;
		imageFrame.origin.x = (cellFrame.size.width - imageRect.size.width) / 2.0f;
		imageFrame.origin.y = (cellFrame.size.height - imageRect.size.height) / 2.0f;
			
		[image setFlipped:[controlView isFlipped]];
		if (flag)
		{
			[image drawInRect:imageFrame fromRect:imageRect operation:NSCompositePlusDarker fraction:1.0f];
			[image drawInRect:imageFrame fromRect:imageRect operation:NSCompositePlusDarker fraction:1.0f];
			[image drawInRect:imageFrame fromRect:imageRect operation:NSCompositePlusDarker fraction:1.0f];
		}
		else
			[image drawInRect:imageFrame fromRect:imageRect operation:NSCompositeSourceOver fraction:1.0f];
	}
	else
	{
		[super highlight:flag withFrame:cellFrame inView:controlView];
	}
}


// ----------------------------------------------------------------------------
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
// ----------------------------------------------------------------------------
{
	if (backgroundIsDark)
	{
		NSImage* image = [(NSButton*)controlView state] == 1 ? SPHudDisclosureExpanded : SPHudDisclosureCollapsed;
		NSRect imageRect = NSMakeRect(0.0f, 0.0f, [image size].width, [image size].height);
		NSRect imageFrame = imageRect;
		imageFrame.origin.x = (cellFrame.size.width - imageRect.size.width) / 2.0f;
		imageFrame.origin.y = (cellFrame.size.height - imageRect.size.height) / 2.0f;
			
		[image setFlipped:[controlView isFlipped]];
		[image drawInRect:imageFrame fromRect:imageRect operation:NSCompositeSourceOver fraction:1.0f];
	}
	else
		[super drawWithFrame:cellFrame inView:controlView];
}


@end

