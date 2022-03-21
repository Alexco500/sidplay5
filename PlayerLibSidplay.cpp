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

// carbon headers
#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>

// module headers
#include "AudioDriver.h"

// local module header
#include "PlayerLibSidplay.h"


unsigned char sid_registers[ 0x19 ];

double mixer_value1 = 1.0;
double mixer_value2 = 1.0;
double mixer_value3 = 1.0;


const char*	PlayerLibSidplay::sChipModel6581 = "MOS 6581";
const char*	PlayerLibSidplay::sChipModel8580 = "MOS 8580";
const char*	PlayerLibSidplay::sChipModelUnknown = "Unknown";
const char*	PlayerLibSidplay::sChipModelUnspecified = "Unspecified";

const int sDefault8580PointCount = 31;
static const sid_fc_t sDefault8580[sDefault8580PointCount] =
{
	{ 0, 0        },
	{ 64, 400	  },
	{ 128, 800    },
	{ 192, 1200	  },
	{ 256, 1600   },
	{ 384, 2450	  },
	{ 512, 3300   },
	{ 576, 3700   },
	{ 640, 4100   },
	{ 704, 4450   },
	{ 768, 4800   },
	{ 832, 5200   },
	{ 896, 5600   },
	{ 960, 6050   },
	{ 1024, 6500  },
	{ 1088, 7000  },
	{ 1152, 7500  },
	{ 1216, 7950  },
	{ 1280, 8400  },
	{ 1344, 8800  },
	{ 1408, 9200  },
	{ 1472, 9500  },
	{ 1536, 9800  },
	{ 1600, 10150 },
	{ 1664, 10500 },
	{ 1728, 10750 },
	{ 1792, 11000 },
	{ 1856, 11350 },
	{ 1920, 11700 },
	{ 1984, 12100 },
	{ 2047, 12500 }
};



// ----------------------------------------------------------------------------
PlayerLibSidplay::PlayerLibSidplay() :
// ----------------------------------------------------------------------------
	mSidEmuEngine(NULL),
	mSidTune(NULL),
	mBuilder(NULL),
	mAudioDriver(NULL),
	mTuneLength(0),
	mCurrentSubtune(0),
	mSubtuneCount(0),
	mDefaultSubtune(0),
	mCurrentTempo(50),
	mPreviousOversamplingFactor(0),
	mOversamplingBuffer(NULL)
{

}


// ----------------------------------------------------------------------------
PlayerLibSidplay::~PlayerLibSidplay()
// ----------------------------------------------------------------------------
{
	if (mSidTune)
	{
		delete mSidTune;
		mSidTune = NULL;
	}
	
	if (mBuilder)
	{
		delete mBuilder;
		mBuilder = NULL;
	}
	
	if (mSidEmuEngine)
	{
		delete mSidEmuEngine;
		mSidEmuEngine = NULL;
	}
}


// ----------------------------------------------------------------------------
void PlayerLibSidplay::setAudioDriver(AudioDriver* audioDriver)
// ----------------------------------------------------------------------------
{
	mAudioDriver = audioDriver;
}


// ----------------------------------------------------------------------------
void PlayerLibSidplay::setupSIDInfo()
// ----------------------------------------------------------------------------
{
	if (mSidTune == NULL)
		return;
	
	mSidTune->getInfo(mTuneInfo);
	mCurrentSubtune = mTuneInfo.currentSong;
	mSubtuneCount = mTuneInfo.songs;
	mDefaultSubtune = mTuneInfo.startSong;
	
	if (getCurrentChipModel() == sChipModel8580)
	{
		mBuilder->filter((sid_filter_t*)NULL);
	}
	else
	{
		mFilterSettings.distortion_enable = true;
		mBuilder->filter(&mFilterSettings);
	}
}


