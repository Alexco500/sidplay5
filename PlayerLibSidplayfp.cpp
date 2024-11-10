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
#include "SidTune.h"

#include <sidplayfp.h>
#include <residfp.h>
#include <resid.h>

#include "SidTuneInfo.h"
#include "SidTuneInfoImpl.h"



#include "SidInfo.h"
#include "SidConfig.h"
// local module header
#include "PlayerLibSidplay.h"

#ifndef NO_USB_SUPPORT
// SIDBlaster USB support
#include "hardsidsb.h"
#endif

// bins
#include "bin/c.h"
#include "bin/b.h"
#include "bin/k.h"


unsigned char sid_registers[ 0x19 ];

double mixer_value1 = 1.0;
double mixer_value2 = 1.0;
double mixer_value3 = 1.0;


const char*	PlayerLibSidplay::sChipModel6581 = "MOS 6581";
const char*	PlayerLibSidplay::sChipModel8580 = "MOS 8580";
const char*	PlayerLibSidplay::sChipModelUnknown = "Unknown";
const char*	PlayerLibSidplay::sChipModelUnspecified = "Unspecified";

const int sDefault8580PointCount = 31;
/*
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
*/


// ----------------------------------------------------------------------------
PlayerLibSidplay::PlayerLibSidplay() :
// ----------------------------------------------------------------------------
	mSidEmuEngine(NULL),
	mSidTune(NULL),
	//mBuilder(NULL),
    mTuneInfo(NULL),
	mAudioDriver(NULL),
	mTuneLength(0),
	mCurrentSubtune(0),
	mSubtuneCount(0),
	mDefaultSubtune(0),
	mCurrentTempo(50),
	mPreviousOversamplingFactor(0),
	mOversamplingBuffer(NULL),
#ifndef NO_USB_SUPPORT
    mSIDBlasterUSBbuilder(NULL),
#endif
    //mBuilder_reSID(NULL),
    mExtUSBDeviceActive(false)
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
		//delete mBuilder;
        mBuilder.release();
        mBuilder = NULL;
	}
    if (mBuilder_reSID)
    {
        //delete mBuilder;
        mBuilder_reSID.release();
        mBuilder_reSID = NULL;
    }
#ifndef NO_USB_SUPPORT
    if (mSIDBlasterUSBbuilder)
    {
        delete mSIDBlasterUSBbuilder;
        mSIDBlasterUSBbuilder = NULL;
        mExtUSBDeviceActive = false;
    }
#endif
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
	
	mTuneInfo = (SidTuneInfo *)mSidTune->getInfo();
    mCurrentSubtune = mTuneInfo->currentSong();
    mSubtuneCount = mTuneInfo->songs();
    mDefaultSubtune = mTuneInfo->startSong();
	
    
    //FIXME: FILTER SETTINGS not needed?
    /*
	if (getCurrentChipModel() == sChipModel8580)
	{
		mBuilder->filter((sid_filter_t*)NULL);
	}
	else
	{
		//mFilterSettings.distortion_enable = true;
		mBuilder->filter(&mFilterSettings);
	}
    */
}


