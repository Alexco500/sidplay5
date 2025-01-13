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

#include "File.h"

SongLengthFile* db;  // the database
bool initStatus = false;

@implementation SongLength
-(id)init
{
    self = [super init];
    if (self)
    {
        db = new SongLengthFile;
    }
    return self;
}


- (id) initWithFile:(const char*) fileName
{
    self = [super init];
    if (self)
    {
        db = new SongLengthFile;
        initStatus = db->init(fileName);
    }
    return self;
}

- (id) initWithDB:(char*) databaseBuffer andSize:(int) databaseSize
{
    self = [super init];
    if (self)
    {
        db = new SongLengthFile;
        initStatus = db->init(databaseBuffer, databaseSize);
    }
    return self;
}

-(BOOL) getItem:(SidTuneWrapper*) pSidLoader number:(int) songNum item:(struct SongLengthDBitem *) item
{
    char *digest = (char *) [pSidLoader getMD5_Digest];
    return db->getSongLength( digest, songNum, item );
}

-(BOOL) getItem:(const char*) rootPath file:(const char*) fileName song:(int) songNum item:(struct SongLengthDBitem*) item
{
	if (rootPath == NULL || fileName == NULL)
		return false;

    bool success = false;
	
        SidTuneWrapper* pSidLoader = [[SidTuneWrapper alloc] init];
        if ( [pSidLoader open:fileName]  )
        {
            char *digest = (char *) [pSidLoader getMD5_Digest];
            success = db->getSongLength( digest, songNum, item );
			
			if (!success) {
				// [AV] try lookup by verbose filename
				success = db->getSongLengthByFileName(rootPath, fileName, songNum, item );
			}
        }

    return success;
}

-(BOOL) isAvailable
{
    return initStatus;
}

- (const char*) getErrorStr
{
    return db->getErrorStr();
}

- (BOOL) getStatus
{
    return db->getStatus();
}
@end