// ----------------------------------------------------------------------------
void PlayerLibSidplay::initEmuEngine(PlaybackSettings *settings)
// ----------------------------------------------------------------------------
{
	if (mSidEmuEngine == NULL )
		mSidEmuEngine = new sidplay2;

	if (mBuilder == NULL)
		mBuilder = new ReSIDBuilder("resid");
	
	if (mAudioDriver)
		settings->mFrequency = mAudioDriver->getSampleRate();
		
	mPlaybackSettings = *settings;

	sid2_config_t cfg = mSidEmuEngine->config();
	
	if (mPlaybackSettings.mClockSpeed == 0)
	{
		cfg.clockSpeed    = SID2_CLOCK_PAL;
		cfg.clockDefault  = SID2_CLOCK_PAL;
	}
	else
	{
		cfg.clockSpeed    = SID2_CLOCK_NTSC;
		cfg.clockDefault  = SID2_CLOCK_NTSC;
	}

	cfg.clockForced   = true;
	
	cfg.environment   = sid2_envR;
	cfg.playback	  = sid2_mono;
	cfg.precision     = mPlaybackSettings.mBits;
	cfg.frequency	  = mPlaybackSettings.mFrequency * mPlaybackSettings.mOversampling;
	cfg.forceDualSids = false;
	cfg.emulateStereo = false;

	cfg.optimisation = SID2_DEFAULT_OPTIMISATION;
	
	switch (mPlaybackSettings.mOptimization)
	{
		case 0:
			cfg.optimisation  = 0;
			break;

		case 1:
			cfg.optimisation  = SID2_DEFAULT_OPTIMISATION;
			break;

		case 2:
			cfg.optimisation  = SID2_MAX_OPTIMISATION;
			break;			
	}

	if (mCurrentTempo > 70)
		cfg.optimisation  = SID2_MAX_OPTIMISATION;

	//printf("optimization: %d\n", cfg.optimisation);

	if (mPlaybackSettings.mSidModel == 0)
		cfg.sidDefault	  = SID2_MOS6581;
	else
		cfg.sidDefault	  = SID2_MOS8580;

	if (mPlaybackSettings.mForceSidModel)
		cfg.sidModel = cfg.sidDefault;

	cfg.sidEmulation  = mBuilder;
	cfg.sidSamples	  = true;
//	cfg.sampleFormat  = SID2_BIG_UNSIGNED;

	setFilterSettingsFromPlaybackSettings(mFilterSettings, settings);
	
	// setup resid
	if (mBuilder->devices(true) == 0)
		mBuilder->create(1);
		
	mBuilder->filter(true);
	mBuilder->filter(&mFilterSettings);
	mBuilder->sampling(cfg.frequency);
	
	int rc = mSidEmuEngine->config(cfg);
	if (rc != 0)
		printf("configure error: %s\n", mSidEmuEngine->error());

	mSidEmuEngine->setRegisterFrameChangedCallback(NULL, NULL);
}


// ----------------------------------------------------------------------------
void PlayerLibSidplay::updateSampleRate(int newSampleRate)
// ----------------------------------------------------------------------------
{
	if (mSidEmuEngine == NULL)
		return;
	
	mPlaybackSettings.mFrequency = newSampleRate;
	
	sid2_config_t cfg = mSidEmuEngine->config();
	cfg.frequency	  = mPlaybackSettings.mFrequency * mPlaybackSettings.mOversampling;

	mBuilder->sampling(cfg.frequency);

	mSidEmuEngine->config(cfg);
}


// ----------------------------------------------------------------------------
bool PlayerLibSidplay::initSIDTune(PlaybackSettings* settings)
// ----------------------------------------------------------------------------
{
	//printf("init sidtune\n");

	if (mSidTune != NULL)
	{
		delete mSidTune;
		mSidTune = NULL;
		mSidEmuEngine->load(NULL);
	}

	//printf("init emu engine\n");

	initEmuEngine(settings);

	mSidTune = new SidTune((uint_least8_t *) mTuneBuffer, mTuneLength);

    if (!mSidTune)
        return false;

	//printf("created sidtune instance: 0x%08x\n", (int) mSidTune);

	mSidTune->selectSong(mCurrentSubtune);

	//printf("loading sid tune data\n");

	int rc = mSidEmuEngine->load(mSidTune);

	if (rc == -1)
	{
		delete mSidTune;
		mSidTune = NULL;
		return false;
	}

	//printf("setting sid tune info\n");

	setupSIDInfo();

	return true;
}


// ----------------------------------------------------------------------------
bool PlayerLibSidplay::playTuneByPath(const char* filename, int subtune, PlaybackSettings* settings)
// ----------------------------------------------------------------------------
{
	//printf("loading file: %s\n", filename);
	
	mAudioDriver->stopPlayback();

	bool success = loadTuneByPath( filename, subtune, settings );

	//printf("load returned: %d\n", success);
	
	if (success)
		mAudioDriver->startPlayback();

	return success;
}


// ----------------------------------------------------------------------------
bool PlayerLibSidplay::playTuneFromBuffer(char* buffer, int length, int subtune, PlaybackSettings* settings)
// ----------------------------------------------------------------------------
{
	//printf( "buffer: 0x%08x, len: %d, subtune: %d\n", (int) buffer, length, subtune );
	//printf( "buffer: %c %c %c %c\n", buffer[0], buffer[1], buffer[2], buffer[3] );

	mAudioDriver->stopPlayback();

	bool success = loadTuneFromBuffer(buffer, length, subtune, settings);

	if (success)
		mAudioDriver->startPlayback();

	return success;
}


