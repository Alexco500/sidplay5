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

#ifndef SONGLENGTHDB_BASE_H
#define SONGLENGTHDB_BASE_H

class SongLengthDBitem;

class SongLengthDB
{
 public:
    virtual ~SongLengthDB()  { ; }

    virtual bool init(const char* fileName) = 0;
	virtual bool init(char* databaseBuffer, int databaseSize) = 0;
	
    // Get database entry for a file name relative to the HVSC root.
    virtual bool getSongLength(const char* md5digest, int songNum,
                               struct SongLengthDBitem* item) = 0;
    
    virtual const char* getErrorStr() = 0;
};

#endif  /* SONGLENGTHDB_BASE_H */
