//
//  PlayerLibSidplayWrapper.h
//  SIDPLAY
//
//  Created by Alexander Coers on 14.11.24.
//

/* PlayerLibSidplayWrapper is a Objective-C++ wrapper
 * for libsidplayfp. No C++ yaddayadda inside this .h file
 * or this can't be included in regular ObjC classes
 */


#import <Foundation/Foundation.h>

#include "PlaybackSettings.h"

typedef int_fast64_t event_clock_t;

NS_ASSUME_NONNULL_BEGIN
// for PopupSIDSelector
enum SIDmodelsGUI
{
    M_UNKNOWN = 0,
    M_6581,
    M_8580
};

#define SID_REGISTER_COUNT 0x19
struct SidRegisterFrame
{
    /*
     SidRegisterFrame() : mTimeStamp(0) { for (int i = 0; i < SID_REGISTER_COUNT; i++) mRegisters[i] = 0; }
     */
    uint8_t mRegisters[32];  //sidplayfp uses 32, not 25
    event_clock_t mTimeStamp;
};
#define sDefault8580PointCount 31
#define TUNE_BUFFER_SIZE  (65536 + 2 + 0x7c)


@interface PlayerLibSidplayWrapper : NSObject
{
    BOOL  mExtUSBDeviceActive;
    char  mTuneBuffer[TUNE_BUFFER_SIZE];
    int   mTuneLength;
    
    int  mCurrentSubtune;
    int  mSubtuneCount;
    int  mDefaultSubtune;
    int  mCurrentTempo;
    
    int  mPreviousOversamplingFactor;
    char* mOversamplingBuffer;
}

@property (NS_NONATOMIC_IOSONLY, readonly) const char* sChipModel6581;
@property (NS_NONATOMIC_IOSONLY, readonly) const char* sChipModel8580;
@property (NS_NONATOMIC_IOSONLY, readonly) const char* sChipModelUnknown;
@property (NS_NONATOMIC_IOSONLY, readonly) const char* sChipModelUnspecified;

- (void) setAudioDriver:(void*) audioDriver;
- (void) stopEmuEngine;
- (void) initEmuEngineWithSettings:(struct PlaybackSettings*)settings;
- (void) updateSampleRate:(unsigned int) newSampleRate;
- (BOOL) playTuneByPath:(const char *)filename subtune:(int) subtune withSettings:(struct PlaybackSettings *)settings;
- (BOOL) playTuneFromBuffer:(char *)buffer withLength:(int) length subtune:(int) subtune withSettings:(struct PlaybackSettings *)settings;
- (BOOL) loadTuneByPath:(const char *)filename subtune:(int) subtune withSettings:(struct PlaybackSettings *)settings;
- (BOOL) loadTuneFromBuffer:(char *)buffer withLength:(int) length subtune:(int) subtune withSettings:(struct PlaybackSettings *)settings;
- (BOOL) startPrevSubtune;
- (BOOL) startNextSubtune;
- (BOOL) startSubtune:(int) which;
- (BOOL) initCurrentSubtune;
- (void) fillBuffer:(void*) buffer withLen: (int) len;
- (int) getTempo;       //    { return mCurrentTempo; }
- (void) setTempo:(int)tempo;
- (void) setVoiceVolume:(float)volume forVoice:(int) voice;

//    sid_filter_t*            getFilterSettings()                                    { return &mFilterSettings; }
//    void                    setFilterSettings(sid_filter_t* filterSettings);

- (BOOL) isTuneLoaded; //    { return mSidTune != NULL; }
- (int) getPlaybackSeconds;
- (int) getCurrentSubtune;  //     { return mCurrentSubtune; }
- (int) getSubtuneCount;   //    { return mSubtuneCount; }
- (int) getDefaultSubtune;  // { return mDefaultSubtune; }

- (int) hasTuneInformationStrings;
- (const char*) getCurrentTitle;
- (const char*) getCurrentAuthor;
- (const char*) getCurrentReleaseInfo;
- (unsigned short) getCurrentLoadAddress;
- (unsigned short) getCurrentInitAddress;
- (unsigned short) getCurrentPlayAddress;
- (unsigned short) getSidChips;

- (const char*) getCurrentFormat;
- (int) getCurrentFileSize;
- (char*) getTuneBuffer:(int *) outTuneLength;
- (const char*) getCurrentChipModel;

// for popoverSIDSelector
- (int) getSIDModelFromTune;
- (struct PlaybackSettings*) getCurrentPlaybackSettings;

- (struct SidRegisterFrame*) getCurrentSidRegisters;
- (void) sidRegisterFrameHasChanged:(void*) inInstance inFrame:(struct SidRegisterFrame *) inRegisterFrame;
@end

NS_ASSUME_NONNULL_END

