//
//  PVScopeView.h
//  SIDTuneViewer
//
//  Created by Alexander Coers on 02.10.23.
//

#import <Cocoa/Cocoa.h>
#import "PlayerWrapper.h"
NS_ASSUME_NONNULL_BEGIN

@interface PVScopeView : NSView {
    PlayerWrapper *playerW;
    unsigned int myInstance;
    int highestVal;
}
- (void)setPlayer:(PlayerWrapper *)player withInstance:(unsigned int)instance;

@end
NS_ASSUME_NONNULL_END