// ----------------------------------------------------------------------------
void PlayerLibSidplay::initEmuEngine(PlaybackSettings *settings)
// ----------------------------------------------------------------------------
{
	//reSID VICE params
    double bias = 0;
    
    if (mSidEmuEngine == NULL )
		mSidEmuEngine = new sidplayfp;

    // Set up a SID builder
	if (mBuilder == NULL)
         mBuilder = std::unique_ptr<ReSIDfpBuilder> (new ReSIDfpBuilder("reSIDfp"));
    
    if (mBuilder_reSID == NULL)
        mBuilder_reSID = std::unique_ptr<ReSIDBuilder>(new ReSIDBuilder("reSID"));

#ifndef NO_USB_SUPPORT
    // Set up a SIDblasterUSB builder
    if (mSIDBlasterUSBbuilder != NULL) {
        delete mSIDBlasterUSBbuilder;
        mSIDBlasterUSBbuilder = NULL;
    }
    if (mSIDBlasterUSBbuilder == NULL) {
        mSIDBlasterUSBbuilder = new HardSIDSBBuilder("SIDBlaster");
    }
#endif
    // set bins
    mSidEmuEngine->setRoms(kernalr, basicr, charr);

    if (mAudioDriver)
		settings->mFrequency = mAudioDriver->getSampleRate();
		
	mPlaybackSettings = *settings;

    SidConfig cfg = mSidEmuEngine->config();
	if (mPlaybackSettings.mClockSpeed == 0)
	{
		cfg.defaultC64Model    = SidConfig::c64_model_t::PAL;
	}
	else
	{
        cfg.defaultC64Model    = SidConfig::c64_model_t::NTSC;
	}
    //FIXME: check if this is really needed, default settings are always sane
    /*

	cfg.clockForced   = true;
	
	cfg.environment   = sid2_envR;
	cfg.playback	  = sid2_mono;
	cfg.precision     = mPlaybackSettings.mBits;
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

    // * mPlaybackSettings.mOversampling;
	//printf("optimization: %d\n", cfg.optimisation);
     */
    
    if (!mPlaybackSettings.SIDselectorOverrideActive) {
        if (mPlaybackSettings.mSidModel == 0)
            cfg.defaultSidModel    = SidConfig::MOS6581;
        else
            cfg.defaultSidModel    = SidConfig::MOS8580;

        if (mPlaybackSettings.mForceSidModel)
        { // force SID and PAL/NTSC if user wants that
            cfg.forceSidModel = true;
            cfg.forceC64Model = true;
        } else {
            cfg.forceSidModel = false;
            cfg.forceC64Model = false;

        }
    } else {
        // manual ovveride of settings
        if (mPlaybackSettings.SIDselectorOverrideModel == 0)
            cfg.defaultSidModel      = SidConfig::MOS6581;
        else
            cfg.defaultSidModel      = SidConfig::MOS8580;
        cfg.forceSidModel = true;
    }
    // set reSID VICE specific config values
    if (cfg.forceSidModel)
    {
        if (cfg.defaultSidModel == SidConfig::MOS6581) {
            bias = 500/1000;
        } else {
            bias = 0;
        }
            
    }
//	cfg.sidEmulation  = mBuilder;
//	cfg.sidSamples	  = true;
//	cfg.sampleFormat  = SID2_BIG_UNSIGNED;
//	setFilterSettingsFromPlaybackSettings(mFilterSettings, settings);
	
    // Get the number of SIDs supported by the engine
    unsigned int maxsids = (mSidEmuEngine->info()) .maxsids();

    // Create SID emulators
    mBuilder->create(maxsids);
    mBuilder_reSID->create(maxsids);
#ifndef NO_USB_SUPPORT
    mSIDBlasterUSBbuilder->create(maxsids);
    
    int count  = mSIDBlasterUSBbuilder->availDevices();
    // Check if builder is ok
    if (!mSIDBlasterUSBbuilder->getStatus())
    {
        printf("SIDBlasterUSB configure error: %s\n", mSIDBlasterUSBbuilder->error());
    } else {
        mExtUSBDeviceActive = true;
    }
#else
    mExtUSBDeviceActive = false;
#endif
   // Check if builder is ok
   if (!mBuilder->getStatus())
   {
       printf("configure error: %s\n", mBuilder->error());
       return;
   }
    // Check if builder is ok
    if (!mBuilder_reSID->getStatus())
    {
        printf("configure error: %s\n", mBuilder_reSID->error());
        return;
    }
    
    mBuilder_reSID->filter(true);
    mBuilder_reSID->bias(bias);

	mBuilder->filter(false);
//	mBuilder->filter(&mFilterSettings);
//	mBuilder->sampling(cfg.frequency);
    if (mExtUSBDeviceActive)
        cfg.sidEmulation   = (sidbuilder*)mSIDBlasterUSBbuilder;
    else
        cfg.sidEmulation   = mBuilder.get();
    
    cfg.frequency      = mPlaybackSettings.mFrequency;
    cfg.samplingMethod = SidConfig::RESAMPLE_INTERPOLATE;
    cfg.fastSampling   = false;
    cfg.playback       = SidConfig::MONO;

	bool rc = mSidEmuEngine->config(cfg);
	if (!rc)
		printf("configure error: %s\n", mSidEmuEngine->error());

//	mSidEmuEngine->setRegisterFrameChangedCallback(NULL, NULL);
}


