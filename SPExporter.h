#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>
#import "PlayerLibSidplay.h"

@class SPPlayerWindow;
@class SPExportController;
@class SPExportItem;


enum ExportFileType
{
	EXPORT_TYPE_MP3 = 0,
	EXPORT_TYPE_AAC,
	EXPORT_TYPE_ALAC,
	EXPORT_TYPE_AIFF,
	EXPORT_TYPE_PRG,
	EXPORT_TYPE_PSID,
	
	NUM_EXPORT_TYPES
};


struct ExportSettings
{
	void Init() 
	{
		mTimeInSeconds = 180;
		mWithFadeOut = NO;
		mFadeOutTime = 3;
		mBitRate = 128;
		mUseVBR = NO;
		mQuality = 0.5f;

		mBlankScreen = NO;
		mIncludeStilComment = NO;
		mCompressOutputFile = NO;
	}
					
	
	ExportFileType	mFileType;
	NSUInteger		mTimeInSeconds;
	BOOL			mWithFadeOut;
	int				mFadeOutTime;
	int				mBitRate;
	BOOL			mUseVBR;
	float			mQuality;
	
	BOOL			mBlankScreen;
	BOOL			mIncludeStilComment;
	BOOL			mCompressOutputFile;
};


@interface SPExporter : NSObject
{
	SPExportController* controller;
	SPPlayerWindow* ownerWindow;
	PlayerLibSidplay* player;
	PlaybackSettings settings;
	SPExportItem* exportItem;
	
	BOOL exportItemLoaded;
	BOOL exportStopped;
	BOOL exportInProgress;
	BOOL exportProgressIsIndeterminate;
	
	ExportSettings exportSettings;

	ExtAudioFileRef outputFileRef;
	NSUInteger samplesRemaining;
	NSUInteger samplesCompleted;
	AudioStreamBasicDescription inputFormat;
	AudioStreamBasicDescription outputFormat;
	
	NSString* title;
	NSString* author;
	NSString* releaseInfo;
	
	NSTask* psid64Task;
	
	NSString* destinationPath;
	NSString* fileName;
	NSImage* fileIcon;
	float exportProgress;
}

- (id) initWithItem:(SPExportItem*)item withController:(SPExportController*)theController andWindow:(SPPlayerWindow*)window loadNow:(BOOL)loadItem;

- (BOOL) loadExportItem;
- (void) unloadExportItem;

- (void) determineExportFilePath:(NSString*)directoryPath;
- (NSString*) suggestedFileExtension;
- (NSString*) suggestedFilename;

- (void) setFileName:(NSString*)name;
- (NSString*) fileName;

- (void) setDestinationPath:(NSString*)path;

- (ExportSettings) exportSettings;
- (void) setExportSettings:(ExportSettings)theExportSettings;

- (NSImage*) fileIcon;
- (void) setFileIcon:(NSImage*)icon;

- (PlayerLibSidplay*) player;

- (BOOL) exportInProgress;

- (BOOL) exportProgressIsIndeterminate;
- (void) setExportProgressIsIndeterminate:(BOOL)indeterminate;

- (BOOL) exportStopped;
- (void) setExportStopped:(BOOL)stopped;

- (float) exportProgress;
- (void) setExportProgress:(float)progress;

- (void) startExport;
- (void) stopExport;
- (void) exportUsingExtAudioFileThread:(id)inObject;
- (void) exportUsingLameThread:(id)inObject;
- (void) exportUsingPsid64;

- (void) exportCompletedNotification:(NSError*)error;
- (void) exportInProgressNotification:(id)progress;
- (void) psid64TaskFinished:(NSNotification*)aNotification;

@end


@interface SPExportItem : NSObject
{
	NSString* path;
	NSString* title;
	NSString* author;
	int subtune;
	int loopCount;
	SPExporter* exporter;
}

- (id) initWithPath:(NSString*)filePath andTitle:(NSString*)titleString andAuthor:(NSString*)authorString andSubtune:(int)subtuneIndex andLoopCount:(int)loops;

- (NSString*) path;
- (void) setPath:(NSString*)filePath;

- (NSString*) title;
- (void) setTitle:(NSString*)titleString;

- (NSString*) author;
- (void) setAuthor:(NSString*)authorString;

- (int) subtune;
- (void) setSubtune:(int)subtuneIndex;

- (int) loopCount;
- (void) setLoopCount:(int)loops;

- (SPExporter*) exporter;
- (void) setExporter:(SPExporter*)theExporter;

@end
