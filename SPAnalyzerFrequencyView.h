#import <Cocoa/Cocoa.h>
#import "PlayerLibSidplay.h"
#import "SPCachedView.h"


@interface SPAnalyzerFrequencyView : SPCachedView
{
	NSColor* ebonyRowColor;
	NSColor* ivoryRowColor;
	NSColor* lineColor;
	NSColor* verticalLineColor;
	NSColor* voiceColors[3][3];
}

- (void) drawRect:(NSRect)rect;
- (void) drawContent:(NSRect)rect;

@end