// ----------------------------------------------------------------------------
void PlayerLibSidplay::updateSampleRate(int newSampleRate)
// ----------------------------------------------------------------------------
{
	if (mSidEmuEngine == NULL)
		return;
	
	mPlaybackSettings.mFrequency = newSampleRate;
	
	SidConfig cfg = mSidEmuEngine->config();
	cfg.frequency	  = mPlaybackSettings.mFrequency * mPlaybackSettings.mOversampling;

	//mBuilder->sampling(cfg.frequency);

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
#ifndef NO_USB_SUPPORT
	//printf("setting sid tune info\n");
    if (mSIDBlasterUSBbuilder) {
        libsidplayfp::SidTuneInfoImpl *mSidInfo = (libsidplayfp::SidTuneInfoImpl *)mSidTune->getInfo();
        switch (mSidInfo->getClockSpeed())
        {
            case SidTuneInfo::CLOCK_NTSC:
                mSIDBlasterUSBbuilder->setClockToPAL(false);
                break;
            case SidTuneInfo::CLOCK_UNKNOWN:
            case SidTuneInfo::CLOCK_ANY:
            case SidTuneInfo::CLOCK_PAL:
                mSIDBlasterUSBbuilder->setClockToPAL(true);
                break;
        }
    }
#endif
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
	
    if (success) {
#ifndef NO_USB_SUPPORT

        if (mSIDBlasterUSBbuilder) {
            mSIDBlasterUSBbuilder->reset(0x0f);
        }
#endif
        mAudioDriver->startPlayback();
    }
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

    if (success) {
#ifndef NO_USB_SUPPORT
        if (mSIDBlasterUSBbuilder) {
            mSIDBlasterUSBbuilder->reset(0x0f);
        }
#endif
        mAudioDriver->startPlayback();
    }
	return success;
}


