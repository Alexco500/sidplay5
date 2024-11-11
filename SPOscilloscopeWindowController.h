//
//  SPOscilloscopeWindow.h
//  SIDPLAY
//
//  Created by Alexander Coers on 12.04.24.
//

#import <Cocoa/Cocoa.h>
#import "SPBigOscilloscopeView.h"

@class SPPlayerWindow;
NS_ASSUME_NONNULL_BEGIN

@interface SPOscilloscopeWindowController : NSWindowController
{
    SPPlayerWindow* playerWindow;
    SPBigOscilloscopeView* scopeView;
}
@property (NS_NONATOMIC_IOSONLY) SPPlayerWindow* playerWindow;
- (void)toggleWindow:id;
- (void)updateScope;
- (void)updateTuneInfo:(NSNotification *)aNotification;
@end
NS_ASSUME_NONNULL_END
