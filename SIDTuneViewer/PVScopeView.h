//
//  PVScopeView.h
//  SIDTuneViewer
//
//  Created by Alexander Coers on 02.10.23.
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
#ifndef PVSCOPE_VIEW_H
#define PVSCOPE_VIEW_H
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
#endif
