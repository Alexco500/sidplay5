
#import <Cocoa/Cocoa.h>
#import "SPCachedView.h"


@interface SPAnalyzerFilterSettingsView : SPCachedView
{
	NSColor* lineColors[2];
	NSColor* verticalLineColor;
	NSColor* seperatorColor;
	NSColor* voiceColors[3];
	
}

- (void) drawRect:(NSRect)rect;
- (void) drawContent:(NSRect)rect;

@end
