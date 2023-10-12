//
//  SIDBlaster.h
//  SIDBlaster Builder
//
//  Created by Alexander Coers on 30.06.23.
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
#ifndef SIDBlaster_h
#define SIDBlaster_h

#include <mach/mach_time.h>  //for high resolution time
#import <Foundation/Foundation.h>
#include "ftd2xx.h"

enum SID_TYPE {
    SID_TYPE_NONE = 0, SID_TYPE_6581, SID_TYPE_8580
};
enum SID_CMD_INDEX {
    SID_CMD_TYPE = 0,
    SID_CMD_DELAY = 1,
    SID_CMD_REGISTER = 2,
    SID_CMD_VALUE = 3,
    SID_CMD_NUMBER = 4
};
enum {
    SID_WRITE = 0,
    SID_READ = 1,
    SID_DELAY = 2,
    SID_NOP
};

static const float ONE_MHZ_CYCLES_PER_MICRO = 1.0;  // 1MHz => 1.000.000 times per second = 1 microsecond
static const unsigned int SB_MIN_CYCLE_SID_WRITE = 4;
static const uint64_t NANOS_PER_USEC  = 1000;
static const uint64_t NANOS_PER_MILLISEC  = 1000 * NANOS_PER_USEC;
static const uint64_t NANOS_PER_SEC  = 1000 * NANOS_PER_MILLISEC;
static const uint64_t THRESHOLD_WAIT_IN_NANOS = 1500 * NANOS_PER_USEC; // 1500 us

// FTDI USB settings
static const unsigned int FT_DEVICE_TIMEOUT_MS = 1000;
static const unsigned int FT_BAUD_RATE = 500000;
static const unsigned int FT_LATENCY_MS = 2;
#define FT_WORD_LENGTH    FT_BITS_8
#define FT_STOP_BITS      FT_STOP_BITS_1
#define FT_PARITY         FT_PARITY_NONE




@interface SIDBlaster : NSObject {
    NSMutableArray *usbSendQueue;
    NSMutableArray *usbRecvQueue;
    
    //USB device housekeeping
    FT_HANDLE ft_handle;
    FT_STATUS ft_status;
    FT_DEVICE_LIST_INFO_NODE ft_info;
    
    uint8 deviceID;
    
    // SID register mirror
    uint8_t sidRegisterArray[32];
    unsigned int commandCounter;
    unsigned int oldCounter;
}

- (void)addSIDCommandToQueue:(int)type
                       delay:(long)delayInCycles
                 SIDRegister:(int)reg
                       value:(int)value;
- (uint8_t)lastRcvedByte;
- (void)resetWithVolume:(uint8_t)volume;
- (void)flush;
- (void)writeToSidRegister:(uint8_t)reg value:(uint8_t)value;
- (void)commandQueueRunner:(id)object;
- (void)setDeviceInfo:(FT_DEVICE_LIST_INFO_NODE *)devInfo;
- (void)copySerialNumberInBuffer:(char *)output withLen:(unsigned int)len;
- (int)getSIDType;
- (BOOL)sameAsDeviceWithSerial:(char *)serialToCheck;
- (BOOL)initUSBSettingsForDevice;
@end

#endif /* SIDBlaster_h */
