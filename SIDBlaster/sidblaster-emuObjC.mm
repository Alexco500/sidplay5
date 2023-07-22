/*
 * This file is part of libsidplayfp, a SID player engine.
 *
 * Copyright 2011-2015 Leandro Nini <drfiemost@users.sourceforge.net>
 * Copyright 2007-2010 Antti Lankila
 * Copyright 2001-2001 by Jarno Paananen
 *
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

#include "hardsidsb-emuObjc.h"

#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <cstdio>
#include <cmath>
#include <sstream>
#include <string>

#import <Foundation/Foundation.h>

#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif

namespace libsidplayfp
{

bool HardSIDSB::m_sidFree[16] = {0};
const unsigned int HardSIDSB::voices = HARDSID_VOICES;
unsigned int HardSIDSB::sid = 0;
bool HardSIDSB::m_HardSIDEmuInitialized = false;
NSMutableArray *HardSIDSB::mySIDDevices = nil;

const char* HardSIDSB::getCredits()
{
    static std::string credits;

    if (credits.empty())
    {
        // Setup credits
        std::ostringstream ss;
        ss << "SIDBlaster USB Emu for sidplayerfp " << VERSION << " Engine:\n";
        ss << "\t(C) 2023 Alexander Coers\n";
        ss << "\tbased on HardSID builder by\n";
        ss << "\t(C) 2001-2002 Jarno Paanenen\n\and indispensable help of Winfred Bos\n";
        credits = ss.str();
    }

    return credits.c_str();
}

HardSIDSB::HardSIDSB (sidbuilder *builder) :
    sidemu(builder),
    m_instance(sid++),
    // adjust cycles code
    total_cycles_to_stretch(0),
    setClockToPAL(true)

{
    unsigned int num = 16;
    // init library component
    if (m_HardSIDEmuInitialized == false)
    {
        // init all those USB and FTDI things
        //HardSID_Initialize();
        m_HardSIDEmuInitialized = true;
    }
    for (unsigned int i = 0; i < 16; i++)
    {
        if (m_sidFree[i] == false)
        {
            m_sidFree[i] = true;
            num = i;
            break;
        }
    }

    // All sids in use?!?
    // FIXME: we only support 1 devices
    if (num == 1)
        return;

    m_instance = num;
    // clear all sid writes
    for (int i=0; i<32; i++) {
        sidRegs[i]=0;
    }
    m_status = true;
    sidemu::reset();
    mySIDBlaster = [mySIDDevices objectAtIndex:m_instance];
    reset(0x0f);
    m_accessClk_old = 0;
}

HardSIDSB::~HardSIDSB()
{
    sid--;
    m_sidFree[m_instance] = false;
    mySIDBlaster = nil;
}

void HardSIDSB::reset(uint8_t volume)
{
    for (unsigned int i= 0; i < voices; i++)
        muted[i] = false;
    //HardSID_Reset(m_instance);
    //HardSID_Write(m_instance, 0, 0x18, 0x0f); // set max volume
    [mySIDBlaster resetWithVolume:volume];
    m_accessClk = 0;
}

event_clock_t HardSIDSB::delay()
{
    event_clock_t sidCycles = eventScheduler->getTime(EVENT_CLOCK_PHI1) - m_accessClk;
    sidCycles = adjustTiming(sidCycles);
    m_accessClk += sidCycles;
   // NSLog(@"::delay() cycles %lld, accessClk %llu", sidCycles, m_accessClk);
    return sidCycles;
}
void HardSIDSB::clock()
{
    /* const event_clock_t cycles = delay();

    if (cycles)
        [mySIDBlaster addSIDCommandToQueue:SID_DELAY delay:cycles SIDRegister:0 value:0];
     */
}

uint8_t HardSIDSB::read(uint_least8_t addr)
{
    uint8_t data = 0;
    // catch illegal reads
    if (addr > 0x1c)
        return data;
    const event_clock_t cycles = delay();

    // ask hardware for value
    [mySIDBlaster addSIDCommandToQueue:SID_READ delay:cycles SIDRegister:addr value:0];
    data =  [mySIDBlaster lastRcvedByte];
    m_accessClk_old = m_accessClk;
    //NSLog(@"::read(): address %d, value %d  => delay %lld, accessClk %lld", addr, data, cycles, m_accessClk);
    return data;
}

void HardSIDSB::write(uint_least8_t addr, uint8_t data)
{
    uint8_t low, high, oldHigh;

    const event_clock_t cycles = delay();
    sidRegs[addr] = data;
    
    if (addr == 0x04 || addr == 0x0b || addr == 0x12) {
        // check if gate is set
        if (data & (1 << 0)) {
            switch (addr) {
                    //do frequency adaption, since SIDBlaster runs @1MHz
                case 0x04:
                    high = sidRegs[0x01];
                    low  = sidRegs[0x00];
                    oldHigh = high;
                    adjustFrequency(&high, &low);
                    if (oldHigh != high)
                        [mySIDBlaster addSIDCommandToQueue:SID_WRITE delay:0 SIDRegister:0x01 value:high];
                    [mySIDBlaster addSIDCommandToQueue:SID_WRITE delay:cycles SIDRegister:0x00 value:low];
                    break;
                case 0x0b:
                    high = sidRegs[0x08];
                    low  = sidRegs[0x07];
                    oldHigh = high;
                    adjustFrequency(&high, &low);
                    if (oldHigh != high)
                        [mySIDBlaster addSIDCommandToQueue:SID_WRITE delay:0 SIDRegister:0x08 value:high];
                    [mySIDBlaster addSIDCommandToQueue:SID_WRITE delay:cycles SIDRegister:0x07 value:low];
                    break;
                case 0x12:
                    high = sidRegs[0x0f];
                    low  = sidRegs[0x0e];
                    oldHigh = high;
                    adjustFrequency(&high, &low);
                    if (oldHigh != high)
                        [mySIDBlaster addSIDCommandToQueue:SID_WRITE delay:0 SIDRegister:0x0f value:high];
                    [mySIDBlaster addSIDCommandToQueue:SID_WRITE delay:cycles SIDRegister:0x0e value:low];
                    break;
                default:
                    break;
            }
        }
    }
     [mySIDBlaster addSIDCommandToQueue:SID_WRITE delay:cycles SIDRegister:addr value:data];

    //NSLog(@"::write(): address %d, value %d  => delay %lld, accessClk %lld", addr, data, cycles, m_accessClk);
}

