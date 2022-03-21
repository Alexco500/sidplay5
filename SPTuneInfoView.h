#import <Cocoa/Cocoa.h>
#import "SPInfoView.h"

@interface SPTuneInfoView : SPInfoView
{

}

@end


class PlayerLibSidplay;

@interface SPTuneInfoContentView : NSView
{
//	IBOutlet NSTableView* tuneInfoTableView;
//	NSMutableArray* tuneInfoHeaders;
//	NSMutableArray* tuneInfoStrings;
	
	PlayerLibSidplay* player;
}

- (void) updateTuneInfo:(NSNotification *)aNotification;
//- (void) containerBackgroundChanged:(NSNotification *)aNotification;

@end
