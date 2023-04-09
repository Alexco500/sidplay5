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
#include "AudioCoreDriverNew.h"

// ----------------------------------------------------------------------------
AudioCoreDriverNew::AudioCoreDriverNew()
// ----------------------------------------------------------------------------
{
	mIsInitialized = false;
}


// ----------------------------------------------------------------------------
AudioCoreDriverNew::~AudioCoreDriverNew()
// ----------------------------------------------------------------------------
{
	stopPlayback();
    AudioUnitUninitialize (gOutputUnit);
    AudioComponentInstanceDispose (gOutputUnit);

	delete[] mSampleBuffer;
	mIsInitialized = false;
}


// ----------------------------------------------------------------------------
void AudioCoreDriverNew::initialize(PlayerLibSidplay* player, int sampleRate, int bitsPerSample)
// ----------------------------------------------------------------------------
{
	//printf("init core audio\n");

	mPlayer = player;
	mSampleRate = 44100; //sampleRate
    pointerInPacket = 0;
    bufferInUse = 0;
    mNumSamplesInBuffer = 512;
    mIsPlaying = false;
    mIsPlayingPreRenderedBuffer = false;
    mBufferUnderrunDetected = false;
    mBufferUnderrunCount = 0;
    
    mPreRenderedBuffer = NULL;
    mPreRenderedBufferSampleCount = 0;
    mPreRenderedBufferPlaybackPosition = 0;
    mSizeOfAudioBuffer = mNumSamplesInBuffer * sizeof(short);
    
	if (!mIsInitialized)
	{
		// Set up our audio format -- signed interleaved shorts (-32767 -> 32767), 16 bit stereo
		// The iphone does not want to play back float32s.
        
		// set up audio unit description
        mDesc.componentType = kAudioUnitType_Output;
        mDesc.componentSubType = kAudioUnitSubType_DefaultOutput;
        mDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        mDesc.componentFlags = 0;
        mDesc.componentFlagsMask = 0;
        // get next component
        AudioComponent comp = AudioComponentFindNext(NULL, &mDesc);
        if (comp == NULL) { printf ("No audio component found.\n"); return; }

        OSStatus err = AudioComponentInstanceNew(comp, &gOutputUnit);
        if (err) { printf (" open component failed %d\n", (int)err); return;}

        // Set up a callback function to generate output to the output unit
        AURenderCallbackStruct input;
        input.inputProc = MyRenderer;
        input.inputProcRefCon = (void*)this;
        
        err = AudioUnitSetProperty (gOutputUnit,
                                    kAudioUnitProperty_SetRenderCallback,
                                    kAudioUnitScope_Input,
                                    0,
                                    &input,
                                    sizeof(input));
        if (err) { printf ("AudioUnitSetProperty-CB=%ld\n", (long int)err); return; }
        
        UInt32 streamDescSize = sizeof( mStreamFormat );
        
        err = AudioUnitGetProperty( gOutputUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Global,
                                  0,
                                  &mStreamFormat,
                                   &streamDescSize);
        if (err) { printf ("AudioUnitGetProperty-CB=%ld\n", (long int)err); return; }

        mStreamFormat.mSampleRate = 44100;
        mStreamFormat.mFormatID = kAudioFormatLinearPCM;
        mStreamFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger |          kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;
        mStreamFormat.mBytesPerPacket = 4; //2 * sizeof(short);
        mStreamFormat.mFramesPerPacket = 1; // this means each packet in the AQ has two samples, one for each channel -> 4 bytes/frame/packet
        mStreamFormat.mBytesPerFrame = 4; //2 * sizeof(short);
        mStreamFormat.mChannelsPerFrame = 2;
        mStreamFormat.mBitsPerChannel = 16;

        numberOfChannelsPerFrame = mStreamFormat.mChannelsPerFrame;
        err = AudioUnitSetProperty (gOutputUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    0,
                                    &mStreamFormat,
                                    sizeof(AudioStreamBasicDescription));
        if (err) { printf ("AudioUnitSetProperty-SF=%4.4s, %ld\n", (char*)&err, (long int)err); return; }
        
        // Initialize unit
        err = AudioUnitInitialize(gOutputUnit);
        if (err) { printf ("AudioUnitInitialize=%ld\n", (long int)err); return; }

        mSampleBuffer = new short[mNumSamplesInBuffer];
        memset(mSampleBuffer, 0, sizeof(short) * mNumSamplesInBuffer);
        int bufferByteSize = mNumSamplesInBuffer * mStreamFormat.mChannelsPerFrame * sizeof(float);
	}

	//printf("init: OK\n");		
	
	mVolume = 1.0f;
	mIsInitialized = true;
}


// ----------------------------------------------------------------------------
void AudioCoreDriverNew::fillBuffer()
// ----------------------------------------------------------------------------
{
	if (!mIsPlaying)
	{
		return;
	}
    mPlayer->fillBuffer(mSampleBuffer, mSizeOfAudioBuffer);}

// ________________________________________________________________________________
//
// Audio Unit Renderer!!!
//
OSStatus    AudioCoreDriverNew::MyRenderer(void                 *inRefCon,
                       AudioUnitRenderActionFlags     *ioActionFlags,
                       const AudioTimeStamp         *inTimeStamp,
                       UInt32                         inBusNumber,
                       UInt32                         inNumberFrames,
                       AudioBufferList             *ioData)