// ----------------------------------------------------------------------------
bool PlayerLibSidplay::loadTuneByPath(const char* filename, int subtune, PlaybackSettings* settings)
// ----------------------------------------------------------------------------
{
	FILE* fp = fopen(filename, "rb");
	
	if ( fp == NULL )
		return false;

	int length = fread(mTuneBuffer, 1, TUNE_BUFFER_SIZE, fp);
	
	if (length < 0)
		return false;

	//printf("file reading worked\n");

	fclose(fp);

	mTuneLength = length;
	mCurrentSubtune = subtune;

	return initSIDTune(settings);
}


// ----------------------------------------------------------------------------
bool PlayerLibSidplay::loadTuneFromBuffer(char* buffer, int length, int subtune, PlaybackSettings *settings)
// ----------------------------------------------------------------------------
{
	if (length < 0 || length > TUNE_BUFFER_SIZE)
		return false;

	if (buffer[0] != 'P' && buffer[0] != 'R')
		return false;
	
	if ( buffer[1] != 'S' ||
		buffer[2] != 'I' ||
		buffer[3] != 'D' )
	{
		return false;
	}
	
	mTuneLength = length;
	memcpy(mTuneBuffer, buffer, length);
	mCurrentSubtune = subtune;

	return initSIDTune(settings);
}


// ----------------------------------------------------------------------------
bool PlayerLibSidplay::startPrevSubtune()
// ----------------------------------------------------------------------------
{
	if (mCurrentSubtune > 1)
		mCurrentSubtune--;
	else
		return true;

	mAudioDriver->stopPlayback();

	initCurrentSubtune();
	
	mAudioDriver->startPlayback();

	return true;
}


// ----------------------------------------------------------------------------
bool PlayerLibSidplay::startNextSubtune()
// ----------------------------------------------------------------------------
{
	if (mCurrentSubtune < mSubtuneCount)
		mCurrentSubtune++;
	else
		return true;

	mAudioDriver->stopPlayback();

	initCurrentSubtune();
	
	mAudioDriver->startPlayback();

	return true;
}


// ----------------------------------------------------------------------------
bool PlayerLibSidplay::startSubtune( int which )
// ----------------------------------------------------------------------------
{
	if (which >= 1 && which <= mSubtuneCount)
		mCurrentSubtune = which;
	else
		return true;

	mAudioDriver->stopPlayback();

	initCurrentSubtune();
	
	mAudioDriver->startPlayback();

	return true;
}


// ----------------------------------------------------------------------------
bool PlayerLibSidplay::initCurrentSubtune()
// ----------------------------------------------------------------------------
{
	if (mSidTune == NULL)
		return false;

	if (mSidEmuEngine == NULL)
		return false;

	mSidTune->selectSong(mCurrentSubtune);
	mSidEmuEngine->load(mSidTune);
	
	return true;
}


// ----------------------------------------------------------------------------
void PlayerLibSidplay::setTempo(int tempo)
// ----------------------------------------------------------------------------
{
	if (mSidEmuEngine == NULL)
		return;

	// tempo is from 0..100, default is 50
	// 50 should yield a fastForward parameter of 100 (normal speed)
	// 0 should yield a fastForward parameter of 200 (half speed)
	// 100 should yield a fastForward parameter of 5 (20x speed)

	mCurrentTempo = tempo;

	tempo = 200 - tempo * 2;

	if (tempo < 5)
		tempo = 5;

	if (tempo < 50)
		mBuilder->overrideOptimisation(SID2_MAX_OPTIMISATION);
	else
		mBuilder->overrideOptimisation(mPlaybackSettings.mOptimization);

	mSidEmuEngine->fastForward( 10000 / tempo );
}


// ----------------------------------------------------------------------------
void PlayerLibSidplay::setVoiceVolume(int voice, float volume)
// ----------------------------------------------------------------------------
{
	switch (voice)
	{
		case 0:
			mixer_value1 = volume;
			break;
		case 1:
			mixer_value2 = volume;
			break;
		case 2:
			mixer_value3 = volume;
			break;
	}
}


// ----------------------------------------------------------------------------
void PlayerLibSidplay::setFilterSettings(sid_filter_t* filterSettings)
// ----------------------------------------------------------------------------
{
	mFilterSettings = *filterSettings;
	if (mBuilder)
		mBuilder->filter(&mFilterSettings);
}


