/*
 *
 * Copyright (c) 2023 Alexander Coers
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
    mIsPlaying = false;
    mIsPlayingPreRenderedBuffer = false;
    mBufferUnderrunDetected = false;
    mBufferUnderrunCount = 0;
    mPreRenderedBuffer = NULL;
    mPreRenderedBufferSampleCount = 0;
    mPreRenderedBufferPlaybackPosition = 0;

    mSampleRate = DEFAULT_SAMPLERATE; //sampleRate
    mNumSamplesInAudioBuffer = 512;
    numberOfBytesInAudioBuffer = mNumSamplesInAudioBuffer * sizeof(short);
    
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

        mStreamFormat.mSampleRate = DEFAULT_SAMPLERATE;
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
        
        
        err = AudioUnitAddPropertyListener (gOutputUnit,
                                    kAudioUnitProperty_LastRenderError,
                                    AUPropertyListener,
                                            this);
        if (err) { printf ("AudioUnitAddPropertyListener-CB=%ld\n", (long int)err); return; }
        
        // Initialize unit
        err = AudioUnitInitialize(gOutputUnit);
        if (err) { printf ("AudioUnitInitialize=%ld\n", (long int)err); return; }

        // alloc sample buffer
        mSampleBuffer = new short[mNumSamplesInAudioBuffer];
        memset(mSampleBuffer, 0, numberOfBytesInAudioBuffer);
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
    mPlayer->fillBuffer(mSampleBuffer, numberOfBytesInAudioBuffer);
    // reset value to full buffer
    numberOfSamplesInAudioBuffer = mNumSamplesInAudioBuffer;
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
    //memset(mSampleBuffer, 0, sizeof(short) * mNumSamplesInBuffer);
    fillBuffer();
    // Start the rendering
    // The DefaultOutputUnit will do any format conversions to the format of the default device
    OSStatus err = AudioOutputUnitStart (gOutputUnit);
    if (err) { printf ("AudioOutputUnitStart=%ld\n", (long int)err); return false; }

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

#pragma mark Core Audio functions
// ________________________________________________________________________________
//
// Audio Unit Disconnect Handler
//
void AudioCoreDriverNew::AUPropertyListener(void *inRefCon,
                                                AudioUnit inUnit,
                                                AudioUnitPropertyID inID,
                                                AudioUnitScope inScope,
                                                AudioUnitElement inElement)
{
  
  return;
}

// ________________________________________________________________________________
//
// Audio Unit Renderer!!!
//
OSStatus    AudioCoreDriverNew::MyRenderer(void     *inRefCon,
                       AudioUnitRenderActionFlags   *ioActionFlags,
                       const AudioTimeStamp         *inTimeStamp,
                       UInt32                        inBusNumber,
                       UInt32                        inNumberFrames,
                       AudioBufferList              *ioData)

{
    // Get the info struct and a pointer to our output data
    AudioCoreDriverNew* driverInstance = reinterpret_cast<AudioCoreDriverNew*>(inRefCon);
    short* outAudioBuffer = (short*) ioData->mBuffers[0].mData;
    short* inAudioBuffer  = (short*) driverInstance->getSampleBuffer();
    unsigned int numberOfBytesOutAudioBuffer = ioData->mBuffers[0].mDataByteSize;
    float sample = 0.0f;

    // available samples in outBuffer
    // need to divide by 2, since we have left/right channel
    unsigned int numberOfSamplesOutAudioBuffer = numberOfBytesOutAudioBuffer / sizeof(short) /2;
    // set buffers...
    short *audioOut = outAudioBuffer;
    short *audioIn  = &inAudioBuffer[driverInstance->mNumSamplesInAudioBuffer-driverInstance->numberOfSamplesInAudioBuffer];
    // out buffer shall be organized like sample 0, sample 0, sample 1, sample 1
    // duplicating the samples (audio buffer, make stereo left/right out of mono
    // we always need to fill the entire outBuffer
    // case 1
    if (driverInstance->numberOfSamplesInAudioBuffer > numberOfSamplesOutAudioBuffer)
    {
        for (int x=0;x<numberOfSamplesOutAudioBuffer;x++) {
            sample = driverInstance->mVolume * (*audioIn++);
            *audioOut++ = (short)sample; // left
            *audioOut++ = (short)sample; // right
        }
        driverInstance->numberOfSamplesInAudioBuffer -= numberOfSamplesOutAudioBuffer;
       // NSLog(@"Case 1: copied %d samples (%d bytes)",numberOfSamplesOutAudioBuffer,numberOfBytesOutAudioBuffer);
    } else
    // case 2
    if (driverInstance->numberOfSamplesInAudioBuffer < numberOfSamplesOutAudioBuffer)
    {
        int numberOfSamplesToCopy = numberOfSamplesOutAudioBuffer;
        int tempSampleCopy = driverInstance->numberOfSamplesInAudioBuffer;
        while (numberOfSamplesToCopy >0 ) {
            for (int x=0;x<tempSampleCopy;x++) {
                sample = driverInstance->mVolume * (*audioIn++);
                *audioOut++ = (short)sample; // left
                *audioOut++ = (short)sample; // right
            }
            // entire in buffer was copied?
            if (tempSampleCopy == driverInstance->numberOfSamplesInAudioBuffer) {
                //fill buffer up with fresh samples
                driverInstance->fillBuffer();
                audioIn  = inAudioBuffer;
            } else
                driverInstance->numberOfSamplesInAudioBuffer -= tempSampleCopy;
            //NSLog(@"Case 2: copied %d samples.",tempSampleCopy);
 
            //numberOfBytesInAudioBuffer = sizeof(short) * numberOfSamplesInAudioBuffer;
            numberOfSamplesToCopy -= tempSampleCopy;
            if (numberOfSamplesToCopy >= driverInstance->numberOfSamplesInAudioBuffer)
                tempSampleCopy = driverInstance->numberOfSamplesInAudioBuffer;
            else
                tempSampleCopy = numberOfSamplesToCopy;
        }
    } else
    //case 3
    if (driverInstance->numberOfSamplesInAudioBuffer == numberOfSamplesOutAudioBuffer)
    {
        for (int x=0;x<numberOfSamplesOutAudioBuffer;x++) {
            sample = driverInstance->mVolume * (*audioIn++);
            *audioOut++ = (short)sample; // left
            *audioOut++ = (short)sample; // right
        }
        //fill buffer up with fresh samples
        driverInstance->fillBuffer();
        //audioIn  = inAudioBuffer;
        //NSLog(@"Case 3: copied %d samples (%d bytes)",numberOfSamplesOutAudioBuffer,numberOfBytesOutAudioBuffer);
    }


    return noErr;
}
