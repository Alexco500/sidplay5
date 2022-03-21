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

#ifdef XSID_WB_DEBUG
#include <iostream>
#include <iomanip>
#endif

#include <algorithm>
#include <functional>
#include <vector>
#include <cctype>
#include <fstream>
#ifdef XSID_HAVE_NOTHROW
#include <new>
#endif
using namespace std;

#include "File.h"

// String comparison functor for sort function.
struct myStrLessThan : public binary_function<const char*, const char*, bool> 
{
    bool operator()(const char* x, const char* y) 
    {
        return (strcmp(x,y)<0); 
    }
};

const char _SongLengthFile_text_cantOpenFile[] = "Failed to open Songlengths.txt!";
const char _SongLengthFile_text_cantLoadFile[] = "Failed to read Songlengths.txt!";
const char _SongLengthFile_text_notEnoughMemory[] = "Not enough memory!";
const char _SongLengthFile_text_noEntry[] = "No database entry for this file!";
const char _SongLengthFile_text_badSong[] = "Requested song number too high! Wrong songlengths file version?";
const char _SongLengthFile_text_noErrors[] = "No error.";

SongLengthFile::SongLengthFile()
{
    errorString = _SongLengthFile_text_noErrors;
    
    status = false;

    dbFileNameAbs = 0;
    hvscRoot = 0;
    pDB = 0;
}

SongLengthFile::~SongLengthFile()
{
    clear();
}

void SongLengthFile::clear()
{
    while ( !vec.empty() )
        vec.pop_back();
    if (pDB != 0)
        delete[] pDB;
    pDB = 0;
    if (hvscRoot != 0)
        delete[] hvscRoot;
    hvscRoot = 0;
    if (dbFileNameAbs != 0)
        delete[] dbFileNameAbs;
    dbFileNameAbs = 0;
    status = false;
}

/*
 * Tries to load the songlength file somewhere from within the HVSC
 * directory tree. If successful, it will try to build a database
 * and return "true".
 */
bool SongLengthFile::init(const char* fileName)
{
    clear();

    // Construct songlength database file name.
#ifdef XSID_HAVE_NOTHROW
    dbFileNameAbs = new(std::nothrow) char[strlen(fileName)+1];
#else
    dbFileNameAbs = new char[strlen(fileName)+1];
#endif
    if ( dbFileNameAbs == 0 )
    {
        clear();
        return false;
    }
    strcpy(dbFileNameAbs,fileName);
    
    // Open binary input file stream at end of file.
#ifdef XSID_HAVE_IOS_BIN
    ifstream myIn( dbFileNameAbs, ios::in | ios::bin | ios::ate );
#else
    ifstream myIn( dbFileNameAbs, ios::in | ios::binary | ios::ate );
#endif
    // As a replacement for !is_open(), bad() and the NOT-operator
    // might not work on all systems.
#ifdef XSID_DONT_HAVE_IS_OPEN
    if ( !myIn )
#else
    if ( !myIn.is_open() )
#endif
    {
        errorString = _SongLengthFile_text_cantOpenFile;
        clear();
        return false;
    }
#ifdef XSID_HAVE_SEEKG_OFFSET
    streampos fileLen = (myIn.seekg(0,ios::end)).offset();
#else
    myIn.seekg(0, ios::end);
    streampos fileLen = myIn.tellg();
#endif
#ifdef XSID_HAVE_NOTHROW
    pDB = new(std::nothrow) char[fileLen+1L];
#else
	// AV: for gcc4
    pDB = new char[static_cast<int>(fileLen)+1L];
#endif
    if ( pDB == 0 )
    {
        errorString = _SongLengthFile_text_notEnoughMemory;
        clear();
        return false;
    }
    pDB[fileLen] = 0;  // terminate buffer

    myIn.seekg(0,ios::beg);
    myIn.read(pDB,fileLen);
    if ( myIn.bad() || (int)fileLen==0 )
    {
        errorString = _SongLengthFile_text_cantLoadFile;
        clear();
        return false;
    }
    else
    {
        errorString = _SongLengthFile_text_noErrors;
    }
    myIn.close();
    
    return init(pDB, fileLen);
}


