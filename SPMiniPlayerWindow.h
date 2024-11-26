#import <Cocoa/Cocoa.h>

@class SPPlayerWindow;
@class SPStatusDisplayView;


@interface SPMiniPlayerWindow : NSPanel
{
    IBOutlet SPPlayerWindow* mainWindow;
}

@end
