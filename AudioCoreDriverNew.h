/*

 Copyright (c) 2005, Andreas Varga <sid@galway.c64.org>
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are
 met:

 * Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 * Neither the name of the copyright holder nor the names of its contributors
 may be used to endorse or promote products derived from this software
 without specific prior written permission.


 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#ifndef _AUDIOQUEUEDRIVER_H_
#define _AUDIOQUEUEDRIVER_H_

#include <CoreAudio/CoreAudio.h>
//#include <AudioToolbox/AudioQueue.h>
#include <CoreServices/CoreServices.h>
#include <AudioUnit/AudioUnit.h>


class PlayerLibSidplay;

enum
{
	BUFFER_COUNT = 3
};

#define AUDIO_BUFFER_LENGTH ((44100*2*2)/50)

class AudioCoreDriverNew : public AudioDriver
{
public:

    AudioCoreDriverNew();
	~AudioCoreDriverNew();

	void initialize(PlayerLibSidplay* player, int sampleRate = 44100, int bitsPerSample = 16);
    void deinitialize();

	bool startPlayback();
	void stopPlayback();
	
     bool    startPreRenderedBufferPlayback() {return false;}
     void    stopPreRenderedBufferPlayback() {return;}
     void    setPreRenderedBuffer(short* inBuffer, int inBufferLength) {return;}
     bool    getIsPlayingPreRenderedBuffer() {return false;}
    int        getPreRenderedBufferPlaybackPosition() {return 0;}
     void    setPreRenderedBufferPlaybackPosition(int inPosition) {return;}

    float   getVolume() {return mVolume;}
    void    setVolume(float volume);

    float    getPreRenderedBufferVolume() {return 0;}
    void     setPreRenderedBufferVolume(float volume) {return;}
 
    void    setBufferUnderrunDetected(bool flag) {return;}
    bool    getBufferUnderrunDetected() {return false;}

    inline bool getIsPlaying()            { return mIsPlaying; }
    inline short* getSampleBuffer()        { return mSampleBuffer; }
    inline int getSampleRate()            { return mSampleRate; }
    
	inline int getSampleBufferSize()	{ return mSampleBufferSize; }
	inline bool getIsInitialized()		{ return mIsInitialized; }
    
    inline int getNumSamplesInBuffer()   { return mNumSamplesInBuffer; }
private:
    inline float getScaleFactor()          { return mScaleFactor; }
    
	void fillBuffer();
    static OSStatus    MyRenderer(void                 *inRefCon,
                           AudioUnitRenderActionFlags     *ioActionFlags,
                           const AudioTimeStamp         *inTimeStamp,
                           UInt32                         inBusNumber,
                           UInt32                         inNumberFrames,
                           AudioBufferList             *ioData);
	bool							mIsInitialized;
	PlayerLibSidplay*				mPlayer;

	UInt32							mAudioFrameCount;
	AudioStreamBasicDescription		mStreamFormat;
    AudioComponentDescription       mDesc;
    AudioUnit                       gOutputUnit;
    AudioDeviceID                   gOutputDevice;
    UInt32                          pointerInPacket;
    UInt32                          bufferInUse;
    int                             numberOfChannelsPerFrame;
    
    
	int								mSampleRate;
	int								mSampleBufferSize;
	short*							mSampleBuffer;

	bool							mFastForward;
	float							mVolume;
	float							mAudioLevel;
	bool							mIsPlaying;
 
    int                         mNumSamplesInBuffer;
    float                       mScaleFactor;

    bool                        mIsPlayingPreRenderedBuffer;
    short*                        mPreRenderedBuffer;
    int                            mPreRenderedBufferSampleCount;
    int                            mPreRenderedBufferPlaybackPosition;
    float                        mPreRenderedBufferVolume;
    float                       mPreRenderedBufferScaleFactor;
    
    bool                        mBufferUnderrunDetected;
    int                         mBufferUnderrunCount;
    int                         mInstanceId;
    
    static const int            sBufferUnderrunLimit = 10;

    int                     mSizeOfAudioBuffer;
    
};


#endif // _AUDIOQUEUEDRIVER_H_
