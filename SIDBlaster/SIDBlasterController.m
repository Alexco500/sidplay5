//
//  SIDBlasterController.m
//  SIDBlaster Tool
//
//  Created by Alexander Coers on 03.07.23.
//

#import <Foundation/Foundation.h>

#import "SIDBlasterController.h"

@implementation SIDBlasterController
- (id)init
{
    self = [super init];
    mySIDDevices = [[NSMutableArray alloc] init];
    
    return self;

}
- (BOOL)scanForDevices
{
    FT_STATUS ftStatus;
    FT_DEVICE_LIST_INFO_NODE *devInfo;
    DWORD numDevs;
    BOOL foundValidDevices = NO;
    
    // create the device information list
    ftStatus = FT_CreateDeviceInfoList(&numDevs);
    if (numDevs > 0) {
        // allocate storage for list based on numDevs
        devInfo = (FT_DEVICE_LIST_INFO_NODE*)malloc(sizeof(FT_DEVICE_LIST_INFO_NODE)*numDevs);
        // get the device information list
        ftStatus = FT_GetDeviceInfoList(devInfo,&numDevs);
        if (ftStatus == FT_OK)
            foundValidDevices = YES;
        
        for (int i = 0; i < numDevs; i++, devInfo++) {
            //Check if the FTDI is a real Sidblaster
            if (strncmp(devInfo->Description, "SIDBlaster/USB", 14) == 0) {
                NSEnumerator *enumerator = [mySIDDevices objectEnumerator];
                SIDBlaster *anObject;
                BOOL newSIDBlaster = NO;
                while (anObject = [enumerator nextObject]) {
                    // no duplicates, please...
                    newSIDBlaster = [anObject sameAsDeviceWithSerial:devInfo->SerialNumber];
                }
                if (!newSIDBlaster) {
                    SIDBlaster *newDevice = [[SIDBlaster alloc] init];
                    [newDevice setDeviceInfo:devInfo];
                    if ([newDevice initUSBSettingsForDevice]) {
                        [mySIDDevices addObject:newDevice];
                        // start thread loop
                        [NSThread detachNewThreadSelector:@selector(commandQueueRunner:) toTarget:newDevice withObject:nil];
                        
                    }
                }
            }
        }

    }
    return foundValidDevices;
}
- (int)numberOfDevices
{
    return (int)[mySIDDevices count];
}
- (int)readOfRegister: (unsigned int)reg fromSID:(unsigned int)number withDelay:(unsigned int)delay
{
    if (number > [mySIDDevices count])
        return 0;
    SIDBlaster *myDevice = [mySIDDevices objectAtIndex:number];
    [myDevice addSIDCommandToQueue:SID_READ delay:delay SIDRegister:reg value:0];
    return [myDevice lastRcvedByte];
}
- (int)writeValue: (unsigned int)val ToRegister: (unsigned int)reg toSID:(unsigned int)number withDelay:(unsigned int)delay
{
    if (number > [mySIDDevices count])
        return 0;
    SIDBlaster *myDevice = [mySIDDevices objectAtIndex:number];
    [myDevice addSIDCommandToQueue:SID_WRITE delay:delay SIDRegister:reg value:val];
    return 0;
}
- (void)copySerialNumberInBuffer:(char *)outputBuffer withLength:(unsigned int)len ofSID:(unsigned int)number
{
    if (number > [mySIDDevices count])
        return;
    SIDBlaster *myDevice = [mySIDDevices objectAtIndex:number];
    [myDevice copySerialNumberInBuffer:outputBuffer withLen:len];
}
- (int)getSIDTypeOfSID:(unsigned int)number
{
    int type;
    if (number > [mySIDDevices count])
        return SID_TYPE_NONE;
    SIDBlaster *myDevice = [mySIDDevices objectAtIndex:number];
    type = [myDevice getSIDType];
    return type;
}

#pragma mark sidplayfp library functions
- (const char*)getCredits
{
    const char* credits = "SIDBlaster USB Emu for sidplayerfp \n\t(C) 2023 Alexander Coers\n\tbased on HardSID builder by\t(C) 2001-2002 Jarno Paanenen\and indispensable help of Winfred Bos\n";
    return credits;
}
@end
