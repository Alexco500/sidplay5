
#import "SPAnalyzerFrequencySideView.h"


@implementation SPAnalyzerFrequencySideView


// ----------------------------------------------------------------------------
- (instancetype)initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{
		keyboardImage = nil;
    }
    return self;
}


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	keyboardImage = [NSImage imageNamed:@"keyboard"];	
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
	NSRect bounds = self.bounds;

	float width = keyboardImage.size.width;
	float height = keyboardImage.size.height;
	NSRect imageRect = NSMakeRect(0.0f, 0.0f, width, height);
	[keyboardImage setFlipped:self.flipped];

	float textIntensity = 0.0f;
	CGContextRef context = (CGContextRef) [NSGraphicsContext currentContext].graphicsPort;
	CGContextSelectFont(context, "Lucida Grande", 9.0f, kCGEncodingMacRoman); 
	CGContextSetRGBStrokeColor(context, textIntensity, textIntensity, textIntensity, 1.0f);
	CGContextSetRGBFillColor(context, textIntensity, textIntensity, textIntensity, 1.0f);
	CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1.0f, 1.0f));
	CGContextSetTextDrawingMode(context, kCGTextFill);
	
	for (int i = 0; i < 8; i++)
	{
		NSRect imageFrame = NSMakeRect(0.0f, i * height, width, height);
		[keyboardImage drawInRect:imageFrame fromRect:imageRect operation:NSCompositeCopy fraction:1.0f];

		char stringBuffer[16];
		snprintf(stringBuffer, 15, "C%d", i+1);
		CGContextShowTextAtPoint(context, 20.0f, i * height + 3.0f, stringBuffer, strlen(stringBuffer));			
	}
}


@end
