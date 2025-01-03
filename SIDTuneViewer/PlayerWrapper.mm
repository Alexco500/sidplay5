//
//  PlayerWrapper.m
//  SIDTuneViewer
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
#import <Foundation/Foundation.h>
#import "PlayerWrapper.h"
#include "PlayerLibSidplayWrapper.h"
#include "AudioCoreDriverNew.h"

@implementation PlayerWrapper
PlayerLibSidplayWrapper* player;
AudioCoreDriverNew* audioDriver;
struct PlaybackSettings mSimplePlaybackSettings;
unsigned int mInstance;

+ (id)sharedPlayer
{
    static PlayerWrapper *sharedPlayerWrapper = nil;
    @synchronized(self) {
        if (sharedPlayerWrapper == nil)
            sharedPlayerWrapper = [[self alloc] init];
    }
    return sharedPlayerWrapper;
}
- (id)init
{
    self = [super init];
    [self initPlayer];
    mInstance = 0;
    return self;
}
- (void)initPlayer
{
    player = [[PlayerLibSidplayWrapper alloc] init];
    audioDriver = new AudioCoreDriverNew;
    [player setAudioDriver:(audioDriver)];
    
    audioDriver->initialize(player);
    audioDriver->setVolume(1.0f);
    mSimplePlaybackSettings.mFrequency = audioDriver->getSampleRate();

    tuneLoaded = NO;
    isPlaying = NO;
    // setup player engine
    //mPlaybackSettings.mFrequency = 44100;
    mSimplePlaybackSettings.mBits = 16;
    mSimplePlaybackSettings.mStereo = false;
    mSimplePlaybackSettings.mOversampling = 1;
    mSimplePlaybackSettings.mSidModel = 0;
    mSimplePlaybackSettings.mForceSidModel = false;
    mSimplePlaybackSettings.mClockSpeed = 0;
}
- (void)destroyPlayer
{
    if (audioDriver) {
        audioDriver->stopPlayback();
        delete audioDriver;
        audioDriver = nil;
    }
    if (player) {
        player = nil;
    }
}
- (BOOL)loadTuneFrom:(NSData *)data asInstance:(unsigned int *)instance
{
    BOOL retVal = NO;
    @synchronized (self) {
        if (tuneLoaded) {
            audioDriver->stopPlayback();
            tuneLoaded = NO;
            isPlaying = NO;
        }
        //[self destroyPlayer];
        //[self initPlayer];
        retVal = [player loadTuneFromBuffer:(char*)[data bytes] withLength:(int) [data length] subtune:0 withSettings:&mSimplePlaybackSettings];

        tuneLoaded = retVal;
        if (tuneLoaded) {
            isPlaying = YES;
            [player initCurrentSubtune];
            if (*instance == 0) {
                @synchronized (self) {
                    mInstance++;
                    *instance = mInstance;
                }
            }
            audioDriver->startPlayback();
        }
    }
    return retVal;
}
- (void)stopAllPlayerInstances
{
    audioDriver->stopPlayback();
    isPlaying = NO;
}
- (void)stopPlayerWithInstance:(unsigned int)instance
{
    @synchronized (self) {
        //ignore everything except the current instance
        if (instance != mInstance)
            return;
        audioDriver->stopPlayback();
        isPlaying = NO;
    }
}
- (short *)currentAudioBuffer
{
    return audioDriver->getSampleBuffer();
}
- (unsigned int)currentNumberOfSamples
{
    return audioDriver->getNumSamplesInBuffer();
}
- (BOOL)isPlaying
{
    @synchronized (self) {
        return isPlaying;
    }
}
#pragma mark SIDTune info
/* SID info
 const char*        getCurrentTitle();
 const char*        getCurrentAuthor();
 const char*        getCurrentReleaseInfo();
 int                getSubtuneCount();
 int                getDefaultSubtune();
 unsigned short     getSidChips();
 unsigned short     getCurrentLoadAddress();
 unsigned short     getCurrentInitAddress();
 unsigned short     getCurrentPlayAddress();
 const char*        getCurrentFormat();
 int                getCurrentFileSize();
 const char*        getCurrentChipModel();
 */
- (NSString *)currentTitle
{
    NSString *tempString;
    if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        tempString = [NSString stringWithCString:[player getCurrentTitle] encoding:NSISOLatin1StringEncoding];
    else
        tempString = [NSString string];
    return tempString;
}
- (NSString *)currentAuthor
{
    NSString *tempString;
    if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        tempString = [NSString stringWithCString:[player getCurrentAuthor] encoding:NSISOLatin1StringEncoding];
    else
        tempString = [NSString string];
    return tempString;
}
- (NSString *)currentReleaseInfo
{
    NSString *tempString;
    if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        tempString = [NSString stringWithCString:[player getCurrentReleaseInfo] encoding:NSISOLatin1StringEncoding];
    else
        tempString = [NSString string];
    return tempString;
}
- (NSString *)currentFormat
{
    NSString *tempString;
    if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        tempString = [NSString stringWithCString:[player getCurrentFormat] encoding:NSISOLatin1StringEncoding];
    else
        tempString = [NSString string];
    return tempString;
}
- (NSString *)currentChipModel
{
    NSString *tempString;
    if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        tempString = [NSString stringWithCString:[player getCurrentChipModel] encoding:NSISOLatin1StringEncoding];
    else
        tempString = [NSString string];
    return tempString;
}
- (unsigned int)currentLoadAddress
{
    if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        return (unsigned int)[player getCurrentLoadAddress];
    else
        return 0;
}
- (unsigned int)currentInitAddress
{
    if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        return (unsigned int)[player getCurrentInitAddress];
    else
        return 0;
}
- (unsigned int)currentPlayAddress
{
    if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        return (unsigned int)[player getCurrentPlayAddress];
    else
        return 0;
}
- (unsigned int)sidChips
{
    if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        return (unsigned int)[player getSidChips];
    else
        return 0;
}
- (unsigned int)currentFileSize
{
    if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        return (unsigned int)[player getCurrentFileSize];
    else
        return 0;
}
- (unsigned int)subtuneCount
{
    if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        return (unsigned int)[player getSubtuneCount];
    else
        return 0;
}
- (unsigned int)defaultSubtune
{
    if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        return (unsigned int)[player getDefaultSubtune];
    else
        return 0;
}

@end
