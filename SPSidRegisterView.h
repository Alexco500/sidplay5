#import <Cocoa/Cocoa.h>
#import "SPInfoView.h"
#import "PlayerLibSidplayWrapper.h"

@interface SPSidRegisterView : SPInfoView
{

}

@end


@interface SPSidRegisterContentView : NSView
{
	PlayerLibSidplayWrapper* player;
	unsigned char* registers;
}

- (void) drawVoice:(int)voice intoContext:(CGContextRef)context atHorizontalPosition:(float)xpos andVerticalPosition:(float)ypos;


@end
