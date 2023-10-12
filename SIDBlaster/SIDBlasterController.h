//
//  SIDBlasterController.h
//  SIDBlaster Builder
//
//  Created by Alexander Coers on 03.07.23.
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
#ifndef SIDBlasterController_h
#define SIDBlasterController_h

#import "SIDBlaster.h"
#include "ftd2xx.h"

static const unsigned int maxNumberOfSIDs = 4;

@interface SIDBlasterController : NSObject {
    NSMutableArray *mySIDDevices;
}
- (BOOL)scanForDevices;
- (int)numberOfDevices;
- (int)writeValue: (unsigned int)val ToRegister: (unsigned int)reg toSID:(unsigned int)number withDelay:(unsigned int)delay;
- (int)readOfRegister: (unsigned int)reg fromSID:(unsigned int)number withDelay:(unsigned int)delay;
- (void)copySerialNumberInBuffer:(char *)outputBuffer withLength:(unsigned int)len ofSID:(unsigned int)number;
- (int)getSIDTypeOfSID:(unsigned int)number;

// functions for sidplayfp library support
- (const char*) getCredits;
@end

#endif /* SIDBlasterController_h */
