#import <Cocoa/Cocoa.h>
#import "SPInfoView.h"
#import "PlayerLibSidplayWrapper.h"


@interface SPComposerPhotoView : SPInfoView <NSURLDownloadDelegate>
{
	PlayerLibSidplayWrapper* player;
	BOOL imageDownloadInProgress;
	NSURLDownload* imageDownload;
	NSString* currentImageLocation;
	
	IBOutlet NSImageView* photoView;
}

- (void) updateTuneInfo:(NSNotification *)aNotification;
- (void) updateWithComposerName:(NSString*)composer;
- (void) setImageFromPath:(NSString*)imagePath;

@end
