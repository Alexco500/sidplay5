//
//  SIDBlasterController.h
//  SIDBlaster Tool
//
//  Created by Alexander Coers on 03.07.23.
//

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
