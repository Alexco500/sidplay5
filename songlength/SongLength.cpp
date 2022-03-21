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

#include "SongLength.h"
#include "SidTuneMod.h"
#include "SidTuneWrapper.h"

SongLengthFile SongLength::db;
bool SongLength::initStatus = false;

bool SongLength::init(const char* fileName)
{
    initStatus = db.init(fileName);
    return initStatus;
}

bool SongLength::init(char* databaseBuffer, int databaseSize)
{
    initStatus = db.init(databaseBuffer, databaseSize);
    return initStatus;
}

bool SongLength::getItem(SidTuneWrapper* pSidLoader, int song, SongLengthDBitem& item)
{
    char *digest = (char *) pSidLoader->getMD5_Digest();
    return db.getSongLength( digest, song, item );
}

bool SongLength::getItem(const char* rootPath, const char* fileName, int song, SongLengthDBitem& item )
{
	if (rootPath == NULL || fileName == NULL)
		return false;

    bool success = false;
	
//    try
//    {
        SidTuneWrapper* pSidLoader = new SidTuneWrapper;
        if ( pSidLoader->open( fileName )  )
        {
            char *digest = (char *) pSidLoader->getMD5_Digest();
            success = db.getSongLength( digest, song, item );
			
			if (!success) {
				// [AV] try lookup by verbose filename
				success = db.getSongLengthByFileName(rootPath, fileName, song, item );
			}
        }
        delete pSidLoader;
//    }
//    catch (...)
//    {
//    }
    return success;
}

bool SongLength::isAvailable()
{
    return initStatus;
}

const char* SongLength::getErrorStr()
{
    return db.getErrorStr();
}

bool SongLength::getStatus()
{
    return db.getStatus();
}
