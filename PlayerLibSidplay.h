
#ifndef _PlayerLibSidplay_H
#define _PlayerLibSidplay_H

#include <sidplay2.h>
#include <resid.h>
#include <resid-emu.h>

#include "AudioDriver.h"

enum SPFilterType
{
	SID_FILTER_6581_Resid = 0,
	SID_FILTER_6581R3,
	SID_FILTER_6581_Galway,
	SID_FILTER_6581R4,
	SID_FILTER_8580,
	SID_FILTER_CUSTOM
};


struct PlaybackSettings
{
	int				mFrequency;
	int				mBits;
	int				mStereo;

	int				mOversampling;
	int				mSidModel;
	bool			mForceSidModel;
	int				mClockSpeed;
	int				mOptimization;
	
	float			mFilterKinkiness;
	float			mFilterBaseLevel;
	float			mFilterOffset;
	float			mFilterSteepness;
	float			mFilterRolloff;
	SPFilterType	mFilterType;
	
	int				mEnableFilterDistortion;
	int				mDistortionRate;
	int				mDistortionHeadroom;	
	
};


typedef std::vector<SIDPLAY2_NAMESPACE::SidRegisterFrame> SidRegisterLog;

const int TUNE_BUFFER_SIZE = 65536 + 2 + 0x7c;

class PlayerLibSidplay
{
public:
							PlayerLibSidplay();
	virtual					~PlayerLibSidplay();

	void					setAudioDriver(AudioDriver* audioDriver);

	void					initEmuEngine(PlaybackSettings *settings);
	void					updateSampleRate(int newSampleRate);
	
	bool					playTuneByPath(const char *filename, int subtune, PlaybackSettings *settings );
	bool					playTuneFromBuffer( char *buffer, int length, int subtune, PlaybackSettings *settings );

	bool					loadTuneByPath(const char *filename, int subtune, PlaybackSettings *settings );
	bool					loadTuneFromBuffer( char *buffer, int length, int subtune, PlaybackSettings *settings );

	bool					startPrevSubtune();
	bool					startNextSubtune();
	bool					startSubtune(int which);
	bool					initCurrentSubtune();

	void					fillBuffer(void* buffer, int len);

	inline int				getTempo()											{ return mCurrentTempo; }
	void					setTempo(int tempo);

	void					setVoiceVolume(int voice, float volume);
	
	sid_filter_t*			getFilterSettings()									{ return &mFilterSettings; }
	void					setFilterSettings(sid_filter_t* filterSettings);
	
	inline bool				isTuneLoaded()										{ return mSidTune != NULL; }
	
	int						getPlaybackSeconds();
	inline int				getCurrentSubtune()									{ return mCurrentSubtune; }
	inline int				getSubtuneCount()									{ return mSubtuneCount; }
	inline int				getDefaultSubtune()									{ return mDefaultSubtune; }
	inline int				hasTuneInformationStrings()							{ return mTuneInfo.numberOfInfoStrings >= 3; }
	inline const char*		getCurrentTitle()									{ return mTuneInfo.infoString[0]; }
	inline const char*		getCurrentAuthor()									{ return mTuneInfo.infoString[1]; }
	inline const char*		getCurrentReleaseInfo()								{ return mTuneInfo.infoString[2]; }
	inline unsigned short	getCurrentLoadAddress()								{ return mTuneInfo.loadAddr; }
	inline unsigned short	getCurrentInitAddress()								{ return mTuneInfo.initAddr; }
	inline unsigned short	getCurrentPlayAddress()								{ return mTuneInfo.playAddr; }
	inline const char*		getCurrentFormat()									{ return mTuneInfo.formatString; }
	inline int				getCurrentFileSize()								{ return mTuneInfo.dataFileLen; }
	inline char*			getTuneBuffer(int& outTuneLength)					{ outTuneLength = mTuneLength; return mTuneBuffer; }

	inline const char* getCurrentChipModel()				
	{
		if (mTuneInfo.sidModel == SIDTUNE_SIDMODEL_6581)
			return sChipModel6581;
		
		if (mTuneInfo.sidModel == SIDTUNE_SIDMODEL_8580)
			return sChipModel8580;
		
		return sChipModelUnspecified;
	}

	inline double getCurrentCpuClockRate()
	{
		if (mSidEmuEngine != NULL)
		{
			const sid2_config_t& cfg = mSidEmuEngine->config();
			if (cfg.clockSpeed == SID2_CLOCK_PAL)
				return 985248.4;
			else if (cfg.clockSpeed == SID2_CLOCK_NTSC)
				return 1022727.14;
		}
		
		return 985248.4;
	}
	
	inline SIDPLAY2_NAMESPACE::SidRegisterFrame getCurrentSidRegisters() const 
	{ 
		if (mSidEmuEngine != NULL) 
			return mSidEmuEngine->getCurrentRegisterFrame();
		else
			return SIDPLAY2_NAMESPACE::SidRegisterFrame();
	}

	inline void enableRegisterLogging(bool inEnable)
	{
		if (mSidEmuEngine != NULL)
			mSidEmuEngine->setRegisterFrameChangedCallback((void*) this, inEnable ? sidRegisterFrameHasChanged : NULL);
		
		if (inEnable)
			mRegisterLog.clear();
	}
	
	inline const SidRegisterLog& getRegisterLog() const		{ return mRegisterLog; }
	
	static void	setFilterSettingsFromPlaybackSettings(sid_filter_t& filterSettings, PlaybackSettings* settings);
	static void sidRegisterFrameHasChanged(void* inInstance, SIDPLAY2_NAMESPACE::SidRegisterFrame& inRegisterFrame);
	
	static const char*	sChipModel6581;
	static const char*	sChipModel8580;
	static const char*	sChipModelUnknown;
	static const char*	sChipModelUnspecified;

private:

	bool initSIDTune(PlaybackSettings *settings);
	void setupSIDInfo();

	sidplay2*			mSidEmuEngine;
	SidTune*			mSidTune;
	ReSIDBuilder*		mBuilder;
	SidTuneInfo			mTuneInfo;
	PlaybackSettings	mPlaybackSettings;
	
	AudioDriver*		mAudioDriver;

	char				mTuneBuffer[TUNE_BUFFER_SIZE];
	int					mTuneLength;

	int					mCurrentSubtune;
	int					mSubtuneCount;
	int					mDefaultSubtune;
	int					mCurrentTempo;
	
	int					mPreviousOversamplingFactor;
	char*				mOversamplingBuffer;
	
	sid_filter_t		mFilterSettings;
	
	SidRegisterLog		mRegisterLog;
};

#endif