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

// Write a big-endian 16-bit word to two bytes in memory.
inline void writeLEword(unsigned char ptr[2], int someWord)
{
	ptr[0] = (someWord & 0xFF);
	ptr[1] = (someWord >> 8);
}

#include "SidTuneMod.h"
#include "MD5.h"

void SidTuneMod::createMD5(MD5& myMD5)
{
    if (status)
    {
        // Include C64 data.
        myMD5.append(cache.get()+fileOffset,info.c64dataLen);
        unsigned char tmp[2];

        // Include INIT and PLAY address.
        writeLEword(tmp,info.initAddr);
        myMD5.append(tmp,sizeof(tmp));
        writeLEword(tmp,info.playAddr);
        myMD5.append(tmp,sizeof(tmp));
        // Include number of songs.
        writeLEword(tmp,info.songs);
        myMD5.append(tmp,sizeof(tmp));
        // Include song speed for each song.
        for (unsigned int s = 1; s <= info.songs; s++)
        {
            selectSong(s);
            myMD5.append(&info.songSpeed,sizeof(info.songSpeed));
        }
        // Deal with PSID v2NG clock speed flags: Let only NTSC
        // clock speed change the MD5 fingerprint. That way the
        // fingerprint of a PAL-speed sidtune in PSID v1, v2, and
        // PSID v2NG format is the same.
        if ( info.clockSpeed == SIDTUNE_CLOCK_NTSC )
            myMD5.append(&info.clockSpeed,sizeof(info.clockSpeed));

        // NB! If the fingerprint is used as an index into a
        // song-lengths database or cache, modify above code to
        // allow for PSID v2NG files which have clock speed set to
        // SIDTUNE_CLOCK_ANY. If the SID player program fully
        // supports the SIDTUNE_CLOCK_ANY setting, a sidtune could
        // either create two different fingerprints depending on
        // the clock speed chosen by the player, or there could be
        // two different values stored in the database/cache.
    }
}
