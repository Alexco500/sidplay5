//
//  PreviewViewController.h
//  SIDTuneViewer
//
//  Created by Alexander Coers on 29.09.23.
//

#import <Cocoa/Cocoa.h>
#import "PlayerWrapper.h"
#import "PVScopeView.h"

@interface PreviewViewController : NSViewController {
    PlayerWrapper *playerW;
    NSData *tuneBuffer;
    NSTimer *uiUpdateTimer;
    unsigned int myInstance;
    BOOL isPlaying;
    
    IBOutlet NSTextField *tuneInfoView;
    IBOutlet PVScopeView *scopeView;
}
-(void)updateScopeView;
@end
