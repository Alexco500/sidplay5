/*
 *
 * Copyright (c) 2005, Andreas Varga <sid@galway.c64.org>
 * All rights reserved.
 *
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <Carbon/Carbon.h>
#include "PlayerLibSidplay.h"
#include "AudioSoundManager.h"


// ----------------------------------------------------------------------------
AudioSoundManager::AudioSoundManager()
// ----------------------------------------------------------------------------
{
	mIsInitialized = false;
}


// ----------------------------------------------------------------------------
AudioSoundManager::~AudioSoundManager()
// ----------------------------------------------------------------------------
{
	stopPlayback();

	SndDisposeChannel(mChannel, true);

	delete[] mSampleBuffer1;
	delete[] mSampleBuffer2;
}


// ----------------------------------------------------------------------------
void AudioSoundManager::initialize(PlayerLibSidplay* player, int sampleRate, int bitsPerSample)
// ----------------------------------------------------------------------------
{
	mPlayer = player;
	mSampleRate = sampleRate;
	mSampleBufferSize = 512;

	if (!mIsInitialized)
	{
		mChannel = NULL;
		SndNewChannel(&mChannel, sampledSynth, initMono, NewSndCallBackUPP(AudioSoundManager::streamCallback));
		mChannel->userInfo = reinterpret_cast<long>(this);

		mSampleBuffer1 = new short[ mSampleBufferSize ];
		mSampleBuffer2 = new short[ mSampleBufferSize ];
	}
	
	mSoundHeader.numChannels 		= 1;
	mSoundHeader.sampleRate  		= mSampleRate << 16L;
	mSoundHeader.sampleSize  		= bitsPerSample;
	mSoundHeader.numFrames   		= mSampleBufferSize;

	mSoundHeader.encode 			= extSH;
	mSoundHeader.baseFrequency 		= kMiddleC;
	mSoundHeader.markerChunk 		= NULL;
	mSoundHeader.loopStart 			= 0;
	mSoundHeader.loopEnd 			= mSampleBufferSize;

	mSoundHeader.samplePtr   		= (Ptr) mSampleBuffer1;
	
	mVolume = 1.0f;
	mFastForward = false;
	
	mIsFilling = false;
	mIsInitialized = true;
}


// ----------------------------------------------------------------------------
void AudioSoundManager::fillBuffer(SndChannelPtr channel)
// ----------------------------------------------------------------------------
{
	if (!mIsPlaying)
	{
		return;
	}
	
	SndCommand cmd;
	
	cmd.cmd = bufferCmd;
	cmd.param1 = 0;
	cmd.param2 = (long) &mSoundHeader;
	SndDoImmediate(channel, &cmd);

	// come back to this function when the buffer is played
	cmd.cmd = callBackCmd;
	cmd.param1 = 0;
	cmd.param2 = 0;
	SndDoCommand(channel, &cmd, TRUE);

	short* current_buffer = (short*) mSoundHeader.samplePtr;

	// toggle buffers
	if (current_buffer == mSampleBuffer1) {
	
		mSoundHeader.samplePtr = (Ptr) mSampleBuffer2;
		
	} else if (current_buffer == mSampleBuffer2) {
	
		mSoundHeader.samplePtr = (Ptr) mSampleBuffer1;
	}
	
	current_buffer = (short*) mSoundHeader.samplePtr;

	mPlayer->fillBuffer(current_buffer, mSampleBufferSize * 2);
	
	//for (int i = 0; i < mSampleBufferSize; i++)
	//	current_buffer[i] = rand() & 0xffff;
}


// ----------------------------------------------------------------------------
void AudioSoundManager::streamCallback(SndChannelPtr channel, SndCommand* passedcmd)
// ----------------------------------------------------------------------------
{
	AudioSoundManager* channelInstance = reinterpret_cast<AudioSoundManager*>(channel->userInfo);

	if (channelInstance == NULL)
	{
		return;
	}

	if (channelInstance->getIsFilling())
	{
		return;
	}

	channelInstance->setIsFilling(true);
	channelInstance->fillBuffer(channel);
	channelInstance->setIsFilling(false);
}


// ----------------------------------------------------------------------------
bool AudioSoundManager::startPlayback()
// ----------------------------------------------------------------------------
{
	mIsPlaying = true;
	
	fillBuffer(mChannel);
	
	SndCommand cmd;
	
	cmd.cmd = bufferCmd;
	cmd.param1 = 0;
	cmd.param2 = (long) &mSoundHeader;
	SndDoImmediate(mChannel, &cmd);

	cmd.cmd = callBackCmd;
	cmd.param1 = 0;
	cmd.param2 = 0;
	SndDoCommand(mChannel, &cmd, TRUE);

	// pre-toggle buffers
	mSoundHeader.samplePtr = (Ptr) mSampleBuffer2;

	return true;
}


// ----------------------------------------------------------------------------
void AudioSoundManager::stopPlayback()
// ----------------------------------------------------------------------------
{
	SndCommand cmd;

	cmd.cmd = quietCmd;
	cmd.param1 = 0;
	cmd.param2 = 0;
	SndDoImmediate(mChannel, &cmd);

	cmd.cmd = flushCmd;
	SndDoImmediate(mChannel, &cmd);
	
	mIsPlaying = false;
}



// ----------------------------------------------------------------------------
void AudioSoundManager::setVolume(float volume)
// ----------------------------------------------------------------------------
{
	mVolume = volume;
	int soundManagerVolume = static_cast<int>(volume * static_cast<float>(0x0100));
	
	SndCommand cmd;
	cmd.cmd = volumeCmd;
	cmd.param1 = 0;
	cmd.param2 = (soundManagerVolume << 16) + soundManagerVolume;
	SndDoImmediate(mChannel, &cmd);
}


// ----------------------------------------------------------------------------
void AudioSoundManager::setFastForward(bool fastForward)
// ----------------------------------------------------------------------------
{
	mFastForward = fastForward;
}



