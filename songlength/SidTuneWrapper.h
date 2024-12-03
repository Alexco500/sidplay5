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
#import <Foundation/Foundation.h>

@interface SidTuneWrapper : NSObject
{
}
- (BOOL) open:(const char*) fileName;
- (BOOL) load:(void*) buf withLength:(unsigned long int) bufLen;

- (const char*) getMD5_Digest;

-(void) updateInfo;

-(BOOL) getStatus;

-(int) getSongs;
-(int) getCurrentSong;
-(int) getStartSong;

-(const char*) getInfoStringWithNumber:(int) number;
-(int) getInfoStringsNum;
// (ms) For a free-form credit field with an arbitrary number
// of lines, a line-iterator would be more comfortable.

-(int) getLoadAddr;
-(int) getInitAddr;
-(int) getPlayAddr;

-(const char*) getStatusString;
-(const char*) getFormatString;

-(BOOL) savePSID:(const char *) fileName withOverwrite:(BOOL) overWrite;
- (void *)getSidTune;

-(int) getMaxSongs;
-(unsigned long int) getMaxSidFileLen;

@end

#endif  /* SIDTUNEWRAPPER_H */
