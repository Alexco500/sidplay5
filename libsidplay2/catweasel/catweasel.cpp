/***************************************************************************
		   catweasel.cpp  -  Catweasel MK3 support interface.
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
#include "catweasel.h"
#include "catweasel-emu.h"

const  uint Catweasel::voices = CWMK3_VOICES;
uint   Catweasel::sid = 0;
char   Catweasel::credit[];


Catweasel::Catweasel (sidbuilder *builder)
:sidemu(builder),
 Event("HardSID Delay"),
 m_eventContext(NULL),
 m_phase(EVENT_CLOCK_PHI1),
 m_instance(sid++),
 m_status(false),
 m_locked(false)
{
    *m_errorBuffer = '\0';
    if (m_instance >= 1 )
    {
        sprintf (m_errorBuffer, "Catweasel MK3 does not support multiple SIDs.");
        return;
    }

	int rc = CWMK3_Init();

	if ( rc == 0 ) {
        sprintf (m_errorBuffer, "No Catweasel MK3 found.");
        return;
	}
	
    m_status = true;
    reset ();
    // Unmute all the voices

	CWMK3_MuteAllVoices( false );

    //hsid2.MuteAll (m_instance, false);
}


Catweasel::~Catweasel()
{
    sid--;
}

uint8_t Catweasel::read (uint_least8_t addr)
{
    event_clock_t cycles = m_eventContext->getTime (m_accessClk, m_phase);
    m_accessClk += cycles;

    while (cycles > 0xFFFF)
    {
		CWMK3_Delay( 0xFFFF );
        //hsid2.Delay ((BYTE) m_instance, 0xFFFF);
        cycles -= 0xFFFF;
    }

	CWMK3_Delay( cycles );

	UInt32 value;
	CWMK3_ReadSIDByte( addr, &value, 0 );

    return value;
}

void Catweasel::write (uint_least8_t addr, uint8_t data)
{
    event_clock_t cycles = m_eventContext->getTime (m_accessClk, m_phase);
    m_accessClk += cycles;

    while (cycles > 0xFFFF)
    {
		CWMK3_Delay( 0xFFFF );
        //hsid2.Delay ((BYTE) m_instance, 0xFFFF);
        cycles -= 0xFFFF;
    }

	CWMK3_Delay( cycles );

	CWMK3_WriteSIDByte( addr, data );
}


void Catweasel::reset (uint8_t volume)
{   // Ok if no fifo, otherwise need hardware
    // reset to clear out fifo.
    
    m_accessClk = 0;

	CWMK3_ResetSID( volume );
	
    if (m_eventContext != NULL)
		schedule(*m_eventContext, CWMK3_DELAY_CYCLES, m_phase); 
}

void Catweasel::volume (uint_least8_t num, uint_least8_t volume)
{
    // Not yet supported
}

void Catweasel::mute (uint_least8_t num, bool mute)
{
    if (num >= voices)
        return;

	CWMK3_MuteVoice( num, mute );
    //hsid2.Mute ((BYTE) m_instance, (BYTE) num, (BOOL) mute);
}

// Set execution environment and lock sid to it
bool Catweasel::lock (c64env *env)
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
        schedule(*m_eventContext, CWMK3_DELAY_CYCLES, m_phase);
    }
    return true;
}


void Catweasel::event (void)
{
    event_clock_t cycles = m_eventContext->getTime (m_accessClk, m_phase);
    m_accessClk += cycles;
    if (cycles) {

		CWMK3_Delay( cycles );
        //hsid2.Delay ((BYTE) m_instance, (WORD) cycles);
	}

	schedule(*m_eventContext, CWMK3_DELAY_CYCLES, m_phase);
}

// Disable/Enable SID filter
void Catweasel::filter (bool enable)
{
	CWMK3_EnableFilter( enable );
    //hsid2.Filter ((BYTE) m_instance, (BOOL) enable);
}

void Catweasel::flush(void)
{
    //hsid2.Flush ((BYTE) m_instance);
}
