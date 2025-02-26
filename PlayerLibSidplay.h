
#ifndef _PlayerLibSidplay_H
#define _PlayerLibSidplay_H


#include <vector>
#include "AudioDriver.h"
#include "PlaybackSettings.h"

class sidplayfp;
class ReSIDfpBuilder;
class ReSIDBuilder;
class SidTune;
class SidTuneInfo;
#ifndef NO_USB_SUPORT
class HardSIDSBBuilder;
#endif
typedef int_fast64_t event_clock_t;

// for PopupSIDSelector
enum SIDmodelsGUI
{
    M_UNKNOWN = 0,
    M_6581,
    M_8580
};

struct SidRegisterFrame
{
    enum
    {
        SID_REGISTER_COUNT = 0x19
    };
    
    SidRegisterFrame() : mTimeStamp(0) { for (int i = 0; i < SID_REGISTER_COUNT; i++) mRegisters[i] = 0; }
    
    uint8_t mRegisters[32];  //sidplayfp uses 32, not 25
    event_clock_t mTimeStamp;
};

//typedef void (*SidRegisterFrameChangedCallback) (void* inInstance, SidRegisterFrame& inRegisterFrame);

typedef std::vector<SidRegisterFrame> SidRegisterLog;

const int TUNE_BUFFER_SIZE = 65536 + 2 + 0x7c;

class PlayerLibSidplay
{
public:
							PlayerLibSidplay();
	virtual					~PlayerLibSidplay();

	void					setAudioDriver(AudioDriver* audioDriver);
    void                    stopEmuEngine();
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
	
//	sid_filter_t*			getFilterSettings()									{ return &mFilterSettings; }
//	void					setFilterSettings(sid_filter_t* filterSettings);
	
	inline bool				isTuneLoaded()										{ return mSidTune != NULL; }
	
	int						getPlaybackSeconds();
	inline int				getCurrentSubtune()									{ return mCurrentSubtune; }
	inline int				getSubtuneCount()									{ return mSubtuneCount; }
	inline int				getDefaultSubtune()									{ return mDefaultSubtune; }
	
     int				hasTuneInformationStrings();
	
     const char*		getCurrentTitle();
	
     const char*		getCurrentAuthor();
     const char*		getCurrentReleaseInfo();
     unsigned short	getCurrentLoadAddress();
     unsigned short	getCurrentInitAddress();
     unsigned short	getCurrentPlayAddress();
    unsigned short getSidChips();
	
     const char*		getCurrentFormat();
     int				getCurrentFileSize();
     char*			getTuneBuffer(int& outTuneLength);
     const char* getCurrentChipModel();
    // for popoverSIDSelector
    int getSIDModelFromTune();
    
    SidRegisterFrame getCurrentSidRegisters();

    PlaybackSettings* getCurrentPlaybackSettings()
    {
        return &mPlaybackSettings;
    }
	
	static void sidRegisterFrameHasChanged(void* inInstance, SidRegisterFrame& inRegisterFrame);
	
	static const char*	sChipModel6581;
	static const char*	sChipModel8580;
	static const char*	sChipModelUnknown;
	static const char*	sChipModelUnspecified;

private:

	bool initSIDTune(PlaybackSettings *settings);
	void setupSIDInfo();

	sidplayfp*			mSidEmuEngine;
    SidTune*			mSidTune;
    std::unique_ptr<ReSIDfpBuilder> mBuilder;
    //ReSIDfpBuilder*		mBuilder;
    std::unique_ptr<ReSIDBuilder> mBuilder_reSID;
    //ReSIDBuilder*       mBuilder_reSID;
    // SIDblaster USB
#ifndef NO_USB_SUPORT
    HardSIDSBBuilder*   mSIDBlasterUSBbuilder;
#endif
    bool                mExtUSBDeviceActive;
    
    SidTuneInfo*		mTuneInfo;
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
	
	//sid_filter_t		mFilterSettings;
	
	SidRegisterLog		mRegisterLog;
    
    struct SidRegisterFrame currentRegisterFrame;
    
};

#endif
