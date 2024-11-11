//
//  SPBigOscilloscopeView.h
//  SIDPLAY
//
//  Created by Alexander Coers on 12.04.24.
//

#import <Cocoa/Cocoa.h>
#import "PlayerInfoProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class SPPlayerWindow;

@interface SPBigOscilloscopeView : NSView
{
    SPPlayerWindow* playerW;
    NSString *currentTitle;
    NSString *currentAuthor;
    BOOL updateNeeded;
    int hSample;
}
- (void)setPlayerWindow:(SPPlayerWindow*)newPlayerW;
- (void)updatePlayerInfo;
@end
NS_ASSUME_NONNULL_END
