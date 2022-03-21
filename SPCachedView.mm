
#import "SPCachedView.h"


@implementation SPCachedView


// ----------------------------------------------------------------------------
- (id) initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{

    }
    return self;
}


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	imageCache = nil;
	drawIntoImageCache = NO;
	useImageCache = YES;
}


// ----------------------------------------------------------------------------
- (void) setFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
	NSRect old = [self frame];
	[super setFrame:frame];
	
	if (NSEqualRects(old, frame))
		return;

	if (useImageCache)
		[self flushImageCache];
}


// ----------------------------------------------------------------------------
- (void) flushImageCache
// ----------------------------------------------------------------------------
{
	imageCache = nil;
	if (NSWidth([self frame]) < 2048.0f)
		drawIntoImageCache = YES;
}


// ----------------------------------------------------------------------------
- (void) drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	NSRect bounds = [self bounds];
	
	if (NSWidth(bounds) == 0.0f || NSHeight(bounds) == 0.0f)
		return;
	
	if (drawIntoImageCache)
	{
		imageCache = [[NSImage alloc] initWithSize:bounds.size];
		[imageCache lockFocus];
		
		[self drawContent:bounds];
		
		// Store as a bitmap.
		NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:bounds];
		
		[imageCache unlockFocus];
		[imageCache addRepresentation:rep];
		
		drawIntoImageCache = NO;
	}
	
	if(imageCache != nil && useImageCache)
	{
		NSSize imageCacheSize  = [imageCache size];
		NSRect imageRect = NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
		[imageCache drawInRect:rect fromRect:imageRect operation:NSCompositeCopy fraction:1.0];
		
#ifdef SP_DEBUG		
		NSMutableDictionary * attribs = [NSMutableDictionary dictionaryWithCapacity:2];
		[attribs setObject:[NSFont labelFontOfSize:18.0] forKey:NSFontAttributeName];
		[attribs setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
		NSAttributedString* msg = [[NSAttributedString alloc] initWithString:@"Image" attributes:attribs];
		[msg drawAtPoint:NSMakePoint(10.0f, 10.0f)];
#endif
	}
	else
	{
		[self drawContent:rect];
	}
}


// ----------------------------------------------------------------------------
- (void)drawContent:(NSRect)rect
// ----------------------------------------------------------------------------
{
	// Implemented by derived classes
}


@end
