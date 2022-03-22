#import <Cocoa/Cocoa.h>

@class SPPlayerWindow;
@class SPInfoContainerView;


@interface SPInfoWindowController : NSWindowController <NSAnimationDelegate>
{
	SPPlayerWindow* ownerWindow;
	NSScrollView* infoScrollView;
	NSRect infoScrollViewFrame;
	IBOutlet SPInfoContainerView* containerView;
}

- (void) setOwnerWindow:(SPPlayerWindow*)window;
- (void) toggleWindow:(id)sender;
- (void) togglePane:(id)sender;
- (void) windowWillClose:(NSNotification *)aNotification;

@property (NS_NONATOMIC_IOSONLY, readonly, strong) SPInfoContainerView *containerView;

@end


@interface SPInfoPanel : NSPanel
{

}

@end
