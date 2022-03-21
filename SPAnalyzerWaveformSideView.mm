
#import "SPAnalyzerWindowController.h"

#import "SPAnalyzerWaveformSideView.h"


@implementation SPAnalyzerWaveformSideView


// ----------------------------------------------------------------------------
- (id) initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{
		waveformImage = nil;
    }
    return self;
}


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	waveformImage = [NSImage imageNamed:@"waveform_side"];	
}


// ----------------------------------------------------------------------------
- (BOOL) isOpaque
// ----------------------------------------------------------------------------
{
	return YES;
}


// ----------------------------------------------------------------------------
- (void) drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	NSRect bounds = [self bounds];
	
	[[SPAnalyzerWindowController sharedInstance] drawBackgroundInRect:bounds];

	float width = [waveformImage size].width;
	float height = [waveformImage size].height;
	NSRect imageRect = NSMakeRect(0.0f, 0.0f, width, height);
	[waveformImage setFlipped:[self isFlipped]];
	
	NSRect imageFrame = NSMakeRect(14.0f, 32.0f, width, height);
	[waveformImage drawInRect:imageFrame fromRect:imageRect operation:NSCompositeSourceOver fraction:1.0f];
	
	float textIntensity = 0.51f;
	CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
	CGContextSelectFont(context, "Monaco", 9.0f, kCGEncodingMacRoman); 
	CGContextSetRGBStrokeColor(context, textIntensity, textIntensity, textIntensity, 1.0f);
	CGContextSetRGBFillColor(context, textIntensity, textIntensity, textIntensity, 1.0f);
	CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1.0f, 1.0f));
	CGContextSetTextDrawingMode(context, kCGTextFill);
	//CGContextSetShouldAntialias(context, false);
	
	const char* strings[3] = { "SYNC", "RING", "TEST" };
	
	for (int i = 0; i < 3; i++)
	{
		CGContextShowTextAtPoint(context, 7.0f, i * 10.0f + 3.0f, strings[i], strlen(strings[i]));			
	}
}

@end
