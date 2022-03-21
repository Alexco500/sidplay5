
#import "SPAnalyzerWindowController.h"
#import "SPAnalyzerScaleSideView.h"


@implementation SPAnalyzerScaleSideView


// ----------------------------------------------------------------------------
- (id)initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{
		stepValues = nil;
    }
    return self;
}


// ----------------------------------------------------------------------------
- (NSArray*) stepValues
// ----------------------------------------------------------------------------
{
	return stepValues;
}

// ----------------------------------------------------------------------------
- (void) setStepValues:(NSArray*)inStepValues
// ----------------------------------------------------------------------------
{
	stepValues = inStepValues;
}


// ----------------------------------------------------------------------------
- (const char*) formatString
// ----------------------------------------------------------------------------
{
	return formatString;
}


// ----------------------------------------------------------------------------
- (void) setFormatString:(const char*)inFormatString
// ----------------------------------------------------------------------------
{
	formatString = inFormatString;
}


// ----------------------------------------------------------------------------
- (BOOL) isOpaque
// ----------------------------------------------------------------------------
{
	return YES;
}


// ----------------------------------------------------------------------------
- (void)drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	NSRect bounds = [self bounds];
	
	[[SPAnalyzerWindowController sharedInstance] drawBackgroundInRect:bounds];
	
	[NSBezierPath setDefaultLineWidth:1.0f];
	
	NSColor* lineColor1 = [NSColor colorWithCalibratedWhite:0.20f alpha:1.0f];
	NSColor* lineColor2 = [NSColor colorWithCalibratedWhite:0.51f alpha:1.0f];
	
	float textIntensity = 0.51f;
	CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
	CGContextSelectFont(context, "Monaco", 8.0f, kCGEncodingMacRoman); 
	CGContextSetRGBStrokeColor(context, textIntensity, textIntensity, textIntensity, 1.0f);
	CGContextSetRGBFillColor(context, textIntensity, textIntensity, textIntensity, 1.0f);
	CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1.0f, 1.0f));
	
	float yOffset = 6.0f;
	float drawHeight = NSHeight(bounds) - yOffset * 2.0f;
	
	NSBezierPath* path1 = [NSBezierPath bezierPath];
	NSBezierPath* path2 = [NSBezierPath bezierPath];
	float previousYPos = -100.0f;

	if (drawHeight < 14.0f)
		return;
	
	for (int i = 0; i < [stepValues count]; i++)
	{
		float yPos = floorf(drawHeight * float(i) / float([stepValues count] - 1) + yOffset) + 0.5f;
		
		[lineColor1 set];
		[path1 moveToPoint:NSMakePoint(bounds.origin.x + rect.size.width - 7.0f, yPos + 1.0f)];
		[path1 lineToPoint:NSMakePoint(bounds.origin.x + rect.size.width - 1.0f, yPos + 1.0f)];
		[path1 stroke];
		
		[lineColor2 set];
		[path2 moveToPoint:NSMakePoint(bounds.origin.x + rect.size.width - 7.0f, yPos)];
		[path2 lineToPoint:NSMakePoint(bounds.origin.x + rect.size.width - 1.0f, yPos)];
		[path2 stroke];

		if ((yPos - previousYPos) < 9.0f)
			continue;
		
		previousYPos = yPos;
		
		if (drawHeight >= 18.0f)
		{
			char stringBuffer[16];
			snprintf(stringBuffer, 15, formatString, [(NSNumber*)[stepValues objectAtIndex:i] integerValue]);

			CGPoint startPoint = CGContextGetTextPosition(context);
			CGContextSetTextDrawingMode(context, kCGTextInvisible);
			CGContextShowTextAtPoint(context, startPoint.x, startPoint.y, stringBuffer, strlen(stringBuffer));		
			CGPoint endPoint = CGContextGetTextPosition(context);
			float width = endPoint.x - startPoint.x;
			CGContextSetTextDrawingMode(context, kCGTextFill);
			
			CGContextShowTextAtPoint(context, bounds.origin.x + bounds.size.width - width - 9.0f, yPos - 3.0f, stringBuffer, strlen(stringBuffer));			
		}
	}
}

@end
