#import <Cocoa/Cocoa.h>
#import "SPInfoView.h"


class PlayerLibSidplay;


@interface SPComposerPhotoView : SPInfoView <NSURLDownloadDelegate>
{
	PlayerLibSidplay* player;
	BOOL imageDownloadInProgress;
	NSURLDownload* imageDownload;
	NSString* currentImageLocation;
	
	IBOutlet NSImageView* photoView;
}

- (void) updateTuneInfo:(NSNotification *)aNotification;
- (void) updateWithComposerName:(NSString*)composer;
- (void) setImageFromPath:(NSString*)imagePath;

@end
