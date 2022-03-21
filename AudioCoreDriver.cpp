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
#include "AudioCoreDriver.h"


static const float  sBitScaleFactor = 1.0f / 32768.0f;
static int          sInstanceCount = 0;

#define MIN(A,B)	((A) < (B) ? (A) : (B))


// ----------------------------------------------------------------------------
AudioCoreDriver::AudioCoreDriver()
// ----------------------------------------------------------------------------
{
	mIsInitialized = false;
	mInstanceId = sInstanceCount;
	sInstanceCount++;
}


// ----------------------------------------------------------------------------
AudioCoreDriver::~AudioCoreDriver()
// ----------------------------------------------------------------------------
{
	deinitialize();
	sInstanceCount--;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::initialize(PlayerLibSidplay* player, int sampleRate, int bitsPerSample)
// ----------------------------------------------------------------------------
{
	if (mInstanceId != 0)
		return;

	mPlayer = player;
	mNumSamplesInBuffer = 512;
	mIsPlaying = false;
	mIsPlayingPreRenderedBuffer = false;
	mBufferUnderrunDetected = false;
    mBufferUnderrunCount = 0;
	
	mPreRenderedBuffer = NULL;
	mPreRenderedBufferSampleCount = 0;
	mPreRenderedBufferPlaybackPosition = 0;
	
	if (!mIsInitialized)
	{
		UInt32 propertySize = sizeof(mDeviceID);
		if (AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice, &propertySize, &mDeviceID) != kAudioHardwareNoError)
			return;

		if (mDeviceID == kAudioDeviceUnknown)
			return;
		
		propertySize = sizeof(mStreamFormat);
		if (AudioDeviceGetProperty(mDeviceID, 0, false, kAudioDevicePropertyStreamFormat, &propertySize, &mStreamFormat) != kAudioHardwareNoError)
			return;

		if (AudioDeviceAddPropertyListener(mDeviceID, 0, false, kAudioDevicePropertyStreamFormat, streamFormatChanged, (void*) this) != kAudioHardwareNoError)
			return;

		if (AudioDeviceAddPropertyListener(mDeviceID, 0, false, kAudioDeviceProcessorOverload, overloadDetected, (void*) this) != kAudioHardwareNoError)
			return;

		if (AudioHardwareAddPropertyListener(kAudioHardwarePropertyDefaultOutputDevice, deviceChanged, (void*) this)  != kAudioHardwareNoError)
			return;
		
		mSampleBuffer = new short[mNumSamplesInBuffer];
		memset(mSampleBuffer, 0, sizeof(short) * mNumSamplesInBuffer);
	
		int bufferByteSize = mNumSamplesInBuffer * mStreamFormat.mChannelsPerFrame * sizeof(float);
		propertySize = sizeof(bufferByteSize);
		if (AudioDeviceSetProperty(mDeviceID, NULL, 0, false, kAudioDevicePropertyBufferSize, propertySize, &bufferByteSize) != kAudioHardwareNoError)
			return;

		mScaleFactor = sBitScaleFactor;
		mPreRenderedBufferScaleFactor = sBitScaleFactor;
		
		if (AudioDeviceCreateIOProcID(mDeviceID, emulationPlaybackProc, (void*) this, &mEmulationPlaybackProcID) != kAudioHardwareNoError)
		{
			delete[] mSampleBuffer;
			mSampleBuffer = NULL;
			return;
		}

		if (AudioDeviceCreateIOProcID(mDeviceID, preRenderedBufferPlaybackProc, (void*) this, &mPreRenderedBufferPlaybackProcID) != kAudioHardwareNoError)
		{
			delete[] mSampleBuffer;
			mSampleBuffer = NULL;
			return;
		}
	}
	
	mVolume = 1.0f;
	mIsInitialized = true;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::deinitialize()
// ----------------------------------------------------------------------------
{
	if (!mIsInitialized)
		return;
	
	stopPlayback();
	
	AudioDeviceDestroyIOProcID(mDeviceID, mEmulationPlaybackProcID);
	AudioDeviceDestroyIOProcID(mDeviceID, mPreRenderedBufferPlaybackProcID);
	
	AudioDeviceRemovePropertyListener(mDeviceID, 0, false, kAudioDevicePropertyStreamFormat, streamFormatChanged);
	AudioDeviceRemovePropertyListener(mDeviceID, 0, false, kAudioDeviceProcessorOverload, overloadDetected);
	AudioHardwareRemovePropertyListener(kAudioHardwarePropertyDefaultOutputDevice, deviceChanged);
	
	delete[] mSampleBuffer;
	mIsInitialized = false;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::fillBuffer()
// ----------------------------------------------------------------------------
{
	if (!mIsPlaying)
		return;
	
    mPlayer->fillBuffer(mSampleBuffer, mNumSamplesInBuffer * sizeof(short));
}


// ----------------------------------------------------------------------------
OSStatus AudioCoreDriver::emulationPlaybackProc(AudioDeviceID inDevice,
												const AudioTimeStamp *inNow,
												const AudioBufferList *inInputData,
												const AudioTimeStamp *inInputTime,
												AudioBufferList *outOutputData, 
												const AudioTimeStamp *inOutputTime,
												void *inClientData)
// ----------------------------------------------------------------------------
{
	AudioCoreDriver* driverInstance = reinterpret_cast<AudioCoreDriver*>(inClientData);

	register float* outBuffer	= (float*) outOutputData->mBuffers[0].mData;
	register short* audioBuffer = (short*) driverInstance->getSampleBuffer();
	register short* bufferEnd	= audioBuffer + driverInstance->getNumSamplesInBuffer();
	register float scaleFactor  = driverInstance->getScaleFactor();

	driverInstance->fillBuffer();

    if (driverInstance->mStreamFormat.mChannelsPerFrame == 1)
    {
        while (audioBuffer < bufferEnd)
            *outBuffer++ = (*audioBuffer++) * scaleFactor;
    }
    else if (driverInstance->mStreamFormat.mChannelsPerFrame == 2)
    {
        register float sample = 0.0f;
        
        while (audioBuffer < bufferEnd)
        {
            sample = (*audioBuffer++) * scaleFactor;
            *outBuffer++ = sample;
            *outBuffer++ = sample;
        }
    }
	else
	{
        register float sample = 0.0f;
        
        while (audioBuffer < bufferEnd)
        {
            sample = (*audioBuffer++) * scaleFactor;
			for (int i = 0; i < driverInstance->mStreamFormat.mChannelsPerFrame; i++)
				*outBuffer++ = sample;
        }
	}
	
	return 0;
}


// ----------------------------------------------------------------------------
OSStatus AudioCoreDriver::preRenderedBufferPlaybackProc(AudioDeviceID inDevice,
														const AudioTimeStamp *inNow,
														const AudioBufferList *inInputData,
														const AudioTimeStamp *inInputTime,
														AudioBufferList *outOutputData, 
														const AudioTimeStamp *inOutputTime,
														void *inClientData)
// ----------------------------------------------------------------------------
{
	AudioCoreDriver* driverInstance = reinterpret_cast<AudioCoreDriver*>(inClientData);
	
	register int samplesLeft = driverInstance->mPreRenderedBufferSampleCount - driverInstance->mPreRenderedBufferPlaybackPosition;
	if (samplesLeft <= 0)
		driverInstance->stopPreRenderedBufferPlayback();
	
	register int samplesToPlayThisSlice = MIN(samplesLeft, driverInstance->getNumSamplesInBuffer());
	register float* outBuffer	= (float*) outOutputData->mBuffers[0].mData;
	register short* audioBuffer = (short*) &driverInstance->mPreRenderedBuffer[driverInstance->mPreRenderedBufferPlaybackPosition];
	register short* bufferEnd	= audioBuffer + samplesToPlayThisSlice;
	register float scaleFactor  = driverInstance->getPreRenderedBufferScaleFactor();
	
	driverInstance->mPreRenderedBufferPlaybackPosition += samplesToPlayThisSlice;
	
	if (driverInstance->mStreamFormat.mChannelsPerFrame == 1)
    {
        while (audioBuffer < bufferEnd)
            *outBuffer++ = (*audioBuffer++) * scaleFactor;
    }
    else if (driverInstance->mStreamFormat.mChannelsPerFrame == 2)
    {
        register float sample = 0.0f;
        
        while (audioBuffer < bufferEnd)
        {
            sample = (*audioBuffer++) * scaleFactor;
            *outBuffer++ = sample;
            *outBuffer++ = sample;
        }
    }
	else
	{
        register float sample = 0.0f;
        
        while (audioBuffer < bufferEnd)
        {
            sample = (*audioBuffer++) * scaleFactor;
			for (int i = 0; i < driverInstance->mStreamFormat.mChannelsPerFrame; i++)
				*outBuffer++ = sample;
        }
	}
	 
	return 0;
}


// ----------------------------------------------------------------------------
OSStatus AudioCoreDriver::deviceChanged(AudioHardwarePropertyID inPropertyID,
										void* inClientData)
// ----------------------------------------------------------------------------
{
	if (inPropertyID == kAudioHardwarePropertyDefaultOutputDevice)
	{
		AudioCoreDriver* driverInstance = reinterpret_cast<AudioCoreDriver*>(inClientData);
		
		bool wasPlaying = driverInstance->mIsPlaying;
		Float64 oldSampleRate = driverInstance->mStreamFormat.mSampleRate;
		
		driverInstance->deinitialize();
		driverInstance->initialize(driverInstance->mPlayer);
		
		if (driverInstance->mStreamFormat.mSampleRate != oldSampleRate)
			driverInstance->mPlayer->updateSampleRate(driverInstance->mStreamFormat.mSampleRate);

		if (wasPlaying)
			driverInstance->startPlayback();
	}
	
	return kAudioHardwareNoError;
}


// ----------------------------------------------------------------------------
OSStatus AudioCoreDriver::streamFormatChanged(AudioDeviceID inDevice,
											  UInt32 inChannel,
											  Boolean isInput,
											  AudioDevicePropertyID inPropertyID,
											  void* inClientData)
// ----------------------------------------------------------------------------
{
	AudioCoreDriver* driverInstance = reinterpret_cast<AudioCoreDriver*>(inClientData);
	UInt32 propertySize = sizeof(driverInstance->mStreamFormat);

	if (AudioDeviceGetProperty(inDevice, inChannel, isInput, inPropertyID, &propertySize, &driverInstance->mStreamFormat) != kAudioHardwareNoError)
		return kAudioHardwareNoError;

	if (driverInstance->mStreamFormat.mFormatID != kAudioFormatLinearPCM)
		return kAudioHardwareNoError;

	if (driverInstance->mPlayer)
		driverInstance->mPlayer->updateSampleRate(driverInstance->mStreamFormat.mSampleRate);
	
	return kAudioHardwareNoError;
}


// ----------------------------------------------------------------------------
OSStatus AudioCoreDriver::overloadDetected(AudioDeviceID inDevice,
										   UInt32 inChannel,
										   Boolean isInput,
										   AudioDevicePropertyID inPropertyID,
										   void* inClientData)
// ----------------------------------------------------------------------------
{
	if (inPropertyID == kAudioDeviceProcessorOverload)
	{
		AudioCoreDriver* driverInstance = reinterpret_cast<AudioCoreDriver*>(inClientData);
        
        driverInstance->mBufferUnderrunCount++;
        
        if (driverInstance->mBufferUnderrunCount > sBufferUnderrunLimit)
            driverInstance->setBufferUnderrunDetected(true);
	}
	
	return kAudioHardwareNoError;
}


// ----------------------------------------------------------------------------
bool AudioCoreDriver::startPlayback()
// ----------------------------------------------------------------------------
{
	if (mInstanceId != 0)
		return false;

	if (!mIsInitialized)
		return false;
		
	stopPreRenderedBufferPlayback();
	
	mIsPlaying = true;
	
	memset(mSampleBuffer, 0, sizeof(short) * mNumSamplesInBuffer);
	AudioDeviceStart(mDeviceID, mEmulationPlaybackProcID);

	return true;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::stopPlayback()
// ----------------------------------------------------------------------------
{
	if (!mIsInitialized)
		return;

	AudioDeviceStop(mDeviceID, mEmulationPlaybackProcID);

	mIsPlaying = false;
}


// ----------------------------------------------------------------------------
bool AudioCoreDriver::startPreRenderedBufferPlayback()
// ----------------------------------------------------------------------------
{
	if (mInstanceId != 0)
		return false;
	
	if (!mIsInitialized)
		return false;
	
	stopPlayback();

	mIsPlayingPreRenderedBuffer = true;
	
	memset(mSampleBuffer, 0, sizeof(short) * mNumSamplesInBuffer);
	AudioDeviceStart(mDeviceID, mPreRenderedBufferPlaybackProcID);
	
	return true;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::stopPreRenderedBufferPlayback()
// ----------------------------------------------------------------------------
{
	if (!mIsInitialized)
		return;
	
	AudioDeviceStop(mDeviceID, mPreRenderedBufferPlaybackProcID);
	
	mIsPlayingPreRenderedBuffer = false;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::setPreRenderedBuffer(short* inBuffer, int inBufferLength)
// ----------------------------------------------------------------------------
{
	mPreRenderedBuffer = inBuffer;
	mPreRenderedBufferSampleCount = inBufferLength;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::setVolume(float volume)
// ----------------------------------------------------------------------------
{
	mVolume = volume;
	mScaleFactor = sBitScaleFactor * volume;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::setPreRenderedBufferVolume(float volume)
// ----------------------------------------------------------------------------
{
	mPreRenderedBufferVolume = volume;
	mPreRenderedBufferScaleFactor = sBitScaleFactor * volume;
}

