//
//  hardsidsb-builderObjC.h
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
#ifndef HARDSIDSB_EMU_H
#define HARDSIDSB_EMU_H

#include "sidemu.h"
#include "Event.h"
#include "EventScheduler.h"
#include "sidplayfp/siddefs.h"

#include "sidcxx11.h"

#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif

//#import <Foundation/Foundation.h>
#include "USBSID.h"

class sidbuilder;

namespace libsidplayfp
{

#define HARDSID_VOICES 3
// Approx 60ms
#define HARDSID_DELAY_CYCLES 60000

const float ONE_MH_CLOCK = 1000000.0;
const float PAL_CLOCK = 17734475.0 / 18.0;
const float NTSC_CLOCK = 14318180.0 / 14.0;

const float PAL_CLOCK_SCALE = (ONE_MH_CLOCK - PAL_CLOCK) / ONE_MH_CLOCK;
const float NTSC_CLOCK_SCALE = (NTSC_CLOCK - ONE_MH_CLOCK) / ONE_MH_CLOCK;

const float MIN_CYCLE_SID_WRITE = 8;
const float MIN_CYCLE_SID_WRITE_FAST_FORWARD = 8;

const float PAL_FREQ_SCALE  = PAL_CLOCK / ONE_MH_CLOCK;
const float NTSC_FREQ_SCALE = NTSC_CLOCK / ONE_MH_CLOCK;

/***************************************************************************
 * HardSID SID Specialisation
 ***************************************************************************/
class USBSID final : public sidemu, private Event
{
private:
    friend class USBSIDBuilder;

    /* USBSID specific data */
    USBSID_NS::USBSID_Class &m_sid;
    int m_handle;
    int sidno;

    bool m_status;

    uint8_t busValue;  /* Return value on read */

    SidConfig::sid_model_t runmodel;  /* Read model type */

    event_clock_t delay();  /* Event */
    
    /* SIDPLAY 5 */
    bool setClockToPAL;
        
    
public:
    static const char* getCredits();
    
public:
public:
    USBSID(sidbuilder *builder);
    ~USBSID() override;

    /* static variables required due to
     * multiple class initializations */
    static long raster_rate;
    static event_clock_t m_delayClk;

    bool getStatus() const { return m_status; }

    uint8_t read(uint_least8_t addr) override;
    void write(uint_least8_t addr, uint8_t data) override;

    /* c64sid functions */
    void reset(uint8_t volume) override;

    /* Standard SID functions */
    void clock() override {};


    void sampling(float systemclock, float freq,
        SidConfig::sampling_method_t method) ;

    void model(SidConfig::sid_model_t model, MAYBE_UNUSED bool digiboost) override;

    /* USBSID specific */
    void flush(void);
    void filter(bool enable);

    /* SIDPLAY 5 */
    uint8_t numberOfSids();
    void setToPAL(bool value);
    /* ISSUE: Disabled, blocks playing */
    // Must lock the SID before using the standard functions.
    //bool lock(EventScheduler *env) override;
    //void unlock() override;

private:
    // Fixed interval timer delay to prevent sidplay2
    // shoot to 100% CPU usage when song no longer
    // writes to SID.
    void event() override;
};

}

#endif // HARDSIDSB_EMU_H
