/***************************************************************************
         hardsid-builder.cpp - HardSID PCI builder class
                                 -------------------
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

#include <stdio.h>
#include "config.h"

#ifdef HAVE_EXCEPTIONS
#   include <new>
#endif

#include "hardsid.h"
#include "hardsid-emu.h"


uint HSIDBuilder::m_instance = 0;

HSIDBuilder::HSIDBuilder (const char * const name)
:sidbuilder (name)
{
    strcpy (m_errorBuffer, "N/A");

    if (m_instance == 0)
    {   // Setup credits

        char *p = HardSID::credit;
        sprintf (p, "HardSID PCI SoundCard Engine:");
        p += strlen (p) + 1;
        strcpy  (p, "\t(C) 2003 Andreas Varga <sid@galway.c64.org>");
        p += strlen (p) + 1;
        *p = '\0';
    }
    m_instance++;
}

HSIDBuilder::~HSIDBuilder (void)
{   // Remove all are SID emulations
    remove ();
    m_instance--;
}

// Create a new sid emulation.  Called by libsidplay2 only
uint HSIDBuilder::create (uint sids)
{
    uint   count;
    HardSID *sid = NULL;
    m_status     = true;

    // Check available devices
    count = devices (false);
    if (!m_status)
        goto HSIDBuilder_create_error;
    if (count && (count < sids))
        sids = count;

    for (count = 0; count < sids; count++)
    {
#   ifdef HAVE_EXCEPTIONS
        sid = new(std::nothrow) HardSID(this);
#   else
        sid = new HardSID(this);
#   endif

        // Memory alloc failed?
        if (!sid)
        {
            sprintf (m_errorBuffer, "%s ERROR: Unable to create HardSID object", name ());
            goto HSIDBuilder_create_error;
        }

        // SID init failed?
        if (!*sid)
        {
            strcpy (m_errorBuffer, sid->error ());
            goto HSIDBuilder_create_error;
        }
        sidobjs.push_back (sid);
    }
    return count;

HSIDBuilder_create_error:
    m_status = false;
    if (sid)
        delete sid;
    return count;
}

uint HSIDBuilder::devices (bool created)
{
    m_status = true;
    if (created)
        return sidobjs.size ();

    return 1;
}

const char *HSIDBuilder::credits ()
{
    m_status = true;
    return HardSID::credit;
}

void HSIDBuilder::flush(void)
{
    int size = sidobjs.size ();
    for (int i = 0; i < size; i++)
        ((HardSID*)sidobjs[i])->flush();
}

void HSIDBuilder::filter (bool enable)
{
    int size = sidobjs.size ();
    m_status = true;
    for (int i = 0; i < size; i++)
    {
        HardSID *sid = (HardSID *) sidobjs[i];
        sid->filter (enable);
    }
}

// Find a free SID of the required specs
sidemu *HSIDBuilder::lock (c64env *env, sid2_model_t model)
{
    int size = sidobjs.size ();
    m_status = true;

    for (int i = 0; i < size; i++)
    {
        HardSID *sid = (HardSID *) sidobjs[i];
        if (sid->lock (env))
		{
            sid->model (model);
            return sid;
		}
    }
    // Unable to locate free SID
    m_status = false;
    sprintf (m_errorBuffer, "%s ERROR: No available SIDs to lock", name ());
    return NULL;
}

// Allow something to use this SID
void HSIDBuilder::unlock (sidemu *device)
{
    int size = sidobjs.size ();
    // Make sure this is our SID
    for (int i = 0; i < size; i++)
    {
        HardSID *sid = (HardSID *) sidobjs[i];
        if (sid == device)
		{   // Unlock it
            sid->lock (NULL);
			break;
		}
    }
}

// Remove all SID emulations.
void HSIDBuilder::remove ()
{
    int size = sidobjs.size ();
    for (int i = 0; i < size; i++)
        delete sidobjs[i];
    sidobjs.clear();
}

