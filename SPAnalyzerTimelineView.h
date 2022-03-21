#import <Cocoa/Cocoa.h>


@interface SPAnalyzerTimelineView : NSView
{
	BOOL showTimeInSeconds;
	NSImage* cursorImage;
}

- (void) setShowTimeInSeconds:(BOOL)inTimeInSeconds;

@end
