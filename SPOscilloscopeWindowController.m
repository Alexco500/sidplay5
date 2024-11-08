//
//  SPOscilloscopeWindow.m
//  SIDPLAY
//
//  Created by Alexander Coers on 12.04.24.
//

#import "SPOscilloscopeWindowController.h"
#import "SPBigOscilloscopeView.h"

extern NSString* SPTuneChangedNotification;

@class SPPlayerWindow;

@implementation SPOscilloscopeWindowController

@synthesize playerWindow;
- (id)init
{
    self = [super init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTuneInfo:) name:SPTuneChangedNotification object:nil];    
    return self;
}
- (void)updateTuneInfo:(NSNotification *)aNotification;
{
    // tune has changed
    if ([[self window] isVisible])
    {
        if (scopeView)
            [scopeView updatePlayerInfo];
    }
}

- (void)toggleWindow:(id)sender
{
    if ([[self window] isVisible] == YES)
    {
        [[self window] setIsVisible:NO];
    }
    else {
        scopeView = [[self window] contentView];
        [scopeView setPlayerWindow:playerWindow];
        [[self window] setIsVisible:YES];
    }
}
- (void)updateScope
{
    // needs to be called via timer to update scope regulary
    if ([[self window] isVisible])
    {
        if (scopeView)
        {
            [scopeView updatePlayerInfo];
             [scopeView setNeedsDisplay:YES];
        }
    }
}
@end
