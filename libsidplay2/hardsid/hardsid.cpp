/***************************************************************************
		   hardsid.cpp  -  HardSID PCI support interface.
                             --------------------------------
    begin                : Fri Jan 31 2000
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

#include <stdio.h>
#include <unistd.h>
#include "config.h"
#include "hardsid.h"
#include "hardsid-emu.h"

const  uint HardSID::voices = HSID_VOICES;
uint   HardSID::sid = 0;
char   HardSID::credit[];


HardSID::HardSID (sidbuilder *builder)
:sidemu(builder),
 Event("HSID Delay"),
 m_eventContext(NULL),
 m_phase(EVENT_CLOCK_PHI1),
 m_instance(sid++),
 m_status(false),
 m_locked(false)
{
    *m_errorBuffer = '\0';
    if (m_instance >= 1 )
    {
        sprintf (m_errorBuffer, "No multi-SID support yet");
        return;
    }

	int rc = HSID_Init();

	if ( rc == 0 ) {
        sprintf (m_errorBuffer, "No HardSID PCI SoundCard found.");
        return;
	}
	
    m_status = true;
    reset ();
    // Unmute all the voices

	HSID_MuteAllVoices( false );

    //hsid2.MuteAll (m_instance, false);
}


HardSID::~HardSID()
{
    sid--;
}

uint8_t HardSID::read (uint_least8_t addr)
{
    event_clock_t cycles = m_eventContext->getTime (m_accessClk, m_phase);
    m_accessClk += cycles;

    UInt32 value;
    HSID_ReadSIDByte( addr, &value, 1 );

    return value;
}

void HardSID::write (uint_least8_t addr, uint8_t data)
{
    event_clock_t cycles = m_eventContext->getTime (m_accessClk, m_phase);
    m_accessClk += cycles;
    //HSID_WriteSIDByteEx(cycles, addr, data);
	
	// AV - hackish hardsid volume control
	if ( addr == 0x18 ) {

		int orig_volume = data & 0x0f;
		int filter_settings = data & 0xf0;
		extern int hsid_volume;	
			
		data = ( ( ( orig_volume * hsid_volume ) / 0x0f ) & 0x0f ) | filter_settings;
	}

	if ( addr == 0x17 ) {
	
		extern int hsid_enable_filter;

		if ( hsid_enable_filter == 0 ) {
			data = data & 0xf8;
		}
	}
	
    HSID_WriteSIDByteEx(m_accessClk, addr, data);
}

void HardSID::reset (uint8_t volume)
{   // Ok if no fifo, otherwise need hardware
    // reset to clear out fifo.
    
    m_accessClk = 0;

    HSID_ResetSID( volume );
	
    if (m_eventContext != NULL)
		schedule(*m_eventContext, HSID_DELAY_CYCLES, m_phase); 
}

void HardSID::volume (uint_least8_t num, uint_least8_t volume)
{
    // Not yet supported
}

void HardSID::mute (uint_least8_t num, bool mute)
{
    if (num >= voices)
        return;

	HSID_MuteVoice( num, mute );
    //hsid2.Mute ((BYTE) m_instance, (BYTE) num, (BOOL) mute);
}

// Set execution environment and lock sid to it
bool HardSID::lock (c64env *env)
{
    if (env == NULL)
    {
        if (!m_locked)
            return false;
		/*
        if (hsid2.Version >= HSID_VERSION_204)
            hsid2.Unlock (m_instance);
		*/
        m_locked = false;
        cancel();
        m_eventContext = NULL;
    }
    else
    {
        if (m_locked)
            return false;
		/*
        if (hsid2.Version >= HSID_VERSION_204)
        {
            if (hsid2.Lock (m_instance) == FALSE)
                return false;
        }
		*/
        m_locked = true;
        m_eventContext = &env->context ();
		schedule(*m_eventContext, HSID_DELAY_CYCLES, m_phase); 
    }
    return true;
}

void HardSID::event (void)
{
    event_clock_t cycles = m_eventContext->getTime (m_accessClk, m_phase);
    m_accessClk += cycles;
    //HSID_Sync(cycles);
    HSID_Sync(m_accessClk);
}

// Disable/Enable SID filter
void HardSID::filter (bool enable)
{
    HSID_EnableFilter( enable );
    //hsid2.Filter ((BYTE) m_instance, (BOOL) enable);
}

void HardSID::flush(void)
{
    //hsid2.Flush ((BYTE) m_instance);
}
