
#import <Cocoa/Cocoa.h>
#import "SPCachedView.h"


@interface SPAnalyzerAdsrView : SPCachedView
{
	NSColor* backgroundColor;
	NSColor* verticalLineColor;
	NSColor* seperatorColor;
	NSColor* voiceColors[3];

	NSImage* voiceParamKnobImage[3];
}

- (void) drawRect:(NSRect)rect;
- (void) drawContent:(NSRect)rect;

@end
