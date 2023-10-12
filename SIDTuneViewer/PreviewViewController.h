//
//  PreviewViewController.h
//  SIDTuneViewer
//
//  Created by Alexander Coers on 29.09.23.
//
/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */
#ifndef PREVIEW_VIEW_CONTROLLER_H
#define PREVIEW_VIEW_CONTROLLER_H
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
#endif