bool SongLengthFile::init(char* databaseBuffer, int databaseSize)
{
	if (pDB != databaseBuffer)
	{
		clear();
		
#ifdef XSID_HAVE_NOTHROW
		pDB = new(std::nothrow) char[databaseSize+1L];
#else
		// AV: for gcc4
		pDB = new char[static_cast<int>(databaseSize)+1L];
#endif
		if ( pDB == 0 )
		{
			errorString = _SongLengthFile_text_notEnoughMemory;
			clear();
			return false;
		}
		pDB[databaseSize] = 0;  // terminate buffer
		
		memcpy(pDB, databaseBuffer, databaseSize);
	}

	mDBFileLen = strlen(pDB);
	
    char* pDBentry = pDB;
    while (*pDBentry != 0)  // seek end of file buf
    {
        if ( *pDBentry!='[' && *pDBentry!=';' )
        {
            // Store pointer to current line.
            vec.push_back(pDBentry);
        }
        // Advance to line delimiter.
        while ( *pDBentry!=0x0a && *pDBentry!=0x0d )
        {
            ++pDBentry;
        }
        // Terminate line and advance to start of next line.
        while ( *pDBentry==0x0a || *pDBentry==0x0d )
        {
            *pDBentry = 0;
            ++pDBentry;
        }
    };
	
    sort(vec.begin(),vec.end(),myStrLessThan());

	return (status = true);
}



// [AV] added item retrieval by verbose filename
char *_strlwr(char *str)
{
	for (char *scan = str; *scan; scan++ )
	{
		*scan = tolower( *scan );
	}

	return str;
}

bool SongLengthFile::getSongLengthByFileName(const char* rootPath, const char* filename, int songNum, SongLengthDBitem& item)
{
	// taken from xmp_sid plugin by Sebastian Szczepaniak
	char temp[256];
	strcpy(temp, filename);
	_strlwr(temp);
	char *justFileName = strrchr(temp, '/') + 1;
	
	char *sid = strstr(temp, ".sid");
	if (sid)
	{
		if (strlen(justFileName)+5 > 29) strcpy(justFileName+21, "_PSID.sid");			
		else strcpy(sid, "_PSID.sid");
	}

    char* pDBentry = pDB;
    while ((pDBentry - pDB) < mDBFileLen)  // seek end of file buf
    {
        if ( *pDBentry == ';' )
        {
			char *pathNameStart = pDBentry + 2;
	
	        // Advance to line delimiter.
			while ( *pDBentry!=0x0a && *pDBentry!=0x0d && *pDBentry!=0x00)
			{
				++pDBentry;
			}

			// Terminate line and advance to start of next line.
			while ( *pDBentry==0x0a || *pDBentry==0x0d )
			{
				*pDBentry = 0;
				++pDBentry;
			}
			
			if (rootPath) {
			
				int len = strlen(rootPath);

				if (strcasecmp(pathNameStart, temp + len) == 0) {

					while ( *pDBentry != '=')
					{
						++pDBentry;
					}

					const char* pEntry = pDBentry;

					int leftToParse = strlen(pEntry);
					// Skip first spaces between file name and first time stamp.
					while ( isspace(*pEntry) || *pEntry=='=' )
					{
						++pEntry;
						--leftToParse;
					}
					while ( --songNum>0 && leftToParse>0 )
					{
						// Skip time-stamp.
						while ( !isspace(*pEntry) )
						{
							++pEntry;
							--leftToParse;
						}
						// Skip flag if available. 
						if ( leftToParse>=3 && pEntry[0]=='(' &&
							 isalpha(pEntry[1]) && pEntry[2]==')' )
						{
							pEntry += 3;
							leftToParse -= 3;
						}
						// Skip spaces in front of next time stamp.
						while ( isspace(*pEntry) )
						{
							++pEntry;
							--leftToParse;
						}
					};

					if ( leftToParse>0 )
					{
						item.playtime = parseTimeStamp(pEntry);
						errorString = _SongLengthFile_text_noErrors;
						return true;
					}
					else  // songNum > number of time-stamp entries
					{
						errorString = _SongLengthFile_text_badSong;
						return false;
					}
					
				}
			}
			
        } else {

			while ( *pDBentry!=0x00)
			{
				++pDBentry;
			}
			
			pDBentry++;
		}
    }
	
	return false;
}



