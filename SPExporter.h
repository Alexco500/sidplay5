#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>
#import "PlayerLibSidplayWrapper.h"
#import "PlaybackSettings.h"

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


@interface ExportSettings : NSObject
{
    enum ExportFileType  mFileType;
    NSUInteger           mTimeInSeconds;
    BOOL         mWithFadeOut;
    int          mFadeOutTime;
    int          mBitRate;
    BOOL         mUseVBR;
    float        mQuality;
    BOOL         mBlankScreen;
    BOOL         mIncludeStilComment;
    BOOL         mCompressOutputFile;
}
@property enum ExportFileType   mFileType;
@property NSUInteger            mTimeInSeconds;
@property BOOL            mWithFadeOut;
@property int             mFadeOutTime;
@property int             mBitRate;
@property BOOL            mUseVBR;
@property float           mQuality;
@property BOOL            mBlankScreen;
@property BOOL            mIncludeStilComment;
@property BOOL            mCompressOutputFile;
@end


@interface SPExporter : NSObject
{
    SPExportController* controller;
    SPPlayerWindow* ownerWindow;
    PlayerLibSidplayWrapper* player;
    struct PlaybackSettings settings;
    SPExportItem* exportItem;
    
    BOOL exportItemLoaded;
    BOOL exportStopped;
    BOOL exportInProgress;
    BOOL exportProgressIsIndeterminate;
    
    ExportSettings *exportSettings;
    
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

- (instancetype) initWithItem:(SPExportItem*)item withController:(SPExportController*)theController andWindow:(SPPlayerWindow*)window loadNow:(BOOL)loadItem NS_DESIGNATED_INITIALIZER;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL loadExportItem;
- (void) unloadExportItem;

- (void) determineExportFilePath:(NSString*)directoryPath;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *suggestedFileExtension;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *suggestedFilename;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *fileName;

- (void) setDestinationPath:(NSString*)path;

@property (NS_NONATOMIC_IOSONLY) ExportSettings* exportSettings;

@property (NS_NONATOMIC_IOSONLY, copy) NSImage *fileIcon;

@property (NS_NONATOMIC_IOSONLY, readonly) PlayerLibSidplayWrapper *player;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL exportInProgress;

@property (NS_NONATOMIC_IOSONLY) BOOL exportProgressIsIndeterminate;

@property (NS_NONATOMIC_IOSONLY) BOOL exportStopped;

@property (NS_NONATOMIC_IOSONLY) float exportProgress;

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

- (instancetype) initWithPath:(NSString*)filePath andTitle:(NSString*)titleString andAuthor:(NSString*)authorString andSubtune:(int)subtuneIndex andLoopCount:(int)loops NS_DESIGNATED_INITIALIZER;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *path;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *title;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *author;

@property (NS_NONATOMIC_IOSONLY) int subtune;

@property (NS_NONATOMIC_IOSONLY) int loopCount;

@property (NS_NONATOMIC_IOSONLY, strong) SPExporter *exporter;

@end
