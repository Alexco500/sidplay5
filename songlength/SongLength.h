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

#include "SidTuneWrapper.h"
#include "Item.h"

@interface SongLength : NSObject
{
    
}

- (id) initWithFile:(const char*) fileName;
- (id) initWithDB:(char*) databaseBuffer andSize:(int) databaseSize;
    
-(BOOL) getItem:(SidTuneWrapper*) pSidLoader number:(int) songNum item:(struct SongLengthDBitem *) item;
-(BOOL) getItem:(const char*) rootPath file:(const char*) fileName song:(int) songNum item:(struct SongLengthDBitem*) item;
-(BOOL) isAvailable;
- (const char*) getErrorStr;
- (BOOL) getStatus;


@end
#endif  /* XSIDPLAY_SONGLENGTH_H */
