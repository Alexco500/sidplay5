#import <Cocoa/Cocoa.h>


@interface SPInfoView : NSView
{
	SPInfoContainerView* container;
	int index;
	BOOL isCollapsed;
	float collapsedHeight;
	float height;
	
	IBOutlet NSButton* disclosureTriangle;
	IBOutlet NSTextField* titleText;
}

- (IBAction) collapse:(id)sender;

@property (NS_NONATOMIC_IOSONLY, getter=isCollapsed) BOOL collapsed;

@property (NS_NONATOMIC_IOSONLY, readonly) float currentHeight;
@property (NS_NONATOMIC_IOSONLY, readonly) float collapsedHeight;
@property (NS_NONATOMIC_IOSONLY, readonly) float height;

@property (NS_NONATOMIC_IOSONLY, readonly, strong) SPInfoContainerView *container;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) NSButton *disclosureTriangle;

- (void) containerBackgroundChanged:(NSNotification *)aNotification;

@end


@interface SPDisclosureCell : NSButtonCell
{
	BOOL backgroundIsDark;
}

- (void) setBackgroundIsDark:(BOOL)flag;

@end


