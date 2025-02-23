#import "SPSynchronizedScrollView.h"


@implementation SPSynchronizedScrollView


// ----------------------------------------------------------------------------
- (void) setHorizontalMasterScrollView:(NSScrollView*)scrollview
// ----------------------------------------------------------------------------
{
    // stop an existing scroll view synchronizing
    [self unhookFromHorizontalMasterScrollView];
	
    // don't retain the watched view, because we assume that it will be retained by the view hierarchy for as long as we're around.
    horizontalMasterScrollView = scrollview;

    // get the content view of the
    NSClipView* masterContentView = horizontalMasterScrollView.contentView;
	
    // Make sure the watched view is sending bounds changed notifications (which is probably does anyway, but calling this again won't hurt).
    [masterContentView setPostsBoundsChangedNotifications:YES];
	
    // a register for those notifications on the synchronized content view.
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(horizontalMasterScrollViewContentBoundsDidChange:)
												 name:NSViewBoundsDidChangeNotification
											   object:masterContentView];
}


// ----------------------------------------------------------------------------
- (void) setVerticalMasterScrollView:(NSScrollView*)scrollview
// ----------------------------------------------------------------------------
{
    // stop an existing scroll view synchronizing
    [self unhookFromVerticalMasterScrollView];
	
    // don't retain the watched view, because we assume that it will be retained by the view hierarchy for as long as we're around.
    verticalMasterScrollView = scrollview;
	
    // get the content view of the
    NSClipView* masterContentView = verticalMasterScrollView.contentView;
	
    // Make sure the watched view is sending bounds changed notifications (which is probably does anyway, but calling this again won't hurt).
    [masterContentView setPostsBoundsChangedNotifications:YES];
	
    // a register for those notifications on the synchronized content view.
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(verticalMasterScrollViewContentBoundsDidChange:)
												 name:NSViewBoundsDidChangeNotification
											   object:masterContentView];
}


// ----------------------------------------------------------------------------
- (void) horizontalMasterScrollViewContentBoundsDidChange:(NSNotification *)notification
// ----------------------------------------------------------------------------
{
	/*
	// get the changed content view from the notification
    NSClipView* changedContentView = [notification object];
	
    // get the origin of the NSClipView of the scroll view that we're watching
    NSRect changedBounds = [changedContentView documentVisibleRect];
	
    [[self contentView] scrollRectToVisible:NSMakeRect(0, changedBounds.origin.y, 1, changedBounds.size.height)];
	
    // we have to tell the NSScrollView to update its scrollers
    [self reflectScrolledClipView:[self contentView]];
	*/
	
    // get the changed content view from the notification
    NSView* changedContentView = notification.object;
	
    // get the origin of the NSClipView of the scroll view that we're watching
    NSPoint changedBoundsOrigin = changedContentView.bounds.origin;
	
    // get our current origin
    NSPoint curOffset = self.contentView.bounds.origin;
    NSPoint newOffset = curOffset;
	
	newOffset.x = changedBoundsOrigin.x;
	
    // if our synced position is different from our current position, reposition our content view
    if (!NSEqualPoints(curOffset, changedBoundsOrigin))
    {
		// note that a scroll view watching this one will get notified here
		[self.contentView scrollToPoint:newOffset];
		
		// we have to tell the NSScrollView to update its scrollers
		[self reflectScrolledClipView:self.contentView];
    }
}


// ----------------------------------------------------------------------------
- (void) verticalMasterScrollViewContentBoundsDidChange:(NSNotification *)notification
// ----------------------------------------------------------------------------
{
    // get the changed content view from the notification
    NSView* changedContentView = notification.object;
	
    // get the origin of the NSClipView of the scroll view that we're watching
    NSPoint changedBoundsOrigin = changedContentView.bounds.origin;
	
    // get our current origin
    NSPoint curOffset = self.contentView.bounds.origin;
    NSPoint newOffset = curOffset;
	
	newOffset.y = changedBoundsOrigin.y;
	
    // if our synced position is different from our current position, reposition our content view
    if (!NSEqualPoints(curOffset, changedBoundsOrigin))
    {
		// note that a scroll view watching this one will get notified here
		[self.contentView scrollToPoint:newOffset];
		
		// we have to tell the NSScrollView to update its scrollers
		[self reflectScrolledClipView:self.contentView];
    }
}


// ----------------------------------------------------------------------------
- (void) unhookFromHorizontalMasterScrollView
// ----------------------------------------------------------------------------
{
    if (horizontalMasterScrollView != nil)
	{
		NSView* masterContentView = horizontalMasterScrollView.contentView;
		
		// remove any existing notification registration
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:NSViewBoundsDidChangeNotification
													  object:masterContentView];
		
		horizontalMasterScrollView = nil;
    }
}


// ----------------------------------------------------------------------------
- (void) unhookFromVerticalMasterScrollView
// ----------------------------------------------------------------------------
{
    if (verticalMasterScrollView != nil)
	{
		NSView* masterContentView = verticalMasterScrollView.contentView;
		
		// remove any existing notification registration
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:NSViewBoundsDidChangeNotification
													  object:masterContentView];
		
		verticalMasterScrollView = nil;
    }
}


@end
