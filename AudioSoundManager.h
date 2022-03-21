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

#ifndef _AUDIOSOUNDMANAGER_H_
#define _AUDIOSOUNDMANAGER_H_

#include <Carbon/Carbon.h>


class PlayerLibSidplay;


class AudioSoundManager : public AudioDriver
{
public:

	AudioSoundManager();
	~AudioSoundManager();

	void initialize(PlayerLibSidplay* player, int sampleRate = 44100, int bitsPerSample = 16);

	bool startPlayback();
	void stopPlayback();
	void setVolume(float volume);
	void setFastForward(bool fastForward);
	
	inline int getSampleRate() { return mSampleRate; }
	inline short* getSampleBuffer() { return (short*) mSoundHeader.samplePtr; }
	inline bool getIsPlaying() { return mIsPlaying; }
	inline bool getIsFilling() { return mIsFilling; }
	inline void setIsFilling(bool flag) { mIsFilling = flag; }
	inline bool getIsInitialized() { return mIsInitialized; }
	
private:

	void fillBuffer(SndChannelPtr channel);

	static void streamCallback(SndChannelPtr channel, SndCommand* passedcmd);
	
	bool				mIsInitialized;
	PlayerLibSidplay*	mPlayer;
	SndChannelPtr		mChannel;
	ExtSoundHeader		mSoundHeader;
	SndCommand			mSoundCommand;
	int					mSampleRate;
	int					mSampleBufferSize;
	
	short*				mSampleBuffer1;
	short*				mSampleBuffer2;

	bool				mFastForward;
	float				mVolume;
	float				mAudioLevel;
	bool				mIsPlaying;
	bool				mIsFilling;
};


#endif // _AUDIOSOUNDMANAGER_H_