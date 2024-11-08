#ifndef _AUDIODRIVER_H_
#define _AUDIODRIVER_H_

class PlayerLibSidplay;

class AudioDriver
{
public:

	virtual			~AudioDriver() { }

	virtual void	initialize(PlayerLibSidplay* player, int sampleRate = 44100, int bitsPerSample = 16) = 0;

	virtual bool	startPlayback() = 0;
	virtual void	stopPlayback() = 0;
	
	virtual bool	startPreRenderedBufferPlayback() = 0;
	virtual void	stopPreRenderedBufferPlayback() = 0;
	virtual void	setPreRenderedBuffer(short* inBuffer, int inBufferLength) = 0;
	virtual bool	getIsPlayingPreRenderedBuffer() = 0;
	virtual int		getPreRenderedBufferPlaybackPosition() = 0;
	virtual void	setPreRenderedBufferPlaybackPosition(int inPosition) = 0;

	virtual float	getVolume() = 0;
	virtual void	setVolume(float volume) = 0;

	virtual float	getPreRenderedBufferVolume() = 0;
	virtual void	setPreRenderedBufferVolume(float volume) = 0;

	virtual void	setBufferUnderrunDetected(bool flag) = 0;
	virtual bool	getBufferUnderrunDetected() = 0;
	
	virtual bool	getIsPlaying() = 0;
	virtual short*	getSampleBuffer() = 0;
	virtual int		getSampleRate() = 0;
    virtual int     getNumSamplesInBuffer() = 0;
};


#endif // _AUDIODRIVER_H_
