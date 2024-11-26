//
//  PlaybackSettings.h
//  SIDPLAY
//
//  Created by Alexander Coers on 14.11.24.
//
#ifndef PLAYBACKSETTINGS_H
#define PLAYBACKSETTINGS_H
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
    int                mFrequency;
    int                mBits;
    int                mStereo;

    int                mOversampling;
    int                mSidModel;
    bool            mForceSidModel;
    int                mClockSpeed;
    int                mOptimization;

    float            mFilterKinkiness;
    float            mFilterBaseLevel;
    float            mFilterOffset;
    float            mFilterSteepness;
    float            mFilterRolloff;
    enum SPFilterType    mFilterType;

    int                mEnableFilterDistortion;
    int                mDistortionRate;
    int                mDistortionHeadroom;
    // manual override
    bool            SIDselectorOverrideActive;
    int             SIDselectorOverrideModel;

};
#endif /* PLAYBACKSETTINGS_H */