{
    // Get the info struct and a pointer to our output data
    AudioCoreDriverNew* driverInstance = reinterpret_cast<AudioCoreDriverNew*>(inRefCon);
    short* outBuffer    = (short*) ioData->mBuffers[0].mData;
    short* audioBuffer = (short*) driverInstance->getSampleBuffer();
    short* bufferEnd    = audioBuffer + driverInstance->getNumSamplesInBuffer();
    float scaleFactor  = driverInstance->getScaleFactor();
    int bytesInCoreAudioBuffer = ioData->mBuffers[0].mDataByteSize;
    UInt32 remainingBuffer;
    float sample = 0.0f;
    //CoreAdioBuffer expects 2 channels with 16-bit signed ints.
    //so we have to divide size by 2 before we compare with our internal buffer size
    bytesInCoreAudioBuffer = bytesInCoreAudioBuffer/2;
    remainingBuffer = (driverInstance->mSizeOfAudioBuffer - driverInstance->pointerInPacket);
    // point to the start of unused buffer
    short* copyBuffer = audioBuffer + (driverInstance->pointerInPacket/sizeof(short));

    if ( remainingBuffer > bytesInCoreAudioBuffer)
    {
        // buffer has enough unsend samples
        // copy shorts into buffer inteleaved, libsid gives us a
        // mono sound buffer
        for (int i=0;i<bytesInCoreAudioBuffer;i=i+2) {
            sample = (*copyBuffer++) * driverInstance->mVolume;
            *outBuffer++ = (short)sample; // left
            *outBuffer++ = (short)sample; // right
        }
        driverInstance->pointerInPacket += bytesInCoreAudioBuffer;
        return noErr;
    }
    if ( remainingBuffer < bytesInCoreAudioBuffer)
    {
        // buffer has only rest of unsend samples
        // first part
        // copy shorts into buffer inteleaved, libsid gives us a
        // mono sound buffer
        for (int i=0;i<remainingBuffer;i=i+2) {
            sample = (*copyBuffer++) * driverInstance->mVolume;
            *outBuffer++ = (short)sample; // left
            *outBuffer++ = (short)sample; // right
        }
        // second part, get new buffer
        driverInstance->fillBuffer();
        // reset buffer pointer
        copyBuffer = audioBuffer;
        for (int i=0;i<(bytesInCoreAudioBuffer-remainingBuffer);i=i+2) {
            sample = (*copyBuffer++) * driverInstance->mVolume;
            *outBuffer++ = (short)sample; // left
            *outBuffer++ = (short)sample; // right
        }
        driverInstance->pointerInPacket = (bytesInCoreAudioBuffer-remainingBuffer);
        return noErr;
    }

    if ( (remainingBuffer = bytesInCoreAudioBuffer))
    {
        // copy shorts into buffer inteleaved, libsid gives us a
        // mono sound buffer
        for (int i=0;i<bytesInCoreAudioBuffer;i=i+2) {
            sample = (*copyBuffer++) * driverInstance->mVolume;
            *outBuffer++ = (short)sample; // left
            *outBuffer++ = (short)sample; // right
        }
        driverInstance->fillBuffer();
        driverInstance->pointerInPacket = 0;
        return noErr;
    }
    
/*
    if (driverInstance->mStreamFormat.mChannelsPerFrame == 1)
    {
        while (audioBuffer < bufferEnd)
            *outBuffer++ = (*audioBuffer++) * scaleFactor;
    }
    else if (driverInstance->mStreamFormat.mChannelsPerFrame == 2)
    {
        register float sample =0;
        
        while (audioBuffer < bufferEnd)
        {
            sample = (*audioBuffer++) * driverInstance->mVolume;
            *outBuffer++ = (short)sample;
            *outBuffer++ = (short)sample;
            printf("tada: %f\n", sample);
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
 */
    return noErr;
}


// ----------------------------------------------------------------------------
bool AudioCoreDriverNew::startPlayback()
// ----------------------------------------------------------------------------
{
	//printf("trying to start playback\n");

	if (!mIsInitialized)
		return false;
		
	if (mIsPlaying)
		stopPlayback();
		
	mIsPlaying = true;

    // Start the rendering
    // The DefaultOutputUnit will do any format conversions to the format of the default device
    OSStatus err = AudioOutputUnitStart (gOutputUnit);
    if (err) { printf ("AudioOutputUnitStart=%ld\n", (long int)err); return false; }
    memset(mSampleBuffer, 0, sizeof(short) * mNumSamplesInBuffer);

	return true;
}


// ----------------------------------------------------------------------------
void AudioCoreDriverNew::stopPlayback()
// ----------------------------------------------------------------------------
{
    if (!mIsInitialized)
        return;
    
    if (!mIsPlaying)
        return;
    
    // REALLY after you're finished playing STOP THE AUDIO OUTPUT UNIT!!!!!!
    // but we never get here because we're running until the process is nuked...
    OSStatus err = AudioOutputUnitStop (gOutputUnit);
    if (err) { printf ("AudioOutputUnitStop=%ld\n", (long int)err); return; }
    
    
    mIsPlaying = false;
    
}
// ----------------------------------------------------------------------------
void AudioCoreDriverNew::setVolume(float volume)
// ----------------------------------------------------------------------------
{
    mVolume = volume;
}