bool SongLengthFile::getSongLength(const char* md5digest, int songNum,
                                   SongLengthDBitem& item)
{
#ifdef XSID_WB_DEBUG
    cout << "::getSongLength()" << endl << md5digest << endl << songNum << endl;
#endif
    
    item.clear();
    if ( !status )
        return false;

    int md5digestLen = strlen(md5digest);
    int cmpResult = 1;  // for result of strncmp()
    
    // Start searching in the middle of the array.
    int lowerBound = 0;
    int upperBound = vec.size()-1;
#ifdef XSID_WB_DEBUG
    cout << "upperBound = " << upperBound << endl;
#endif
    int currentPos = (upperBound-lowerBound)/2;
    
    while ( (upperBound-lowerBound) > 0 )
    {
        cmpResult = strncmp(vec[currentPos],md5digest,md5digestLen);
        if (cmpResult > 0)
        {
            // Go to lower half.
            upperBound = currentPos-1;
            currentPos = lowerBound+(upperBound-lowerBound)/2;
        }
        else if (cmpResult < 0)
        {
            // Go to upper half.
            lowerBound = currentPos+1;
            currentPos = upperBound-(upperBound-lowerBound)/2;
        }
        else  // if (cmpResult == 0)
        {
            break;
        }
#ifdef XSID_WB_DEBUG
        cout << "upperBound = " << upperBound << endl;
#endif
    };
    if ( (upperBound-lowerBound) == 0 )
        cmpResult = strncmp(vec[currentPos],md5digest,md5digestLen);
    if ( cmpResult != 0 )  // file name not found in DB?
    {
        errorString = _SongLengthFile_text_noEntry;
        return false;
    }

    const char* pEntry = vec[currentPos]+md5digestLen;
#ifdef XSID_WB_DEBUG
    cout << pEntry << endl;
#endif
    int leftToParse = strlen(pEntry);
    // Skip first spaces between file name and first time stamp.
    while ( isspace(*pEntry) || *pEntry=='=' )
    {
        ++pEntry;
        --leftToParse;
    }
    while ( --songNum>0 && leftToParse>0 )
    {
#ifdef XSID_WB_DEBUG
        cout << pEntry << endl;
#endif
        // Skip time-stamp.
        while ( !isspace(*pEntry) )
        {
            ++pEntry;
            --leftToParse;
        }
        // Skip flag if available. 
        if ( leftToParse>=3 && pEntry[0]=='(' &&
             isalpha(pEntry[1]) && pEntry[2]==')' )
        {
            pEntry += 3;
            leftToParse -= 3;
        }
        // Skip spaces in front of next time stamp.
        while ( isspace(*pEntry) )
        {
            ++pEntry;
            --leftToParse;
        }
    };

    if ( leftToParse>0 )
    {
        item.playtime = parseTimeStamp(pEntry);
        errorString = _SongLengthFile_text_noErrors;
        return true;
    }
    else  // songNum > number of time-stamp entries
    {
        errorString = _SongLengthFile_text_badSong;
        return false;
    }
}

/* Read in m:s format at most.
 * Could use a system function if available.
 */
int SongLengthFile::parseTimeStamp(const char* arg)
{
    int seconds = 0;
    int passes = 2;  // minutes, seconds
    bool gotDigits = false;
    while ( passes-- )
    {
        if ( isdigit(*arg) )
        {
            int t = atoi(arg);
            seconds += t;
            gotDigits = true;
        }
        while ( *arg && isdigit(*arg) )
        {
            ++arg;
        }
        if ( *arg && *arg==':' )
        {
            seconds *= 60;
            ++arg;
        }
    }
    
    // Handle -:-- time stamps and old 0:00 entries which
    // need to be rounded up by one second.
    if ( !gotDigits )
        seconds = 0;
    else if ( seconds==0 )
        ++seconds;
    
    return seconds;
}

