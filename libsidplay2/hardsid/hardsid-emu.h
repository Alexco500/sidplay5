/***************************************************************************
           hardsid-emu.h - HardSID PCI support interface.
                             --------------------------------
    begin                : Fri Jan 31 2003
    copyright            : (C) 2003 by Andreas Varga
    email                : sid@galway.c64.org
 ***************************************************************************/
/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

#ifndef _hardsid_emu_h_
#define _hardsid_emu_h_

#include <sidbuilder.h>
#include <event.h>
#include "config.h"

#include <IOKit/IOKitLib.h>
#include "HardSIDClient.h"


#define HSID_VOICES 3
// Approx 60ms
#define HSID_DELAY_CYCLES 60000

/***************************************************************************
 * HardSID SID Specialisation
 ***************************************************************************/
class HardSID: public sidemu, private Event
{
private:
    friend class HSIDBuilder;

    // HardSID specific data

    static const   uint voices;
    static         uint sid;
    static char    credit[100];

    // Generic variables
    EventContext  *m_eventContext;
    event_phase_t  m_phase;
    event_clock_t  m_accessClk;
    char           m_errorBuffer[100];

    // Must stay in this order
    bool           muted[HSID_VOICES];
    uint           m_instance;
    bool           m_status;
    bool           m_locked;

public:
    HardSID  (sidbuilder *builder);
    ~HardSID ();

    // Standard component functions
    const char   *credits (void) {return credit;}
    void          reset   () { sidemu::reset (); }
    void          reset   (uint8_t volume);
    uint8_t       read    (uint_least8_t addr);
    void          write   (uint_least8_t addr, uint8_t data);
    const char   *error   (void) {return m_errorBuffer;}
    operator bool () const { return m_status; }

    // Standard SID functions
    int_least32_t output  (uint_least8_t bits);
    void          filter  (bool enable);
    void          model   (sid2_model_t model) {;}
    void          volume  (uint_least8_t num, uint_least8_t level);
    void          mute    (uint_least8_t num, bool enable);
    void          gain    (int_least8_t) {;}

    void          flush   (void);

    // Must lock the SID before using the standard functions.
    bool          lock    (c64env *env);

private:
    // Fixed interval timer delay to prevent sidplay2
    // shoot to 100% CPU usage when song nolonger
    // writes to SID.
    void event (void);
};

inline int_least32_t HardSID::output (uint_least8_t bits)
{   // Not supported, should return samples off card...???
    return 0;
}

#endif // _hardsid_emu_h_
