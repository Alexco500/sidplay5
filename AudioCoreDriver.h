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

#ifndef _AUDIOCOREDRIVER_H_
#define _AUDIOCOREDRIVER_H_

#include <CoreAudio/AudioHardware.h>
#include "AudioDriver.h"

class PlayerLibSidplay;


class AudioCoreDriver : public AudioDriver
{
public:

	AudioCoreDriver();
	~AudioCoreDriver();

	void initialize(PlayerLibSidplay* player, int sampleRate = 44100, int bitsPerSample = 16);
	void deinitialize();

	bool startPlayback();
	void stopPlayback();
	bool startPreRenderedBufferPlayback();
	void stopPreRenderedBufferPlayback();
	
	void setPreRenderedBuffer(short* inBuffer, int inBufferLength);
	
	inline bool getIsInitialized()										{ return mIsInitialized; }
	inline int getSampleRate()											{ return mStreamFormat.mSampleRate; }
	inline short* getSampleBuffer()										{ return mSampleBuffer; }
	inline int getNumSamplesInBuffer()									{ return mNumSamplesInBuffer; }

	inline void setBufferUnderrunDetected(bool flag)					{ mBufferUnderrunDetected = flag; if (!flag) mBufferUnderrunCount = 0; }
	inline bool getBufferUnderrunDetected()								{ return mBufferUnderrunDetected; };
	
	inline bool getIsPlaying()											{ return mIsPlaying; }
	inline float getVolume()											{ return mVolume; }
	void setVolume(float volume);

	inline bool getIsPlayingPreRenderedBuffer()							{ return mIsPlayingPreRenderedBuffer; }
	inline float getPreRenderedBufferVolume()							{ return mPreRenderedBufferVolume; }
	void setPreRenderedBufferVolume(float volume);
	
	inline int getPreRenderedBufferPlaybackPosition()					{ return mPreRenderedBufferPlaybackPosition; }
	inline void setPreRenderedBufferPlaybackPosition(int inPosition)	{ mPreRenderedBufferPlaybackPosition = inPosition; }
	
private:

	inline float getScaleFactor()										{ return mScaleFactor; }
	inline float getPreRenderedBufferScaleFactor()						{ return mPreRenderedBufferScaleFactor; }

	void fillBuffer();

	static OSStatus emulationPlaybackProc(AudioDeviceID inDevice,
										  const AudioTimeStamp *inNow,
										  const AudioBufferList *inInputData,
										  const AudioTimeStamp *inInputTime,
										  AudioBufferList *outOutputData, 
										  const AudioTimeStamp *inOutputTime,
										  void *inClientData);

	static OSStatus preRenderedBufferPlaybackProc(AudioDeviceID inDevice,
												  const AudioTimeStamp *inNow,
												  const AudioBufferList *inInputData,
												  const AudioTimeStamp *inInputTime,
												  AudioBufferList *outOutputData, 
												  const AudioTimeStamp *inOutputTime,
												  void *inClientData);
	
	static OSStatus deviceChanged(AudioHardwarePropertyID inPropertyID,	void* inClientData);

	static OSStatus streamFormatChanged(AudioDeviceID inDevice,
										UInt32 inChannel,
										Boolean isInput,
										AudioDevicePropertyID inPropertyID,
										void* inClientData);

	static OSStatus overloadDetected(AudioDeviceID inDevice,
					 			     UInt32 inChannel,
									 Boolean isInput,
									 AudioDevicePropertyID inPropertyID,
									 void* inClientData);

	bool                        mIsInitialized;
	PlayerLibSidplay*           mPlayer;
	AudioDeviceID               mDeviceID;
	AudioStreamBasicDescription mStreamFormat;
	AudioDeviceIOProcID         mEmulationPlaybackProcID;
	AudioDeviceIOProcID         mPreRenderedBufferPlaybackProcID;
	
	int                         mNumSamplesInBuffer;
	short*                      mSampleBuffer;

	bool                        mFastForward;

	bool                        mIsPlaying;
	float                       mScaleFactor;
	float                       mVolume;

	bool						mIsPlayingPreRenderedBuffer;
	short*						mPreRenderedBuffer;
	int							mPreRenderedBufferSampleCount;
	int							mPreRenderedBufferPlaybackPosition;
	float						mPreRenderedBufferVolume;
	float                       mPreRenderedBufferScaleFactor;
	
	bool						mBufferUnderrunDetected;
    int                         mBufferUnderrunCount;
	int                         mInstanceId;
    
    static const int            sBufferUnderrunLimit = 10;
};


#endif // _AUDIOCOREDRIVER_H_