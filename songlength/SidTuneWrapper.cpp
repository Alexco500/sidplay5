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

#include "SidTuneWrapper.h"
#include "MD5.h"
#include "SidTune.h"
#include "TypeWrapper.h"

#include "sidplayfp/SidTuneInfo.h"


#include <stdlib.h>
#include <string.h>

const uint_least16_t SIDTUNE_MAX_SONGS = 256;
const uint_least32_t SIDTUNE_MAX_MEMORY = 65536;
const uint_least32_t SIDTUNE_MAX_FILELEN = SIDTUNE_MAX_MEMORY+2+0x7C; //memory + SID file overhead

int SidTuneWrapper::getMaxSongs()  // static
{
	return SIDTUNE_MAX_SONGS;
}

unsigned long int SidTuneWrapper::getMaxSidFileLen()  // static
{
    return SIDTUNE_MAX_FILELEN;
}

SidTuneWrapper::SidTuneWrapper()
{
    pSid = new SidTune(0);
    //pSidInfo = new SidTuneInfo;
    pDigest = NULL;
}

SidTuneWrapper::~SidTuneWrapper()
{
	if ( pDigest != NULL ) {
		free( pDigest );
	}
	
    //delete pSidInfo;
    delete pSid;
}

bool SidTuneWrapper::open(const char* fileName)
{
    pSid->load(fileName);
    bool ret = pSid->getStatus();
    updateInfo();
    return ret;
}

bool SidTuneWrapper::load(void* buf, unsigned long int bufLen)
{
    pSid->read((const ubyte_emuwt*)buf,(udword_emuwt)bufLen);
    bool ret = pSid->getStatus();
    updateInfo();
    return ret;
}

const char *SidTuneWrapper::getMD5_Digest()
{
    /*
    MD5 myMD5;
    pSid->createMD5(myMD5);
    myMD5.finish();
    // Print fingerprint.
//    for (int di = 0; di < 16; ++di)
//        printf("%02x",(int)myMD5.getDigest()[di]);
//
//    printf("\n");
    
	char buf[ 256 ];

	buf[ 0 ] = 0;
	char tmp[ 10 ];
    for (int di = 0; di < 16; ++di) {
		snprintf( tmp, 10, "%02x", (int) myMD5.getDigest()[ di ] );
		strncat( buf, tmp, 256 );
	}

	pDigest = (char *) malloc( strlen( buf ) + 1 );
	strcpy( pDigest, buf );
	
    return pDigest;
    */
    return pSid->createMD5();
}

void SidTuneWrapper::updateInfo()
{
    pSidInfo = (SidTuneInfo *)pSid->getInfo();
}

bool SidTuneWrapper::getStatus() const
{
    return pSid->getStatus();
}

int SidTuneWrapper::getLoadAddr() const
{
    return pSidInfo->loadAddr();
}

int SidTuneWrapper::getInitAddr() const
{
    return pSidInfo->initAddr();
}

int SidTuneWrapper::getPlayAddr() const
{
    return pSidInfo->playAddr();
}

int SidTuneWrapper::getSongs() const
{
    return pSidInfo->songs();
}

int SidTuneWrapper::getCurrentSong() const
{
    return pSidInfo->currentSong();
}

int SidTuneWrapper::getStartSong() const
{
    return pSidInfo->startSong();
}

const char* SidTuneWrapper::getInfoString(int i) const
{
    return pSidInfo->infoString(i);
}

int SidTuneWrapper::getInfoStringsNum() const
{
    return pSidInfo->numberOfInfoStrings();
}

const char* SidTuneWrapper::getStatusString() const
{
    return pSid->statusString();
}

const char* SidTuneWrapper::getFormatString() const
{    
    return pSidInfo->formatString();
}

bool SidTuneWrapper::savePSID(const char* fileName, bool overWrite)
{
    return false;
    /* FIXME: missing PSID */
    //return pSid->savePSIDfile(fileName,overWrite);
}

SidTune* SidTuneWrapper::getSidTune() const
{
    return pSid;
}

