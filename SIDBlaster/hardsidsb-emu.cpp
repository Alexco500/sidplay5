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
    Event("HardSID Delay"),
    m_handle(0),
    m_instance(sid++)
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

    m_status = true;
    sidemu::reset();
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
    //FIXME: we only handle old reset w/o volume
    //FIXME: we only support 1 USB device
    HardSID_Reset(m_instance);
    m_accessClk = 0;
    if (eventScheduler != nullptr)
        eventScheduler->schedule(*this, HARDSID_DELAY_CYCLES, EVENT_CLOCK_PHI1);
}

event_clock_t HardSIDSB::delay()
{
    event_clock_t cycles = eventScheduler->getTime(EVENT_CLOCK_PHI1) - m_accessClk;
    m_accessClk += cycles;

    while (cycles > 0xffff)
    {
        //FIXME: we only support 1 USB device
        HardSID_Delay(m_instance, 0xffff);
        cycles -= 0xffff;
    }

    return cycles;
}

void HardSIDSB::clock()
{
    const event_clock_t cycles = delay();

    if (cycles)
        //FIXME: we only support 1 USB device
        HardSID_Delay(m_instance, cycles);
}

uint8_t HardSIDSB::read(uint_least8_t addr)
{
    const event_clock_t cycles = delay();

    //FIXME: we only support 1 USB device
    return 0; //HardSID_Read(m_instance, (int)cycles, addr);
}

void HardSIDSB::write(uint_least8_t addr, uint8_t data)
{
    const event_clock_t cycles = delay();
    //FIXME: we only support 1 USB device
    HardSID_Write(m_instance, (int) cycles, addr, data);
}

void HardSIDSB::voice(unsigned int num, bool mute)
{
    // Only have 3 voices!
    if (num >= voices)
        return;
    //FIXME: we only support 1 USB device
    HardSID_Mute(m_instance, num, mute);
}

void HardSIDSB::event()
{
    event_clock_t cycles = eventScheduler->getTime(EVENT_CLOCK_PHI1) - m_accessClk;
    if (cycles < HARDSID_DELAY_CYCLES)
    {
        eventScheduler->schedule(*this, (unsigned int)(HARDSID_DELAY_CYCLES - cycles),
                  EVENT_CLOCK_PHI1);
    }
    else
    {
        m_accessClk += cycles;
        //FIXME: we only support 1 USB device
        HardSID_Delay(m_instance, cycles);
        eventScheduler->schedule(*this, HARDSID_DELAY_CYCLES, EVENT_CLOCK_PHI1);
    }
}

void HardSIDSB::filter(bool enable)
{
    //FIXME: we only support 1 USB device
    HardSID_Filter(m_instance, enable);
}

void HardSIDSB::flush()
{
    //FIXME: we only support 1 USB device
    HardSID_Flush(m_instance);
}

bool HardSIDSB::lock(EventScheduler* env)
{
    //FIXME: we only support 1 USB device
    if (HardSID_Lock(m_instance) == false)
        return false;
    
    sidemu::lock(env);
    eventScheduler->schedule(*this, HARDSID_DELAY_CYCLES, EVENT_CLOCK_PHI1);

    return true;
}

void HardSIDSB::unlock()
{
    //FIXME: we only support 1 USB device
    HardSID_Unlock(m_instance);
    eventScheduler->cancel(*this);
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
}
