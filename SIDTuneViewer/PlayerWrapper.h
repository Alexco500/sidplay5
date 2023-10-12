//
//  PlayerWrapper.h
//  SIDPLAY
//
//  Created by Alexander Coers on 29.09.23.
//
/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */
#ifndef PlayerWrapper_h
#define PlayerWrapper_h


@interface PlayerWrapper : NSObject {
    BOOL tuneLoaded;
    BOOL isPlaying;
}
+ (id)sharedPlayer;
- (id)init;
- (BOOL)loadTuneFrom:(NSData *)data asInstance:(unsigned int*)instance;
- (void)stopAllPlayerInstances;
- (void)stopPlayerWithInstance:(unsigned int)instance;
- (short *)currentAudioBuffer;
- (unsigned int)currentNumberOfSamples;
- (BOOL)isPlaying;
- (NSString *)currentTitle;
- (NSString *)currentAuthor;
- (NSString *)currentReleaseInfo;
- (unsigned int)subtuneCount;
- (unsigned int)defaultSubtune;
- (unsigned int)sidChips;
- (unsigned int)currentLoadAddress;
- (unsigned int)currentInitAddress;
- (unsigned int)currentPlayAddress;
- (NSString *)currentFormat;
- (unsigned int)currentFileSize;
- (NSString *)currentChipModel;

@end
#endif /* PlayerWrapper_h */
