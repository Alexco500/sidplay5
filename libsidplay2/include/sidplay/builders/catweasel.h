/***************************************************************************
               catweasel.h  -  Catweasel support interface.
                               ----------------------------
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

#ifndef  _catweasel_h_
#define  _catweasel_h_

#include <vector>
#include "sidbuilder.h"


class CWMK3Builder: public sidbuilder
{
private:
    static uint m_instance;
    char   m_errorBuffer[100];
    std::vector<sidemu *> sidobjs;

public:
    CWMK3Builder  (const char * const name);
    ~CWMK3Builder (void);
    // true will give you the number of used devices.
    //    return values: 0 none, positive is used sids
    // false will give you all available sids.
    //    return values: 0 endless, positive is available sids.
    // use bool operator to determine error
    uint        devices (bool used);
    uint        create  (uint sids);
    sidemu     *lock    (c64env *env, sid2_model_t model);
    void        unlock  (sidemu *device);
    void        remove  (void);
    const char *error   (void) const { return m_errorBuffer; }
    const char *credits (void);
    void        flush   (void);
    void        filter  (bool enable);
};

#endif // _catweasel_h_