// ----------------------------------------------------------------------------
int PlayerLibSidplay::getPlaybackSeconds()
// ----------------------------------------------------------------------------
{
	if (mSidEmuEngine == NULL)
		return 0;

	return(mSidEmuEngine->time() / 10);
}


// ----------------------------------------------------------------------------
void PlayerLibSidplay::fillBuffer(void* buffer, int len)
// ----------------------------------------------------------------------------
{
	if (mSidEmuEngine == NULL)
		return;

	if (mPlaybackSettings.mOversampling == 1)
		mSidEmuEngine->play(buffer, len);
	else
	{
		if (mPlaybackSettings.mOversampling != mPreviousOversamplingFactor)
		{
			delete[] mOversamplingBuffer;
			mOversamplingBuffer = new char[len * mPlaybackSettings.mOversampling];
			mPreviousOversamplingFactor = mPlaybackSettings.mOversampling;
		}
		
		// calculate n times as much sample data
		mSidEmuEngine->play(mOversamplingBuffer, len * mPlaybackSettings.mOversampling);

		short *oversampleBuffer = (short*) mOversamplingBuffer;
		short *outputBuffer = (short*) buffer;
		register long sample = 0;
		
		// downsample n:1 where n = oversampling factor
		for (int sampleCount = len / sizeof(short); sampleCount > 0; sampleCount--)
		{
			// calc arithmetic average (should rather be median?)
			sample = 0;

			for (int i = 0; i < mPlaybackSettings.mOversampling; i++ )
			{
				sample += *oversampleBuffer++;
			}

			*outputBuffer++ = (short) (sample / mPlaybackSettings.mOversampling);
		}
	}
}


// ----------------------------------------------------------------------------
static inline float approximate_dac(int x, float kinkiness)
// ----------------------------------------------------------------------------
{
    float bits = 0.0f;
    for (int i = 0; i < 11; i += 1)
        if (x & (1 << i))
            bits += pow(i, 4) / pow(10, 4);

    return x * (1.0f + bits * kinkiness);

}


// ----------------------------------------------------------------------------
void PlayerLibSidplay::setFilterSettingsFromPlaybackSettings(sid_filter_t& filterSettings, PlaybackSettings* settings)
// ----------------------------------------------------------------------------
{
	filterSettings.distortion_enable = settings->mEnableFilterDistortion;
	filterSettings.rate = settings->mDistortionRate;
	filterSettings.headroom = settings->mDistortionHeadroom;

	if (settings->mFilterType == SID_FILTER_8580)
	{
		filterSettings.opmin = -99999;
		filterSettings.opmax = 99999;
        filterSettings.distortion_enable = false;

		filterSettings.points = sDefault8580PointCount;
		memcpy(filterSettings.cutoff, sDefault8580, sizeof(sDefault8580));
	}
	else
	{
		filterSettings.opmin = -20000;
		filterSettings.opmax = 20000;

		filterSettings.points = 0x800;

		for (int i = 0; i < 0x800; i++) 
		{
			float i_kinked = approximate_dac(i, settings->mFilterKinkiness);
			float freq = settings->mFilterBaseLevel + powf(2.0f, (i_kinked - settings->mFilterOffset) / settings->mFilterSteepness);

			// Better expression for this required.
			// As it stands, it's kinda embarrassing.
			for (float j = 1000.f; j < 18500.f; j += 500.f)
			{
				if (freq > j)
					freq -= (freq - j) / settings->mFilterRolloff;
			}
			if (freq > 18500)
				freq = 18500;

			filterSettings.cutoff[i][0] = i;
			filterSettings.cutoff[i][1] = freq;
		}
	}
}


// ----------------------------------------------------------------------------
void PlayerLibSidplay::sidRegisterFrameHasChanged(void* inInstance, SIDPLAY2_NAMESPACE::SidRegisterFrame& inRegisterFrame)
// ----------------------------------------------------------------------------
{
	/*
	printf("Frame %d: ", inRegisterFrame.mTimeStamp);

	for (int i = 0; i < SIDPLAY2_NAMESPACE::SidRegisterFrame::SID_REGISTER_COUNT; i++)
		printf("%02x ", inRegisterFrame.mRegisters[i]);
	
	printf("\n");
	*/
	
	PlayerLibSidplay* player = (PlayerLibSidplay*) inInstance;
	if (player != NULL)
		player->mRegisterLog.push_back(inRegisterFrame);
}




