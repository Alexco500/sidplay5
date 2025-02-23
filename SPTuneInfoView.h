#import <Cocoa/Cocoa.h>
#import "SPInfoView.h"
#import "PlayerLibSidplayWrapper.h"

@interface SPTuneInfoView : SPInfoView
{

}

@end



@interface SPTuneInfoContentView : NSView
{
//	IBOutlet NSTableView* tuneInfoTableView;
//	NSMutableArray* tuneInfoHeaders;
//	NSMutableArray* tuneInfoStrings;
	
	PlayerLibSidplayWrapper* player;
}

- (void) updateTuneInfo:(NSNotification *)aNotification;
//- (void) containerBackgroundChanged:(NSNotification *)aNotification;

@end