void HardSIDSB::voice(unsigned int num, bool mute)
{
    // Only have 3 voices!
    if (num >= voices)
        return;
    //FIXME: Mute is missing
    //HardSID_Mute(m_instance, num, mute);
}

void HardSIDSB::filter(bool enable)
{
    //FIXME: Filter is missing
    //HardSID_Filter(m_instance, enable);
}

void HardSIDSB::flush()
{
    [mySIDBlaster flush];
    //HardSID_Flush(m_instance);
}

bool HardSIDSB::lock(EventScheduler* env)
{
    //if (HardSID_Lock(m_instance) == false)
      //  return false;
    //FIXME: Lock is missing
    sidemu::lock(env);
    return true;
}

void HardSIDSB::unlock()
{
    //HardSID_Unlock(m_instance);
    //FIXME: Unlock is missing
    sidemu::unlock();
}
const bool HardSIDSB::isLoaded()
{
    // check if SIDblaster USB support is loaded and initialized
    return m_HardSIDEmuInitialized;
}
const unsigned int HardSIDSB::numberOfDevices()
{
    // how many USB devices are available?
    FT_STATUS ftStatus;
    FT_DEVICE_LIST_INFO_NODE *devInfo;
    DWORD numDevs;
    unsigned int numberOfSB = 0;
    
    if (mySIDDevices == nil)
        mySIDDevices = [[NSMutableArray alloc] init];
    
    // create the device information list
    ftStatus = FT_CreateDeviceInfoList(&numDevs);
    if (numDevs > 0) {
        // allocate storage for list based on numDevs
        devInfo = (FT_DEVICE_LIST_INFO_NODE*)malloc(sizeof(FT_DEVICE_LIST_INFO_NODE)*numDevs);
        // get the device information list
        ftStatus = FT_GetDeviceInfoList(devInfo,&numDevs);
        if (ftStatus == FT_OK) {
            
            for (int i = 0; i < numDevs; i++, devInfo++) {
                //Check if the FTDI is a real Sidblaster
                if (strncmp(devInfo->Description, "SIDBlaster/USB", 14) == 0) {
                    numberOfSB++;
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
    }
    return numberOfSB;
}
void HardSIDSB::setToPAL(bool value)
{
    setClockToPAL = value;
}
void HardSIDSB::adjustFrequency(uint8_t *high, uint8_t *low)
{
    /* this frequency adjustment is needed since the SIDBlaster works
     * at 1MHz, so it is either too fast (PAL) or too slow (NTSC)
     * taken from ACID64 code by Winfred Bos
     */
    
    float freq = (*high<<8) + *low;
    if (setClockToPAL) {
        freq = freq * PAL_FREQ_SCALE;
    } else {
        freq = freq * NTSC_FREQ_SCALE;
    }
    *high = (uint8_t)((int)freq>>8);
    *low  = (uint8_t)((int)freq & 0x0ff);
    
}

event_clock_t HardSIDSB::adjustTiming(event_clock_t oldCycles)
{
    /* this timing adjustment is needed since the SIDBlaster works
     * at 1MHz, so it is either too fast (PAL) or too slow (NTSC)
     * taken from ACID64 code by Winfred Bos
     */
    float calcCycles = (float)oldCycles;
    
    if (setClockToPAL) {
          total_cycles_to_stretch += calcCycles * PAL_CLOCK_SCALE;

          if (total_cycles_to_stretch >= 1.0) {
              float stretch_rounded = std::trunc(total_cycles_to_stretch);
              total_cycles_to_stretch -= stretch_rounded;
              calcCycles += stretch_rounded;
          }
      } else {
          total_cycles_to_stretch += calcCycles * NTSC_CLOCK_SCALE;

          if (total_cycles_to_stretch >= 1.0) {
              if (calcCycles > total_cycles_to_stretch) {
                  float stretch_rounded = std::trunc(total_cycles_to_stretch);
                  total_cycles_to_stretch -= stretch_rounded;
                  calcCycles -= stretch_rounded;
              } else {
                  total_cycles_to_stretch -= calcCycles;
                  calcCycles = 0.0;
              }
          }
      }
    
    if (calcCycles < MIN_CYCLE_SID_WRITE) {
        if (setClockToPAL) {
            total_cycles_to_stretch -= MIN_CYCLE_SID_WRITE - calcCycles;
        } else {
            total_cycles_to_stretch += MIN_CYCLE_SID_WRITE - calcCycles;
        }
        return MIN_CYCLE_SID_WRITE;
    }
    
    return (event_clock_t)calcCycles;
}
}
