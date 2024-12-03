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

#ifndef SONGLENGTHFILE_H
#define SONGLENGTHFILE_H

#include <vector>

#include "Base.h"
#include "Item.h"

class SongLengthFile : public SongLengthDB
{
 public:
    SongLengthFile();
    ~SongLengthFile();
    bool init(const char* fileName);
	bool init(char* databaseBuffer, int databaseSize);
	
    bool getSongLength(const char* md5digest, int songNum, struct SongLengthDBitem* item);
	// [AV] added item retrieval by verbose filename
	bool getSongLengthByFileName(const char* rootPath, const char* filename, int songNum, struct SongLengthDBitem* item);

    bool getStatus()  { return status; }
    const char* getErrorStr()  { return errorString; }
    
 private:
    int parseTimeStamp(const char*);
    void clear();
    
    bool status;
    const char* errorString;
        
    std::vector<const char*> vec;

    char* dbFileNameAbs;
    char* hvscRoot;
    char* pDB;
    
	// [AV] added item retrieval by verbose filename
	int mDBFileLen;
	
    // prevent copying
    SongLengthFile(const SongLengthFile&);
    SongLengthFile& operator=(SongLengthFile&);  
};

#endif  /* SONGLENGTHFILE_H */
