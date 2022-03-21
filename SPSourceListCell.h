#import <Cocoa/Cocoa.h>


@interface SPSourceListCell : NSTextFieldCell
{
    NSImage *image;
	NSProgressIndicator* progressIndicator;
}

- (void) setImage:(NSImage *)anImage;
- (NSImage*) image;

- (void) setProgressIndicator:(NSProgressIndicator*)indicator;

- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;

@end
