
#import "SPAnalyzerWindowController.h"
#import "SPAnalyzerAdsrSideView.h"


@implementation SPAnalyzerAdsrSideView


// ----------------------------------------------------------------------------
- (instancetype) initWithFrame:(NSRect)frame
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
	NSRect bounds = self.bounds;
	
	[[SPAnalyzerWindowController sharedInstance] drawBackgroundInRect:bounds];
}

@end