// ----------------------------------------------------------------------------
bool PlayerLibSidplay::loadTuneByPath(const char* filename, int subtune, PlaybackSettings* settings)
// ----------------------------------------------------------------------------
{
	FILE* fp = fopen(filename, "rb");
	
	if ( fp == NULL )
		return false;

	long length = fread(mTuneBuffer, 1,TUNE_BUFFER_SIZE, fp);
	
	if (length < 0)
		return false;

	//printf("file reading worked\n");

	fclose(fp);

	mTuneLength = (int)length;
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
SidRegisterFrame PlayerLibSidplay::getCurrentSidRegisters(void)
{
    if (mSidEmuEngine != NULL) {
        mSidEmuEngine->getSidStatus(0, &currentRegisterFrame.mRegisters[0]);
        return currentRegisterFrame;
    }
        else
            return currentRegisterFrame;
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
    /* FIXME: Override Optimization? Available?
	if (tempo < 50)
		mBuilder->overrideOptimisation(SID2_MAX_OPTIMISATION);
	else
		mBuilder->overrideOptimisation(mPlaybackSettings.mOptimization);
    */
	mSidEmuEngine->fastForward( 10000 / tempo );
}


// ----------------------------------------------------------------------------
void PlayerLibSidplay::setVoiceVolume(int voice, float volume)
// ----------------------------------------------------------------------------
{
    if (mSidEmuEngine == NULL)
        return;
    if (mBuilder_reSID == NULL)
        return;
    int numberSids = mBuilder_reSID->usedDevices();
    
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
    if (volume == 0)
        for (int i=0;i<numberSids;i++)
            mSidEmuEngine->mute(i, voice, true);
    else
        for (int i=0;i<numberSids;i++)
            mSidEmuEngine->mute(i, voice, false);
}

/* FIXME: FILTER SETTINGS?!
// ----------------------------------------------------------------------------
void PlayerLibSidplay::setFilterSettings(sid_filter_t* filterSettings)
// ----------------------------------------------------------------------------
{

	mFilterSettings = *filterSettings;
	if (mBuilder)
		mBuilder->filter(&mFilterSettings);

}
 */

// ----------------------------------------------------------------------------
int PlayerLibSidplay::getPlaybackSeconds()
// ----------------------------------------------------------------------------
{
	if (mSidEmuEngine == NULL)
		return 0;

    return(mSidEmuEngine->time());// / 10);
}



//FIXME: we have void* defined, but use now short*
// ----------------------------------------------------------------------------
void PlayerLibSidplay::fillBuffer(void* buffer, int len)
// ----------------------------------------------------------------------------
{
	if (mSidEmuEngine == NULL)
		return;
    //libsidplayfp uses number of 16-Bit samples (short), not bytes for buffer count
    int count16 = len/2;
    if (mExtUSBDeviceActive) {
        for (int i = 0;i<50;i++)
            mSidEmuEngine->play((short *)buffer, 0);

        return;
    }
    
	if (mPlaybackSettings.mOversampling == 1)
		mSidEmuEngine->play((short *)buffer, count16);
	else
	{
		if (mPlaybackSettings.mOversampling != mPreviousOversamplingFactor)
		{
			delete[] mOversamplingBuffer;
			mOversamplingBuffer = new char[len * mPlaybackSettings.mOversampling];
			mPreviousOversamplingFactor = mPlaybackSettings.mOversampling;
		}
		
		// calculate n times as much sample data
		mSidEmuEngine->play((short *)mOversamplingBuffer, (count16 * mPlaybackSettings.mOversampling)/2);

		short *oversampleBuffer = (short*) mOversamplingBuffer;
		short *outputBuffer = (short*) buffer;
        long sample = 0;
		
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
// moved from header to here because of include chaos...
int PlayerLibSidplay::hasTuneInformationStrings(void)
{
    return mTuneInfo->numberOfInfoStrings() >= 3;
}

const char* PlayerLibSidplay::getCurrentTitle(void)
{
    return mTuneInfo->infoString(0);
}

const char* PlayerLibSidplay::getCurrentAuthor(void)
{
    return mTuneInfo->infoString(1);
}
const char*  PlayerLibSidplay::getCurrentReleaseInfo(void)
{
    return mTuneInfo->infoString(2);
}

unsigned short PlayerLibSidplay::getCurrentLoadAddress(void)
{
     return mTuneInfo->loadAddr();
}
unsigned short PlayerLibSidplay::getSidChips(void)
{
     return mTuneInfo->sidChips();
}

unsigned short PlayerLibSidplay::getCurrentInitAddress(void)
{
    return mTuneInfo->initAddr();
}
unsigned short PlayerLibSidplay::getCurrentPlayAddress(void)
{
    return mTuneInfo->playAddr();
}

const char* PlayerLibSidplay::getCurrentFormat(void)
{
     return mTuneInfo->formatString();
}
int PlayerLibSidplay::getCurrentFileSize(void)
{
    return mTuneInfo->dataFileLen();
}

const char* PlayerLibSidplay::getCurrentChipModel()
{
    if (mTuneInfo != NULL) {
        if (mTuneInfo->sidModel(0) == SidTuneInfo::SIDMODEL_6581)
            return sChipModel6581;
        
        if (mTuneInfo->sidModel(0) == SidTuneInfo::SIDMODEL_8580)
            return sChipModel8580;
    }
    return sChipModelUnspecified;
}
// for popoverSIDSelector
int PlayerLibSidplay::getSIDModelFromTune(void)
{
    if (mTuneInfo != NULL) {
        if (mTuneInfo->sidModel(0) == SidTuneInfo::SIDMODEL_6581)
            return M_6581;
        if (mTuneInfo->sidModel(0) == SidTuneInfo::SIDMODEL_8580)
            return M_8580;
    }
    return M_UNKNOWN;
}
char* PlayerLibSidplay::getTuneBuffer(int& outTuneLength)
{
    outTuneLength = mTuneLength;
    return mTuneBuffer;
}

/* FIXME: Again filter settings....
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
*/

// ----------------------------------------------------------------------------
void PlayerLibSidplay::sidRegisterFrameHasChanged(void* inInstance, SidRegisterFrame& inRegisterFrame)
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




