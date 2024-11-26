/*
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef SIDTUNEWRAPPER_H
#define SIDTUNEWRAPPER_H

//#include <qthread.h>

#include "SidTuneInfo.h"

//class emuEngine;
//struct emuConfig;
class SidTune;


class SidTuneWrapper
{
 public:
    SidTuneWrapper();
    ~SidTuneWrapper();

    bool open(const char*);
    bool load(void*, unsigned long int);
    
    const char* getMD5_Digest();
    
    void updateInfo();

    bool getStatus() const;
    
    int getSongs() const;
    int getCurrentSong() const;
    int getStartSong() const;
    
    const char* getInfoString(int) const;
    int getInfoStringsNum() const;
    // (ms) For a free-form credit field with an arbitrary number
    // of lines, a line-iterator would be more comfortable.

    int getLoadAddr() const;
    int getInitAddr() const;
    int getPlayAddr() const;

    const char* getStatusString() const;
    const char* getFormatString() const;
    
    bool savePSID(const char *, bool overWrite);

    SidTune* getSidTune() const;

    static int getMaxSongs();
    static unsigned long int getMaxSidFileLen();
    
 protected:
    SidTune* pSid;
    SidTuneInfo* pSidInfo;
    char* pDigest;
    
 private:
    // prevent copying
    SidTuneWrapper(const SidTuneWrapper&);
    SidTuneWrapper& operator=(SidTuneWrapper&);  
};

#endif  /* SIDTUNEWRAPPER_H */
