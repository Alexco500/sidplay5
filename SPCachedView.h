
#import <Cocoa/Cocoa.h>


@interface SPCachedView : NSView
{
	BOOL drawIntoImageCache;
	BOOL useImageCache;
	NSImage* imageCache;
	
}

- (void) flushImageCache;
- (void) drawContent:(NSRect)rect;

@end
