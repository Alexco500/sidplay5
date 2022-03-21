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

- (BOOL) isCollapsed;
- (void) setCollapsed:(BOOL)flag;

- (float) currentHeight;
- (float) collapsedHeight;
- (float) height;

- (SPInfoContainerView*) container;
- (NSButton*) disclosureTriangle;

- (void) containerBackgroundChanged:(NSNotification *)aNotification;

@end


@interface SPDisclosureCell : NSButtonCell
{
	BOOL backgroundIsDark;
}

- (void) setBackgroundIsDark:(BOOL)flag;

@end


