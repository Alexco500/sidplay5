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

#include "usbsid_builder.h"
#include "usbSid-emuObjC.h"
#include "sidcxx11.h"

bool USBSIDBuilder::m_initialised = false;
unsigned int USBSIDBuilder::m_count = 0;
bool USBSIDBuilder::clockIsPAL = true;


USBSIDBuilder::USBSIDBuilder(const char * const name) :
    sidbuilder(name)
{}

USBSIDBuilder::~USBSIDBuilder()
{
    /* Remove all SID objects */
    reset(0x0f);
    flush();
    remove();
}
// Create a new sid emulation.
unsigned int USBSIDBuilder::create(unsigned int sids)
{
    m_status = true;

    // Check available devices
    unsigned int count = availDevices();

    if (count && (count < sids))
        sids = count;

    for (count = 0; count < sids; count++)
    {
        try
        {
            std::unique_ptr<libsidplayfp::USBSID> sid(new libsidplayfp::USBSID(this));

            // SID init failed?
            if (!sid->getStatus())
            {
                m_errorBuffer = sid->error();
                m_status = false;
                return count;
            }
            sids = sid->numberOfSids();  // query number of configured sids
            sidobjs.insert(sid.release());
        }
        // Memory alloc failed?
        catch (std::bad_alloc const &)
        {
            m_errorBuffer.assign(name()).append(" ERROR: Unable to create USBSID object");
            m_status = false;
            break;
        }
    }
    return count;

}


const char *USBSIDBuilder::credits() const
{
    return libsidplayfp::USBSID::getCredits();
}

void USBSIDBuilder::flush()
{
    for (libsidplayfp::sidemu* e: sidobjs)
        static_cast<libsidplayfp::USBSID*>(e)->flush();
}

void USBSIDBuilder::filter (bool enable)
{
    for (libsidplayfp::sidemu* e: sidobjs)
        static_cast<libsidplayfp::USBSID*>(e)->filter(enable);
}
unsigned int USBSIDBuilder::availDevices() const
{
    // Available devices
    m_count = (unsigned int)sidobjs.size();
    return m_count;
}

#pragma mark AddOns SIDPlayer5

void USBSIDBuilder::reset(int volume)
{
    for (libsidplayfp::sidemu* e: sidobjs)
        static_cast<libsidplayfp::USBSID*>(e)->reset(volume&0x0f);
}
void USBSIDBuilder::setClockToPAL(bool isPAL)
{
    clockIsPAL = isPAL;
    for (libsidplayfp::sidemu* e: sidobjs)
        static_cast<libsidplayfp::USBSID*>(e)->setToPAL(isPAL);
}
