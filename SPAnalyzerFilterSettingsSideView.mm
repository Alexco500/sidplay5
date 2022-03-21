
#import "SPAnalyzerWindowController.h"
#import "SPAnalyzerFilterSettingsSideView.h"


@implementation SPAnalyzerFilterSettingsSideView


// ----------------------------------------------------------------------------
- (id) initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{
        // Initialization code here.
    }
    return self;
}


// ----------------------------------------------------------------------------
- (void) drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	NSRect bounds = [self bounds];
	
	[[SPAnalyzerWindowController sharedInstance] drawBackgroundInRect:bounds];
}

@end
