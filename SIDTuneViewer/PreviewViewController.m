//
//  PreviewViewController.m
//  SIDTuneViewer
//
//  Created by Alexander Coers on 29.09.23.
//

#import "PreviewViewController.h"
#import <Quartz/Quartz.h>

#define prefSizeWidth 500
#define prefSizeHeight 200

@interface PreviewViewController () <QLPreviewingController>
    
@end

@implementation PreviewViewController

- (NSString *)nibName {
    return @"PreviewViewController";
}
- (void)viewDidLoad
{
    [super viewDidLoad];
    myInstance = 0;
    if (@available(macOS 10.10, *)) {
        self.preferredContentSize = NSMakeSize(prefSizeWidth, prefSizeHeight);
    } else {
        // Fallback on earlier versions
        NSRect f = self.view.frame;
        f.size.width = prefSizeWidth;
        f.size.height = prefSizeHeight;
        self.view.frame = f;
    }
}
- (void)viewWillDisappear
{
    [uiUpdateTimer invalidate];
    if (playerW)
        [playerW stopPlayerWithInstance:myInstance];
}
- (void)loadView
{
    [super loadView];
    // Do any additional setup after loading the view.
    playerW = [PlayerWrapper sharedPlayer];
    //NSLog(@"PVController loadView: self: %@",self);
    //NSLog(@"PVController loadView: view: %@",[self view]);
    //NSLog(@"PVController loadView: player: %@",playerW);
}
/*
 * Implement this method and set QLSupportsSearchableItems to YES in the Info.plist of the extension if you support CoreSpotlight.
 *
- (void)preparePreviewOfSearchableItemWithIdentifier:(NSString *)identifier queryString:(NSString *)queryString completionHandler:(void (^)(NSError * _Nullable))handler {
    
    // Perform any setup necessary in order to prepare the view.
    
    // Call the completion handler so Quick Look knows that the preview is fully loaded.
    // Quick Look will display a loading spinner while the completion handler is not called.

    handler(nil);
}
*/

- (void)preparePreviewOfFileAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable))handler {
    
    // Add the supported content types to the QLSupportedContentTypes array in the Info.plist of the extension.
    
    // Perform any setup necessary in order to prepare the view.
    
    // Call the completion handler so Quick Look knows that the preview is fully loaded.
    // Quick Look will display a loading spinner while the completion handler is not called.
    BOOL retVal = NO;
    if (url) {
        tuneBuffer = [NSData dataWithContentsOfURL:url];
        retVal = [playerW loadTuneFrom:tuneBuffer asInstance:&myInstance];
    }
    if (retVal)
    {
        //setup player and info box
        NSMutableAttributedString *sidInfo = [[NSMutableAttributedString alloc] initWithString:@"Title \t\t\t"];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:[playerW currentTitle]]];
        
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nAuthor \t\t"]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:[playerW currentAuthor]]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nReleased \t\t"]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:[playerW currentReleaseInfo]]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nSongs \t\t"]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:[[[NSNumber alloc] initWithInt:[playerW subtuneCount]] stringValue]]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:@" (default: "]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:[[[NSNumber alloc] initWithInt:[playerW defaultSubtune]] stringValue]]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:@")\nUsed SIDs \t"]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:[[[NSNumber alloc] initWithInt:[playerW sidChips]] stringValue]]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nSID Model \t"]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:[playerW currentChipModel]]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nLoad Address \t$"]];
        NSString *temp = [NSString stringWithFormat:@"%04X", [playerW currentLoadAddress]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:temp]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nInit Address \t$"]];
        temp = [NSString stringWithFormat:@"%04X", [playerW currentInitAddress]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:temp]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nPlay Address \t$"]];
        temp = [NSString stringWithFormat:@"%04X", [playerW currentPlayAddress]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:temp]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nFormat \t\t"]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:[playerW currentFormat]]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:@"\nFile Size \t\t"]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:[[[NSNumber alloc] initWithInt:[playerW currentFileSize]] stringValue]]];
        [sidInfo appendAttributedString:[[NSAttributedString alloc] initWithString:@" bytes\n"]];
        
        [sidInfo addAttribute:NSFontAttributeName value:[NSFont userFontOfSize:12] range:NSMakeRange(0, [sidInfo length])];
        [tuneInfoView setAttributedStringValue:sidInfo];
        [tuneInfoView setEditable:NO];
        [tuneInfoView setSelectable:NO];
        [scopeView setPlayer:playerW withInstance:myInstance];
        isPlaying = YES;
        uiUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f/60.0f
            target:self
            selector:@selector(updateScopeView)
            userInfo:nil
            repeats:YES];
    }
    handler(nil);
}
-(void)updateScopeView
{
    //cyclic called to update the scope view
    [scopeView setNeedsDisplay:YES];
    
    // Hack to find out if we are the top presented window
    // stop playback and resume if that changes
    NSWindow *window;
    window = [[self view] window];
    if  (window) {
        NSInteger level = [window level];
        BOOL isActive = level > 0;
        if (isActive) {
            if (!isPlaying) {
                isPlaying = [playerW loadTuneFrom:tuneBuffer asInstance:&myInstance];
                //NSLog(@"Instance %u: RESUME:::RESUME with %d", myInstance, isPlaying);

            }
        } else {
            if (isPlaying) {
                //NSLog(@"Instance %u: STOP:::STOP", myInstance);
                //no need to stop, stopping is handled by playerW
                //[playerW stopPlayerWithInstance:myInstance];
                isPlaying = NO;
            }
        }
    }
}

@end

