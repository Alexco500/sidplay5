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

#ifndef XSIDPLAY_SONGLENGTH_H
#define XSIDPLAY_SONGLENGTH_H

class SidTuneWrapper;
    
#include "File.h"

class SongLength
{
 public:
    static bool init(const char* fileName);
    static bool init(char* databaseBuffer, int databaseSize);

    static bool getItem(SidTuneWrapper*, int songNum, SongLengthDBitem& item);
    static bool getItem(const char*, const char*, int songNum, SongLengthDBitem& item);
    static bool isAvailable();
    static const char* getErrorStr();
    static bool getStatus();
    
 protected:
    static SongLengthFile db;  // the database
    static bool initStatus;
    
 private:
    SongLength();
    ~SongLength();
};

#endif  /* XSIDPLAY_SONGLENGTH_H */
