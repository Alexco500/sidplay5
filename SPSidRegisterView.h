#import <Cocoa/Cocoa.h>
#import "SPInfoView.h"

@interface SPSidRegisterView : SPInfoView
{

}

@end


class PlayerLibSidplay;

@interface SPSidRegisterContentView : NSView
{
	PlayerLibSidplay* player;
	unsigned char* registers;
}

- (void) drawVoice:(int)voice intoContext:(CGContextRef)context atHorizontalPosition:(float)xpos andVerticalPosition:(float)ypos;


@end
