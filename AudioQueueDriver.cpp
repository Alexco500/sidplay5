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
#include "PlayerLibSidplay.h"
#include "AudioQueueDriver.h"


// ----------------------------------------------------------------------------
AudioQueueDriver::AudioQueueDriver()
// ----------------------------------------------------------------------------
{
	mIsInitialized = false;
}


// ----------------------------------------------------------------------------
AudioQueueDriver::~AudioQueueDriver()
// ----------------------------------------------------------------------------
{
	stopPlayback();

	AudioQueueDispose(mAudioQueue, true);
	
	delete[] mSampleBuffer;
	mIsInitialized = false;
}


// ----------------------------------------------------------------------------
void AudioQueueDriver::initialize(PlayerLibSidplay* player, int sampleRate, int bitsPerSample)
// ----------------------------------------------------------------------------
{
	//printf("init core audio\n");

	mPlayer = player;
	mSampleRate = sampleRate;

	if (!mIsInitialized)
	{
		// Set up our audio format -- signed interleaved shorts (-32767 -> 32767), 16 bit stereo
		// The iphone does not want to play back float32s.
		mStreamFormat.mSampleRate = sampleRate;
		mStreamFormat.mFormatID = kAudioFormatLinearPCM;
		mStreamFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsBigEndian;
		mStreamFormat.mBytesPerPacket = 2 * sizeof(short);
		mStreamFormat.mFramesPerPacket = 1; // this means each packet in the AQ has two samples, one for each channel -> 4 bytes/frame/packet
		mStreamFormat.mBytesPerFrame = 2 * sizeof(short);
		mStreamFormat.mChannelsPerFrame = 2;
		mStreamFormat.mBitsPerChannel = 16;
		
		// Set up the output buffer callback on the current run loop
		OSStatus err = AudioQueueNewOutput(&mStreamFormat, streamCallback, (void*) this, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &mAudioQueue);
		if(err) fprintf(stderr, "AudioQueueNewOutput err %d\n", err);
		
		// Set the size and packet count of each buffer read. (e.g. "frameCount")
		mAudioFrameCount = 512;
		
		// Byte size is 2*frames (see above)
		UInt32 bufferBytes = mAudioFrameCount * mStreamFormat.mBytesPerFrame;

		mSampleBuffer = new short[mAudioFrameCount * 2];
			
		// alloc 3 buffers.
		for (int i = 0; i < BUFFER_COUNT; i++)
		{
			err = AudioQueueAllocateBuffer(mAudioQueue, bufferBytes, &mSampleBuffers[i]);
			if(err) fprintf(stderr, "AudioQueueAllocateBuffer [%d] err %d\n",i, err);
			
			// "Prime" by calling the callback once per buffer
			streamCallback((void*) this, mAudioQueue, mSampleBuffers[i]);
		}	
		
		// set the volume of the queue -- note that the volume knobs on the ipod / celestial also change this
		err = AudioQueueSetParameter(mAudioQueue, kAudioQueueParam_Volume, 1.0f);
		if(err) fprintf(stderr, "AudioQueueSetParameter err %d\n", err);
	}

	//printf("init: OK\n");		
	
	mVolume = 1.0f;
	
	mIsInitialized = true;
}


// ----------------------------------------------------------------------------
void AudioQueueDriver::fillBuffer(short* buffer, int length)
// ----------------------------------------------------------------------------
{
	if (!mIsPlaying)
	{
		return;
	}
	
	mPlayer->fillBuffer(buffer, length);
}


// ----------------------------------------------------------------------------
void AudioQueueDriver::streamCallback(void *in, AudioQueueRef inQ, AudioQueueBufferRef outQB)
// ----------------------------------------------------------------------------
{
	UInt32 err;

	// Get the info struct and a pointer to our output data
	AudioQueueDriver* driverInstance = reinterpret_cast<AudioQueueDriver*>(in);
	register short* audioBuffer = (short*) outQB->mAudioData;

	// if we're being asked to render
	if (driverInstance->mAudioFrameCount > 0)
	{
		outQB->mAudioDataByteSize = 2 * sizeof(short) * driverInstance->mAudioFrameCount;
		driverInstance->fillBuffer(driverInstance->mSampleBuffer, sizeof(short) * driverInstance->mAudioFrameCount);
		
		register int samplesToCopy = driverInstance->mAudioFrameCount; 
		register short* sampleBuffer = driverInstance->mSampleBuffer;
		
        for(int i = 0; i < samplesToCopy; i++)
		{
			*audioBuffer++ = *sampleBuffer;
			*audioBuffer++ = *sampleBuffer++;
        }

		// "Enqueue" the buffer
		AudioQueueEnqueueBuffer(inQ, outQB, 0, NULL);
	}
	else
	{
		err = AudioQueueStop(driverInstance->mAudioQueue, false);
	}
}


// ----------------------------------------------------------------------------
bool AudioQueueDriver::startPlayback()
// ----------------------------------------------------------------------------
{
	//printf("trying to start playback\n");

	if (!mIsInitialized)
		return false;
		
	if (mIsPlaying)
		stopPlayback();
		
	mIsPlaying = true;

	//printf("starting playback\n");
	
	for (int i = 0; i < BUFFER_COUNT; i++)
	{
		// "Prime" by calling the callback once per buffer
		streamCallback((void*) this, mAudioQueue, mSampleBuffers[i]);
	}	

	OSStatus err = AudioQueueStart(mAudioQueue, NULL);
	if(err) fprintf(stderr, "AudioQueueStart err %d\n", err);

	return true;
}


// ----------------------------------------------------------------------------
void AudioQueueDriver::stopPlayback()
// ----------------------------------------------------------------------------
{
	if (!mIsInitialized)
		return;

	if (!mIsPlaying)
		return;

	//printf("stopping playback\n");

	AudioQueueFlush(mAudioQueue);

	//printf("flushed queue\n");
	
	//AudioQueueStop(mAudioQueue, true);
	AudioQueuePause(mAudioQueue);

	mIsPlaying = false;
}



// ----------------------------------------------------------------------------
void AudioQueueDriver::setVolume(float volume)
// ----------------------------------------------------------------------------
{
	mVolume = volume;
	AudioQueueSetParameter(mAudioQueue, kAudioQueueParam_Volume, volume);
}

