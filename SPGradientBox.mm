#import "SPGradientBox.h"


@implementation SPGradientBox

// ----------------------------------------------------------------------------
- (void) drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	NSGradient* gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.96f alpha:1.0f] endingColor:[NSColor colorWithCalibratedWhite:0.89f alpha:1.0f]];
    [gradient drawInRect:self.bounds angle:-90];
}

@end


@implementation SPDarkGradientBox

// ----------------------------------------------------------------------------
- (void) drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	NSGradient* gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.76f alpha:1.0f] endingColor:[NSColor colorWithCalibratedWhite:0.59f alpha:1.0f]];
    [gradient drawInRect:self.bounds angle:-90];

	NSColor* darkColor = [NSColor colorWithCalibratedWhite:0.3f alpha:1.0f];
	
	NSRect bounds = self.bounds;
	float ypos = bounds.origin.y + bounds.size.height;
	
	[NSBezierPath setDefaultLineWidth:1.0f];
	NSBezierPath* path = [NSBezierPath bezierPath];
	
	[path moveToPoint:NSMakePoint(rect.origin.x, ypos)];
	[path lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, ypos)];
	
	[darkColor set];	
	[path stroke];
}

@end
