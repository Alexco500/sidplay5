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
#include "TypeWrapper.h"

// sid lib
#include "SidTune.h"
#include "sidplayfp/SidTuneInfo.h"


#include <stdlib.h>
#include <string.h>

const uint_least16_t SIDTUNE_MAX_SONGS = 256;
const uint_least32_t SIDTUNE_MAX_MEMORY = 65536;
const uint_least32_t SIDTUNE_MAX_FILELEN = SIDTUNE_MAX_MEMORY+2+0x7C; //memory + SID file overhead



SidTune* pSid;
SidTuneInfo* pSidInfo;
char* pDigest;

@implementation SidTuneWrapper
-(int) getMaxSongs
{
	return SIDTUNE_MAX_SONGS;
}

-(unsigned long int) getMaxSidFileLen
{
    return SIDTUNE_MAX_FILELEN;
}

-(id)init
{
    self = [super init];
    pSid = new SidTune(0);
    //pSidInfo = new SidTuneInfo;
    pDigest = NULL;
    return self;
}

-(void)dealloc
{
	if ( pDigest != NULL ) {
		free( pDigest );
	}
	
    //delete pSidInfo;
    delete pSid;
}

- (BOOL) open:(const char*) fileName
{
    pSid->load(fileName);
    bool ret = pSid->getStatus();
    [self updateInfo];
    return ret;
}

- (BOOL) load:(void*) buf withLength:(unsigned long int) bufLen
{
    pSid->read((const ubyte_emuwt*)buf,(udword_emuwt)bufLen);
    bool ret = pSid->getStatus();
    [self updateInfo];
    return ret;
}

- (const char*) getMD5_Digest
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

-(void) updateInfo
{
    pSidInfo = (SidTuneInfo *)pSid->getInfo();
}

-(BOOL) getStatus
{
    return pSid->getStatus();
}

-(int) getLoadAddr
{
    return pSidInfo->loadAddr();
}

-(int) getInitAddr;
{
    return pSidInfo->initAddr();
}

-(int) getPlayAddr;
{
    return pSidInfo->playAddr();
}

-(int) getSongs;
{
    return pSidInfo->songs();
}

-(int) getCurrentSong;
{
    return pSidInfo->currentSong();
}

-(int) getStartSong;
{
    return pSidInfo->startSong();
}

-(const char*) getInfoStringWithNumber:(int) number;
{
    return pSidInfo->infoString(number);
}

-(int) getInfoStringsNum
{
    return pSidInfo->numberOfInfoStrings();
}

-(const char*) getStatusString
{
    return pSid->statusString();
}

-(const char*) getFormatString
{    
    return pSidInfo->formatString();
}
-(BOOL) savePSID:(const char *) fileName withOverwrite:(BOOL) overWrite
{
    return false;
    /* FIXME: missing PSID */
    //return pSid->savePSIDfile(fileName,overWrite);
}

- (void *)getSidTune
{
    return pSid;
}
@end
