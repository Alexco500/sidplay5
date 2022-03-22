
#import "SPAnalyzerWindowController.h"
#import "SPAnalyzerTimelineView.h"


@implementation SPAnalyzerTimelineView


// ----------------------------------------------------------------------------
- (instancetype)initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{
        showTimeInSeconds = YES;
		cursorImage = nil;
    }
    return self;
}


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	cursorImage = [NSImage imageNamed:@"playback_cursor"];	
	showTimeInSeconds = YES;
}


// ----------------------------------------------------------------------------
- (BOOL) isOpaque
// ----------------------------------------------------------------------------
{
	return YES;
}


// ----------------------------------------------------------------------------
- (void) setShowTimeInSeconds:(BOOL)inTimeInSeconds
// ----------------------------------------------------------------------------
{
	showTimeInSeconds = inTimeInSeconds;
	[self setNeedsDisplay:YES];
}


// ----------------------------------------------------------------------------
- (void)drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	if (![SPAnalyzerWindowController isInitialized])
		return;
	
	NSRect bounds = self.bounds;

	NSGradient* gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.463f alpha:1.0f] endingColor:[NSColor colorWithCalibratedWhite:0.333f alpha:1.0f]];
    [gradient drawInRect:bounds angle:-90];

	[NSBezierPath setDefaultLineWidth:1.0f];

	NSColor* drawColor = [NSColor colorWithCalibratedWhite:0.580f alpha:1.0f];
	[drawColor set];

	float textIntensity = 0.7f;
	CGContextRef context = (CGContextRef) [NSGraphicsContext currentContext].graphicsPort;
	CGContextSelectFont(context, "Monaco", 9.0f, kCGEncodingMacRoman); 
	CGContextSetRGBStrokeColor(context, textIntensity, textIntensity, textIntensity, 1.0f);
	CGContextSetRGBFillColor(context, textIntensity, textIntensity, textIntensity, 1.0f);
	CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1.0f, 1.0f));
	CGContextSetTextDrawingMode(context, kCGTextFill);
	//CGSize shadowOffset = {1.0f, -1.0f};
	//CGContextSetShadow(context, shadowOffset, 1.0f);
	
	double cycleToPixelRatio = [[SPAnalyzerWindowController sharedInstance] cycleToPixelRatio];
	double totalTime = [[SPAnalyzerWindowController sharedInstance] totalCaptureTime];
	
	const double lineHeight = 10.0f;
	double desiredStep = 100.0f;
	double pixelStep = desiredStep * cycleToPixelRatio;

	if (pixelStep < desiredStep)
		pixelStep *= floorf(desiredStep / pixelStep);
	
	double timeStep = pixelStep / cycleToPixelRatio;
	
	NSBezierPath* path = [NSBezierPath bezierPath];
	
	double drawStart = rect.origin.x - pixelStep;
	double drawEnd = rect.origin.x + NSWidth(rect) + pixelStep;
	
	double clockRate = [[SPAnalyzerWindowController sharedInstance] effectiveCpuClockRate];
	
	for (double t = 0.0; t < totalTime; t += timeStep)
	{
		double x = t * cycleToPixelRatio;
		
		if (x >= drawStart && x <= drawEnd)
		{
			float xpos = floorf(bounds.origin.x + x) + 0.5f;
			
			[path moveToPoint:NSMakePoint(xpos, bounds.origin.y)];
			[path lineToPoint:NSMakePoint(xpos, bounds.origin.y + lineHeight)];
			
			[path stroke];

			int timeInCycles = floorf(t);
			char stringBuffer[16];
			if (showTimeInSeconds)
			{
				double timeInSeconds = double(timeInCycles) / clockRate;
				int minutes = floor(timeInSeconds / 60);
				timeInSeconds -= minutes * 60;
				int seconds = floor(timeInSeconds);
				timeInSeconds -= seconds;
				int milliseconds = floor(timeInSeconds * 1000);
				snprintf(stringBuffer, 15, "%02d'%02d\"%03d", minutes, seconds, milliseconds);
			}
			else
				snprintf(stringBuffer, 15, "%d", timeInCycles);

			CGContextShowTextAtPoint(context, xpos + 2.0f, bounds.origin.y + 6.0f, stringBuffer, strlen(stringBuffer));			
		}
	}
	
	float width = cursorImage.size.width;
	float height = cursorImage.size.height;
	NSRect imageRect = NSMakeRect(0.0f, 0.0f, width, height);
	[cursorImage setFlipped:self.flipped];
	
	double cursorPosition = [[SPAnalyzerWindowController sharedInstance] cursorPosition];
	float cursorXPos = floorf(cursorPosition * cycleToPixelRatio);
	if (cursorXPos > (NSMinX(rect) - 5.0f) && cursorXPos < (NSMaxX(rect) + 5.0f))
	{
		NSRect imageFrame = NSMakeRect(cursorXPos - 5.0f, 0.0f, width, height);
		[cursorImage drawInRect:imageFrame fromRect:imageRect operation:NSCompositeSourceOver fraction:1.0f];
	}
}


// ----------------------------------------------------------------------------
- (void) mouseDown:(NSEvent*) event
// ----------------------------------------------------------------------------
{
	NSPoint mousePosition = event.locationInWindow;
	NSPoint mousePositionInView = [self convertPoint:mousePosition fromView:nil];

	double cycleToPixelRatio = [[SPAnalyzerWindowController sharedInstance] cycleToPixelRatio];

	NSInteger cursorPosition = mousePositionInView.x / cycleToPixelRatio;
	[[SPAnalyzerWindowController sharedInstance] setCursorPosition:cursorPosition];
}


// ----------------------------------------------------------------------------
- (void) mouseDragged:(NSEvent*) event
// ----------------------------------------------------------------------------
{
	NSPoint mousePosition = event.locationInWindow;
	NSPoint mousePositionInView = [self convertPoint:mousePosition fromView:nil];
	
	double cycleToPixelRatio = [[SPAnalyzerWindowController sharedInstance] cycleToPixelRatio];
	
	NSInteger cursorPosition = mousePositionInView.x / cycleToPixelRatio;
	[[SPAnalyzerWindowController sharedInstance] setCursorPosition:cursorPosition];
}


@end
