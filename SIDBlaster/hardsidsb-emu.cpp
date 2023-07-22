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

#include "hardsidsb-emu.h"

//hardsid emulation for sidblasterUSB
#include "hardsid_sb.hpp"

#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <cstdio>
#include <cmath>
#include <sstream>
#include <string>

#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif

namespace libsidplayfp
{

bool HardSIDSB::m_sidFree[16] = {0};
const unsigned int HardSIDSB::voices = HARDSID_VOICES;
unsigned int HardSIDSB::sid = 0;
bool HardSIDSB::m_HardSIDEmuInitialized = false;

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
        ss << "\t(C) 2001-2002 Jarno Paanenen\n";
        credits = ss.str();
    }

    return credits.c_str();
}

HardSIDSB::HardSIDSB (sidbuilder *builder) :
    sidemu(builder),
    m_handle(0),
    m_instance(sid++),
    // adjust cycles code
    total_cycles_to_stretch(0),
    cycles(0),
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
    // FIXME: we only support one device
    if (num == 1)
        return;

    m_instance = num;
    // clear all sid writes
    for (int i=0; i<32; i++) {
        sidRegs[i]=0;
    }
    m_status = true;
    sidemu::reset();
    HardSID_SetWriteBufferSize(8);
}

HardSIDSB::~HardSIDSB()
{
    sid--;
    m_sidFree[m_instance] = false;
}

void HardSIDSB::reset(uint8_t volume)
{
    for (unsigned int i= 0; i < voices; i++)
        muted[i] = false;
    HardSID_Reset(m_instance);
    HardSID_Write(m_instance, 0, 0x18, 0x0f); // set max volume
    m_accessClk = 0;
    cycles = 0;
}


void HardSIDSB::clock()
{
    cycles = eventScheduler->getTime(EVENT_CLOCK_PHI1) - m_accessClk;
    cycles = adjustTiming(cycles);
    m_accessClk += (cycles);

    //printf("HardSIDSB::clock(): cycles %d  => accessClk %lld\n", cycles, m_accessClk);

    if (cycles-MIN_CYCLE_SID_WRITE >= 0)
        HardSID_Delay(m_instance, cycles-MIN_CYCLE_SID_WRITE);
}

uint8_t HardSIDSB::read(uint_least8_t addr)
{
    clock();
    // catch illegal reads
    if (addr > 0x1c)
        return 0;
    // catch read registers and do a SID read
    if (addr >= 0x19)
        return HardSID_Read(m_instance, cycles, addr);
    // else simply return stored value from memory
    return sidRegs[addr];

}

void HardSIDSB::write(uint_least8_t addr, uint8_t data)
{
    uint8_t low, high, oldHigh;
    clock();
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
                        HardSID_Write(m_instance, (int) 0, 0x01, high);
                    HardSID_Write(m_instance, (int) cycles, 0x00, low);
                    break;
                case 0x0b:
                    high = sidRegs[0x08];
                    low  = sidRegs[0x07];
                    oldHigh = high;
                    adjustFrequency(&high, &low);
                    if (oldHigh != high)
                        HardSID_Write(m_instance, (int) 0, 0x08, high);
                    HardSID_Write(m_instance, (int) cycles, 0x07, low);
                    break;
                case 0x12:
                    high = sidRegs[0x0f];
                    low  = sidRegs[0x0e];
                    oldHigh = high;
                    adjustFrequency(&high, &low);
                    if (oldHigh != high)
                        HardSID_Write(m_instance, (int) 0, 0x0f, high);
                    HardSID_Write(m_instance, (int) cycles, 0x0e, low);
                    break;
                default:
                    break;
            }
        }
    }
    HardSID_Write(m_instance, (int) cycles, addr, data);
    //printf("HardSIDSB::write(): address %d, value %d  => accessClk %lld\n", addr, data, m_accessClk);
}

void HardSIDSB::voice(unsigned int num, bool mute)
{
    // Only have 3 voices!
    if (num >= voices)
        return;
    HardSID_Mute(m_instance, num, mute);
}

void HardSIDSB::filter(bool enable)
{
    HardSID_Filter(m_instance, enable);
}

void HardSIDSB::flush()
{
    HardSID_Flush(m_instance);
}

bool HardSIDSB::lock(EventScheduler* env)
{
    if (HardSID_Lock(m_instance) == false)
        return false;
    
    sidemu::lock(env);
    return true;
}

void HardSIDSB::unlock()
{
    HardSID_Unlock(m_instance);
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
    
    return (const unsigned int)GetHardSIDCount();
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
