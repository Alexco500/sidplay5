#import <Cocoa/Cocoa.h>


@interface SPSourceListCell : NSTextFieldCell
{
    NSImage *image;
	NSProgressIndicator* progressIndicator;
}

@property (NS_NONATOMIC_IOSONLY) NSImage *image;

- (void) setProgressIndicator:(NSProgressIndicator*)indicator;

- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;

@end
