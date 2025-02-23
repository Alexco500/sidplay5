#import "SPMiniPlayerWindow.h"
#import "SPStatusDisplayView.h"
#import "SPPlayerWindow.h"


@implementation SPMiniPlayerWindow


// ----------------------------------------------------------------------------
- (void) awakeFromNib
{
    [self setFloatingPanel:NO];
}

// ----------------------------------------------------------------------------
- (void) keyDown:(NSEvent*)event
{
    [mainWindow keyDown:event];
}

// ----------------------------------------------------------------------------
- (void) keyUp:(NSEvent*)event
{
    [mainWindow keyUp:event];
}

// ----------------------------------------------------------------------------
- (IBAction) nextSubtune:(id)sender
{
    [mainWindow nextSubtune:sender];
}

// ----------------------------------------------------------------------------
- (IBAction) previousSubtune:(id)sender
{
    [mainWindow previousSubtune:sender];
}

@end
