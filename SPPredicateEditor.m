#import "SPPredicateEditor.h"


@implementation SPPredicateEditor


// ----------------------------------------------------------------------------
- (void)drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	[super drawRect:rect];
	
	NSColor* darkColor = [NSColor colorWithCalibratedWhite:0.729f alpha:1.0f];
	NSColor* brightColor = [NSColor colorWithCalibratedWhite:0.973f alpha:1.0f];

	float ypos = 0.5f;

	[NSBezierPath setDefaultLineWidth:1.0f];
	NSBezierPath* path = [NSBezierPath bezierPath];
	
	[path moveToPoint:NSMakePoint(rect.origin.x, ypos)];
	[path lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, ypos)];
	
	[darkColor set];	
	[path stroke];
	
	ypos += 1.0f;
	path = [NSBezierPath bezierPath];
	[path moveToPoint:NSMakePoint(rect.origin.x, ypos)];
	[path lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, ypos)];

	[brightColor set];	
	[path stroke];
}

@end
