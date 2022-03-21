#import <Cocoa/Cocoa.h>


@interface SPSynchronizedScrollView : NSScrollView
{
	NSScrollView* horizontalMasterScrollView;
	NSScrollView* verticalMasterScrollView;
}

- (void) setHorizontalMasterScrollView:(NSScrollView*)scrollview;
- (void) setVerticalMasterScrollView:(NSScrollView*)scrollview;

- (void) unhookFromHorizontalMasterScrollView;
- (void) unhookFromVerticalMasterScrollView;

- (void) horizontalMasterScrollViewContentBoundsDidChange:(NSNotification *)notification;
- (void) verticalMasterScrollViewContentBoundsDidChange:(NSNotification *)notification;

@end
