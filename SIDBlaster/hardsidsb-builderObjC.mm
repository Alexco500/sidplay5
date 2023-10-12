//
//  hardsidsb-builderObjC.mm
//  SIDBlaster Builder
//
//  Created by Alexander Coers on 08.05.23.
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

#import <Foundation/Foundation.h>

#include <cstring>
#include <string>
#include <memory>
#include <sstream>
#include <algorithm>
#include <new>

#include "hardsidsb.h"
#include "sidcxx11.h"
#include "hardsidsb-emuObjC.h"


bool HardSIDSBBuilder::m_initialised = false;
unsigned int HardSIDSBBuilder::m_count = 0;
bool HardSIDSBBuilder::clockIsPAL = true;

HardSIDSBBuilder::HardSIDSBBuilder(const char * const name) :
    sidbuilder (name)
{
    if (!m_initialised)
    {
        if (init() < 0)
            return;
        m_initialised = true;
    }
}

HardSIDSBBuilder::~HardSIDSBBuilder()
{   // Remove all SID emulations
    remove();
}

// Create a new sid emulation.
unsigned int HardSIDSBBuilder::create(unsigned int sids)
{
    m_status = true;

    // Check available devices
    unsigned int count = availDevices();
    if (count == 0)
    {
        m_errorBuffer = "No SIDBlaster USB device found.";
        goto HardSIDSBBuilder_create_error;
    }

    if (count < sids)
        sids = count;

    for (count = 0; count < sids; count++)
    {
        try
        {
            std::unique_ptr<libsidplayfp::HardSIDSB> sid(new libsidplayfp::HardSIDSB(this));

            // SID init failed?
            if (!sid->getStatus())
            {
                m_errorBuffer = sid->error();
                goto HardSIDSBBuilder_create_error;
            }
            sidobjs.insert(sid.release());
        }
        // Memory alloc failed?
        catch (std::bad_alloc const &)
        {
            m_errorBuffer.assign(name()).append(" ERROR: Unable to create HardSID object");
            goto HardSIDSBBuilder_create_error;
        }


    }
    return count;

HardSIDSBBuilder_create_error:
    m_status = false;
    return count;
}

unsigned int HardSIDSBBuilder::availDevices() const
{
    // Available devices
    m_count = libsidplayfp::HardSIDSB::numberOfDevices();
    return m_count;
}

const char *HardSIDSBBuilder::credits() const
{
    return libsidplayfp::HardSIDSB::getCredits();
}

void HardSIDSBBuilder::flush()
{
    for (emuset_t::iterator it=sidobjs.begin(); it != sidobjs.end(); ++it)
        static_cast<libsidplayfp::HardSIDSB*>(*it)->flush();
}

void HardSIDSBBuilder::filter(bool enable)
{
    std::for_each(sidobjs.begin(), sidobjs.end(), applyParameter<libsidplayfp::HardSIDSB, bool>(&libsidplayfp::HardSIDSB::filter, enable));
}

int HardSIDSBBuilder::init()
{
    m_count = 0;
    libsidplayfp::HardSIDSB(this);
    if (libsidplayfp::HardSIDSB::isLoaded() == true)
    {
        // sidblaster found
        return 0;
    }
    // nothing found
    return -1;
}
#pragma mark AddOns SIDPlayer5

void HardSIDSBBuilder::reset(int volume)
{
    for (emuset_t::iterator it=sidobjs.begin(); it != sidobjs.end(); ++it)
        static_cast<libsidplayfp::HardSIDSB*>(*it)->reset(volume);
}
void HardSIDSBBuilder::setClockToPAL(bool isPAL)
{
    clockIsPAL = isPAL;
    for (emuset_t::iterator it=sidobjs.begin(); it != sidobjs.end(); ++it)
        static_cast<libsidplayfp::HardSIDSB*>(*it)->setToPAL(isPAL);
}
