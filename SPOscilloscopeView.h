#import <Cocoa/Cocoa.h>
#import "SPInfoView.h"

@interface SPOscilloscopeView : SPInfoView
{

}

@end


@interface SPOscilloscopeContentView : NSView
{
	BOOL bloomFilterActive;
}

@end
