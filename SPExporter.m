#import "SPExporter.h"
#import "SPExportController.h"
#import "SPPlayerWindow.h"
#import "PlayerLibSidplayWrapper.h"
#import "SongLengthDatabase.h"
#import "SPCollectionUtilities.h"
#import "SPPreferencesController.h"

#include "TargetConditionals.h"
#include <lame/lame.h>

static NSString* exportFileTypeExtensions[NUM_EXPORT_TYPES] =
{
	@"mp3",
	@"m4a",
	@"m4a",
	@"aiff",
	@"prg",
	@"sid"
};

static AudioFileTypeID exportAudioFileIDs[NUM_EXPORT_TYPES] =
{
	kAudioFileMP3Type,
	kAudioFileM4AType,
	kAudioFileM4AType,
	kAudioFileAIFFType,
	0,
	0
};

@implementation SPExporter

// ----------------------------------------------------------------------------
- (instancetype) init
// ----------------------------------------------------------------------------
{
    return [self initWithItem:nil withController:nil andWindow:nil loadNow:NO];
}

// ----------------------------------------------------------------------------
- (instancetype) initWithItem:(SPExportItem*)item withController:(SPExportController*)theController andWindow:(SPPlayerWindow*)window loadNow:(BOOL)loadItem
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		controller = theController;
		ownerWindow = window;
		
		outputFileRef = NULL;
		exportSettings = [controller exportSettings];
		
		samplesRemaining = 0;
		samplesCompleted = 0;
		
		fileName = nil;
		exportProgress = 0.0f;
		fileIcon = nil;
		
		exportItemLoaded = NO;
		exportInProgress = NO;
		[self setExportStopped:NO];
		[self setExportProgressIsIndeterminate:NO];
		
		psid64Task = nil;
		
        player = [[PlayerLibSidplayWrapper alloc] init];
        struct PlaybackSettings dummy;
        [gPreferences getPlaybackSettings:&dummy];
        [player initEmuEngineWithSettings:&dummy];
		exportItem = item;

		title = [item title];
		author = [item author];

		if (loadItem)
		{
			BOOL itemIsValid = [self loadExportItem];
			if (!itemIsValid)
				return nil;
		}
		
		destinationPath = nil;
	}
	return self;
}


// ----------------------------------------------------------------------------
- (BOOL) loadExportItem
// ----------------------------------------------------------------------------
{
	if (exportItemLoaded)
		return NO;
    [gPreferences getPlaybackSettings:&settings];

	NSString* path = [exportItem path];
	int subtune = [exportItem subtune];
    bool success = [player loadTuneByPath:
                    [path cStringUsingEncoding:NSUTF8StringEncoding]
                                  subtune: subtune withSettings:&settings];
	if (!success)
		return NO;

    exportSettings.mTimeInSeconds = [[SongLengthDatabase sharedInstance] getSongLengthByPath:path andSubtune:subtune];
    if (exportSettings.mTimeInSeconds == 0)
        exportSettings.mTimeInSeconds = gPreferences.mDefaultPlayTime;
	if ([exportItem loopCount] > 0)
        exportSettings.mTimeInSeconds *= [exportItem loopCount];

	releaseInfo = [NSString stringWithCString:[player getCurrentReleaseInfo] encoding:NSISOLatin1StringEncoding];

	exportItemLoaded = YES;

	return YES;
}


// ----------------------------------------------------------------------------
- (void) unloadExportItem
// ----------------------------------------------------------------------------
{
	if (!exportItemLoaded)
		return;
	
	exportItemLoaded = NO;
}	


// ----------------------------------------------------------------------------
- (ExportSettings *) exportSettings
// ----------------------------------------------------------------------------
{
	return exportSettings;
}


// ----------------------------------------------------------------------------
- (void) setExportSettings:(ExportSettings *)theExportSettings
// ----------------------------------------------------------------------------
{
	exportSettings = theExportSettings;
}


// ----------------------------------------------------------------------------
- (void) determineExportFilePath:(NSString*)directoryPath
// ----------------------------------------------------------------------------
{
	NSString* suggestedFilename = [self suggestedFilename];
	NSString* suggestedFilenameWithoutExtension = suggestedFilename.stringByDeletingPathExtension;
	NSString* suggestedExtension = [self suggestedFileExtension]; 

	NSString* filename = [suggestedFilenameWithoutExtension stringByAppendingPathExtension:suggestedExtension];
	
	NSString* destinationFile = [directoryPath stringByAppendingPathComponent:filename];
	
	int retryCount = 1;
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:destinationFile];
	while (exists)
	{
		filename = [suggestedFilenameWithoutExtension stringByAppendingFormat:@" %d", retryCount];
		filename = [filename stringByAppendingPathExtension:suggestedExtension];
		
		destinationFile = [directoryPath stringByAppendingPathComponent:filename];
		
		retryCount++;
		exists = [[NSFileManager defaultManager] fileExistsAtPath:destinationFile];
	}

	[self setDestinationPath:destinationFile];
}


// ----------------------------------------------------------------------------
- (NSString*) suggestedFileExtension
// ----------------------------------------------------------------------------
{
	return exportFileTypeExtensions[exportSettings.mFileType];
}


// ----------------------------------------------------------------------------
- (NSString*) suggestedFilename
// ----------------------------------------------------------------------------
{
	NSRange slashRange = [author rangeOfString:@"/"];
	NSString* authorWithoutGroup = nil;
	if (slashRange.location == NSNotFound)
		authorWithoutGroup = author;
	else
		authorWithoutGroup = [author substringToIndex:slashRange.location];

	authorWithoutGroup = [authorWithoutGroup stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	NSString* titleWithoutSlashes = [title stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
	return [NSString stringWithFormat:@"%@ - %@ (song %d).%@", authorWithoutGroup, titleWithoutSlashes, [exportItem subtune], exportFileTypeExtensions[exportSettings.mFileType]];
}


// ----------------------------------------------------------------------------
- (void) setFileName:(NSString*)name
// ----------------------------------------------------------------------------
{
	fileName = name;
}


// ----------------------------------------------------------------------------
- (NSString*) fileName
// ----------------------------------------------------------------------------
{
	return fileName;
}


// ----------------------------------------------------------------------------
- (void) setDestinationPath:(NSString*)path
// ----------------------------------------------------------------------------
{
	destinationPath = path;
	[self setFileName:path.lastPathComponent];
}


// ----------------------------------------------------------------------------
- (PlayerLibSidplayWrapper*) player
// ----------------------------------------------------------------------------
{
	return player;
}


// ----------------------------------------------------------------------------
- (NSImage*) fileIcon
// ----------------------------------------------------------------------------
{
	return fileIcon;
}


// ----------------------------------------------------------------------------
- (void) setFileIcon:(NSImage*)icon
// ----------------------------------------------------------------------------
{
	fileIcon = icon;
}


// ----------------------------------------------------------------------------
- (BOOL) exportInProgress
// ----------------------------------------------------------------------------
{
	return exportInProgress;
}


// ----------------------------------------------------------------------------
- (BOOL) exportStopped
// ----------------------------------------------------------------------------
{
	return exportStopped;
}


// ----------------------------------------------------------------------------
- (void) setExportStopped:(BOOL)stopped
// ----------------------------------------------------------------------------
{
	exportStopped = stopped;
}


// ----------------------------------------------------------------------------
- (float) exportProgress
// ----------------------------------------------------------------------------
{
	return exportProgress;
}


// ----------------------------------------------------------------------------
- (void) setExportProgress:(float)progress
// ----------------------------------------------------------------------------
{
	exportProgress = progress;
}


// ----------------------------------------------------------------------------
- (BOOL) exportProgressIsIndeterminate
// ----------------------------------------------------------------------------
{
	return exportProgressIsIndeterminate;
}


// ----------------------------------------------------------------------------
- (void) setExportProgressIsIndeterminate:(BOOL)indeterminate
// ----------------------------------------------------------------------------
{
	exportProgressIsIndeterminate = indeterminate;
}


// ----------------------------------------------------------------------------
- (void) startExport
// ----------------------------------------------------------------------------
{
	samplesRemaining = exportSettings.mTimeInSeconds * settings.mFrequency;
	samplesCompleted = 0;
	exportProgress = 0.0f;
	
	[self setExportStopped:NO];
	exportInProgress = YES;
	
	if (exportSettings.mFileType == EXPORT_TYPE_MP3)
		[NSThread detachNewThreadSelector:@selector(exportUsingLameThread:) toTarget:self withObject:nil];
	else if (exportSettings.mFileType == EXPORT_TYPE_PRG)
		[self exportUsingPsid64];
	else
		[NSThread detachNewThreadSelector:@selector(exportUsingExtAudioFileThread:) toTarget:self withObject:nil];
}


// ----------------------------------------------------------------------------
- (void) stopExport
// ----------------------------------------------------------------------------
{
	[self setExportStopped:YES];
	if (!exportInProgress)
		[controller exportFinished:self];
}


// ----------------------------------------------------------------------------
- (void) revealExportFile
// ----------------------------------------------------------------------------
{
	if (destinationPath != nil)
	{
		NSWorkspace* workSpace = [NSWorkspace sharedWorkspace];
		[workSpace selectFile:destinationPath inFileViewerRootedAtPath:@""];
	}
}


// ----------------------------------------------------------------------------
- (void) exportUsingPsid64
// ----------------------------------------------------------------------------
{
	[self setExportProgressIsIndeterminate:YES];
	
	//NSString* psid64ExecutablePath = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"psid64"];
    //macOS executables should reside in executable folders for signing
    NSString* psid64ExecutablePath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"psid64"];

    NSMutableArray* psid64Arguments = [NSMutableArray arrayWithCapacity:3];

	if (exportSettings.mBlankScreen)
		[psid64Arguments addObject:@"-b"];
		
	if (exportSettings.mIncludeStilComment)
		[psid64Arguments addObject:@"-g"];

	if (exportSettings.mCompressOutputFile)
		[psid64Arguments addObject:@"-c"];

	[psid64Arguments addObject:@"-v"];

	[psid64Arguments addObject:[NSString stringWithFormat:@"-i %d", [exportItem subtune]]];
	//[psid64Arguments addObject:[NSString stringWithFormat:@"-r %@", [[SPCollectionUtilities sharedInstance] rootPath]]];
	[psid64Arguments addObject:[NSString stringWithFormat:@"-s %@", [[SongLengthDatabase sharedInstance] databasePath]]];
	[psid64Arguments addObject:[NSString stringWithFormat:@"-o%@", destinationPath]];
	[psid64Arguments addObject:[exportItem path]];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(psid64TaskFinished:) name:NSTaskDidTerminateNotification object:nil];	
	psid64Task = [[NSTask alloc] init];
	psid64Task.launchPath = psid64ExecutablePath;
	psid64Task.currentDirectoryPath = [NSBundle mainBundle].resourcePath;
	psid64Task.arguments = psid64Arguments;
	[psid64Task launch];
}


// ----------------------------------------------------------------------------
- (void) psid64TaskFinished:(NSNotification*)aNotification
// ----------------------------------------------------------------------------
{
	NSTask* task = (NSTask*) aNotification.object;
	if (task != psid64Task)
		return;

	psid64Task = nil;
	
	NSNumber* creatorCode = [NSNumber numberWithUnsignedLong:'C=64'];
	NSNumber* typeCode = [NSNumber numberWithUnsignedLong:'C64F'];
	NSDictionary* attributes = @{NSFileHFSCreatorCode: creatorCode, NSFileHFSTypeCode: typeCode};
	[[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:destinationPath error:nil];

	NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:destinationPath];
	//[icon setScalesWhenResized:NO];
	icon.size = NSMakeSize(32, 32);
	[self setFileIcon:icon];

	exportInProgress = NO;
	[self setExportStopped:YES];
	[controller exportFinished:self];
	[self setExportProgressIsIndeterminate:NO];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


// ----------------------------------------------------------------------------
- (void) exportUsingExtAudioFileThread:(id)inObject
// ----------------------------------------------------------------------------
{
    OSStatus err = noErr;

	[NSThread setThreadPriority:[NSThread threadPriority]+.1];
    
    // create the file
    if (outputFileRef == NULL)
	{
		// NSString* directory = destinationPath.stringByDeletingLastPathComponent;
		// NSString* filename = [[NSString alloc] initWithString:destinationPath.lastPathComponent];
        
        NSURL* fileUrl = [[NSURL alloc] initFileURLWithPath:destinationPath];

		BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:destinationPath];
		if (exists)
			[[NSFileManager defaultManager] removeItemAtPath:destinationPath error:nil];

		//FSRef directoryFileRef;
		//err = FSPathMakeRef((const UInt8*)directory.fileSystemRepresentation, &directoryFileRef, NULL);

		// The format in which we render the SID output
		inputFormat.mChannelsPerFrame = 1;
		inputFormat.mSampleRate = settings.mFrequency;
		inputFormat.mFormatID = kAudioFormatLinearPCM;
#if TARGET_RT_LITTLE_ENDIAN
		inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
#else
		inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsBigEndian;
#endif
		inputFormat.mBytesPerPacket = sizeof(short) * inputFormat.mChannelsPerFrame;
		inputFormat.mFramesPerPacket = 1;
		inputFormat.mBytesPerFrame = sizeof(short) * inputFormat.mChannelsPerFrame;
		inputFormat.mBitsPerChannel = 16;

		// The format for the output file
		UInt32 size = sizeof(outputFormat);

		outputFormat.mSampleRate = settings.mFrequency;
		outputFormat.mChannelsPerFrame = 1;

		switch (exportSettings.mFileType)
		{
			case EXPORT_TYPE_AAC:
				outputFormat.mFormatID = kAudioFormatMPEG4AAC;
				outputFormat.mFormatFlags = 0;
				err = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &outputFormat);
				break;

			case EXPORT_TYPE_ALAC:
				outputFormat.mFormatID = kAudioFormatAppleLossless;
				outputFormat.mFormatFlags = 0;
				err = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &outputFormat);
				break;

			case EXPORT_TYPE_AIFF:
			default:
				outputFormat.mFormatID = kAudioFormatLinearPCM;
				outputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
				outputFormat.mBytesPerPacket = sizeof(short) * outputFormat.mChannelsPerFrame;
				outputFormat.mFramesPerPacket = 1;
				outputFormat.mBytesPerFrame = sizeof(short) * outputFormat.mChannelsPerFrame;
				outputFormat.mBitsPerChannel = 16;
		}
		
		//err = ExtAudioFileCreateNew(&directoryFileRef, (__bridge CFStringRef)filename, exportAudioFileIDs[exportSettings.mFileType], &outputFormat, NULL, &outputFileRef);		
        err = ExtAudioFileCreateWithURL((__bridge CFURLRef)fileUrl, exportAudioFileIDs[exportSettings.mFileType], &outputFormat, NULL, 0, &outputFileRef);

		NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:destinationPath];
		//[icon setScalesWhenResized:NO];
		icon.size = NSMakeSize(32, 32);
		[self performSelectorOnMainThread:@selector(setFileIcon:) withObject:icon waitUntilDone:NO];

		err = ExtAudioFileSetProperty(outputFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), &inputFormat);
		
		/*
		UInt32 size = sizeof(AudioFileID);
		AudioFileID audioFileId;
		err = ExtAudioFileGetProperty(outputFileRef, kExtAudioFileProperty_AudioFile, &size, &audioFileId);

		NSString* year = [releaseInfo substringWithRange:NSMakeRange(0, 4)];
		const char* yearCString = [year cStringUsingEncoding:NSISOLatin1StringEncoding];
		const char* titleCString = [title cStringUsingEncoding:NSISOLatin1StringEncoding];
		const char* authorCString = [author cStringUsingEncoding:NSISOLatin1StringEncoding];
		const char* commentCString = "Exported with SIDPLAY/Mac";
		UInt32 nameType = 0xa96e616d;
		UInt32 artistType = 0xa9415254;
		UInt32 dayType = 0xa9646179;
		UInt32 commentType = 0xa9636d74;

		size = sizeof(CFStringRef);
		err = AudioFileSetUserData(audioFileId, nameType , 0, size, (CFStringRef)title);
		
		err = AudioFileSetUserData(audioFileId, nameType , 0, strlen(titleCString) + 1, titleCString);
		err = AudioFileSetUserData(audioFileId, artistType, 0, strlen(authorCString) + 1, authorCString);
		err = AudioFileSetUserData(audioFileId, dayType, 0, strlen(yearCString) + 1, yearCString);
		err = AudioFileSetUserData(audioFileId, commentType, 0, strlen(commentCString) + 1, commentCString);
		*/
		
		if (exportSettings.mFileType == EXPORT_TYPE_AAC)
		{
			size = sizeof(AudioConverterRef);
			AudioConverterRef converterRef;
			err = ExtAudioFileGetProperty(outputFileRef, kExtAudioFileProperty_AudioConverter, &size, &converterRef);
			
			UInt32 mode = exportSettings.mUseVBR ? kAudioCodecBitRateFormat_VBR : kAudioCodecBitRateFormat_CBR;
			err	= AudioConverterSetProperty(converterRef, kAudioCodecBitRateFormat, sizeof(mode), &mode);

			/*
			err	= AudioConverterGetPropertyInfo(converterRef, kAudioConverterApplicableEncodeBitRates, &size, NULL);
			AudioValueRange* bitRates = (AudioValueRange*) new char[size];
			err	= AudioConverterGetProperty(converterRef, kAudioConverterApplicableEncodeBitRates, &size, bitRates);
			if(err == noErr)
			{
				ssize_t bitRateCount = size / sizeof(AudioValueRange);
				for(int i = 0; i < bitRateCount; i++)
					NSLog(@"bitrate %d: %f/%f\n", i, bitRates[i].mMinimum, bitRates[i].mMaximum);

				delete[] bitRates;
			}			
			*/
			
			UInt32 bitRate = exportSettings.mBitRate * 1000;
			err = AudioConverterSetProperty(converterRef, kAudioConverterEncodeBitRate, sizeof(UInt32), &bitRate);
			
			UInt32 codecQuality = kAudioConverterQuality_Medium;
			int quality = exportSettings.mQuality * 4;
			switch (quality)
			{
				case 0:
					codecQuality = kAudioConverterQuality_Min;
					break;
				case 1:
					codecQuality = kAudioConverterQuality_Low;
					break;
				case 2:
					codecQuality = kAudioConverterQuality_Medium;
					break;
				case 3:
					codecQuality = kAudioConverterQuality_High;
					break;
				case 4:
					codecQuality = kAudioConverterQuality_Max;
					break;
			}

			err = AudioConverterSetProperty(converterRef, kAudioConverterCodecQuality, sizeof(UInt32), &codecQuality);
		}
		
		err = ExtAudioFileWriteAsync(outputFileRef, 0, NULL);
    }
    
	const int maxSamplesPerSlice = 64 * 1024;
	const int fadeTimeInSamples = exportSettings.mFadeOutTime * settings.mFrequency;

	AudioBufferList outputBufferList;
	UInt32 renderBufferSize = (maxSamplesPerSlice * inputFormat.mBytesPerFrame);
    char* renderBuffer = malloc(sizeof(char)*renderBufferSize);

    if (renderBuffer == nil)
        return;
	outputBufferList.mNumberBuffers = inputFormat.mChannelsPerFrame;
	outputBufferList.mBuffers[0].mData = renderBuffer;
	outputBufferList.mBuffers[0].mDataByteSize = renderBufferSize;
    // loop until stopped from an external event, or finished the entire extraction
	while (!exportStopped)
	{
        if (samplesRemaining == 0)
			break;

		// progress update
		NSNumber* progress = @((float)samplesCompleted / (float)(samplesCompleted + samplesRemaining));
		[self performSelectorOnMainThread:@selector(exportInProgressNotification:) withObject:progress waitUntilDone:NO];
		
		UInt32 numSamplesThisSlice = (int)samplesRemaining;
		if (numSamplesThisSlice > maxSamplesPerSlice)
			numSamplesThisSlice = maxSamplesPerSlice;

		// write it to the file
		if (numSamplesThisSlice > 0)
		{
            [player fillBuffer:outputBufferList.mBuffers[0].mData withLen:outputBufferList.mBuffers[0].mDataByteSize];
            
			if (exportSettings.mWithFadeOut && (samplesRemaining - numSamplesThisSlice) < fadeTimeInSamples)
			{
				short* sampleBuffer = (short*) renderBuffer;
				
				for(int i = 0; i < numSamplesThisSlice; i++)
				{
					if ((samplesRemaining - i) < fadeTimeInSamples)
					{
						float fadeOutFactor = (float)(samplesRemaining - i) / (float)(fadeTimeInSamples);
						short sample = fadeOutFactor * sampleBuffer[i];
						sampleBuffer[i] = sample;
					}
				}
			}

			err =  ExtAudioFileWriteAsync(outputFileRef, numSamplesThisSlice, &outputBufferList);
			if (err != noErr)
				break;
		}
		
		samplesRemaining -= numSamplesThisSlice;
		samplesCompleted += numSamplesThisSlice;
    }

	free(renderBuffer);
		
    if (outputFileRef != NULL)
		ExtAudioFileDispose(outputFileRef);
 	
	//NSLog(@"file written!\n");
	
	[self performSelectorOnMainThread:@selector(exportCompletedNotification:)
                                                withObject:(id)[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]
												waitUntilDone:NO];
	
}


// ----------------------------------------------------------------------------
- (void) exportUsingLameThread:(id)inObject
// ----------------------------------------------------------------------------
{
	[NSThread setThreadPriority:[NSThread threadPriority]+.1];

    OSStatus err = noErr;

	FILE* outputFileHandle = fopen(destinationPath.fileSystemRepresentation, "wb");

	NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:destinationPath];
	//[icon setScalesWhenResized:NO];
	icon.size = NSMakeSize(32, 32);
	[self performSelectorOnMainThread:@selector(setFileIcon:) withObject:icon waitUntilDone:NO];

	lame_global_flags *lameState;
	lameState = lame_init();
	lame_set_mode(lameState, MONO);
	lame_set_in_samplerate(lameState, settings.mFrequency);
	
	if (exportSettings.mUseVBR)
	{
		lame_set_VBR(lameState, vbr_default);
		lame_set_brate(lameState, exportSettings.mBitRate);		
	}
	else
	{
		lame_set_VBR(lameState, vbr_off);
		lame_set_brate(lameState, exportSettings.mBitRate);		
	}

	int lameQuality = (int) ((1.0f - exportSettings.mQuality) * 9.0f);
	lame_set_quality(lameState, lameQuality);

	id3tag_init(lameState);
	id3tag_add_v2(lameState);
	id3tag_set_title(lameState, [title cStringUsingEncoding:NSISOLatin1StringEncoding]);
	id3tag_set_artist(lameState, [author cStringUsingEncoding:NSISOLatin1StringEncoding]);

	if (releaseInfo.length > 3)
	{
		NSString* year = [releaseInfo substringWithRange:NSMakeRange(0, 4)];
		id3tag_set_year(lameState, [year cStringUsingEncoding:NSISOLatin1StringEncoding]);
	}
	
	id3tag_set_comment(lameState, "Exported with SIDPLAY/Mac");
	
	int rc = lame_init_params(lameState);

	const int maxSamplesPerSlice = 64 * 1024;
	const int fadeTimeInSamples = exportSettings.mFadeOutTime * settings.mFrequency;

	UInt32 renderBufferSize = (maxSamplesPerSlice * sizeof(short));
    
    char* renderBuffer = malloc(sizeof(char)*renderBufferSize);
    if (renderBuffer == nil)
        return;
    int mp3BufferSize = (int) (1.25f * maxSamplesPerSlice + 7200);
    
    unsigned char* mp3Buffer = malloc(sizeof(unsigned char)*mp3BufferSize);

	while (!exportStopped)
	{
        if (samplesRemaining == 0)
			break;

		// progress update
		NSNumber* progress = @((float)samplesCompleted / (float)(samplesCompleted + samplesRemaining));
		[self performSelectorOnMainThread:@selector(exportInProgressNotification:) withObject:progress waitUntilDone:NO];
		
		UInt32 numSamplesThisSlice = (int)samplesRemaining;
		if (numSamplesThisSlice > maxSamplesPerSlice)
			numSamplesThisSlice = maxSamplesPerSlice;

		// write it to the file
		if (numSamplesThisSlice > 0)
		{
            [player fillBuffer:renderBuffer withLen:renderBufferSize];

			if (exportSettings.mWithFadeOut && (samplesRemaining - numSamplesThisSlice) < fadeTimeInSamples)
			{
				short* sampleBuffer = (short*) renderBuffer;
				
				for(int i = 0; i < numSamplesThisSlice; i++)
				{
					if ((samplesRemaining - i) < fadeTimeInSamples)
					{
						float fadeOutFactor = (float)(samplesRemaining - i) / (float)(fadeTimeInSamples);
						short sample = fadeOutFactor * sampleBuffer[i];
						sampleBuffer[i] = sample;
					}
				}
			}

			rc = lame_encode_buffer(lameState, (short int*)renderBuffer, (short int*)renderBuffer, numSamplesThisSlice, mp3Buffer, mp3BufferSize);
			if (rc > 0)
				fwrite(mp3Buffer, 1, rc, outputFileHandle);
		}
		
		samplesRemaining -= numSamplesThisSlice;
		samplesCompleted += numSamplesThisSlice;
    }

	rc = lame_encode_flush(lameState, mp3Buffer, mp3BufferSize);
	fwrite(mp3Buffer, 1, rc, outputFileHandle);
	lame_close(lameState);

	free (renderBuffer);
	free (mp3Buffer);
		
    if (outputFileHandle != NULL)
		fclose(outputFileHandle);
 	
	//NSLog(@"file written using lame!\n");
	
	[self performSelectorOnMainThread:@selector(exportCompletedNotification:)
                                                withObject:(id)[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]
												waitUntilDone:NO];
	
}


// ----------------------------------------------------------------------------
- (void) exportCompletedNotification:(NSError *)error
// ----------------------------------------------------------------------------
{
	//NSLog(@"export stopped with error: %@\n", error);

	exportInProgress = NO;
	[self setExportStopped:YES];
	[controller exportFinished:self];
}


// ----------------------------------------------------------------------------
- (void) exportInProgressNotification:(id)progress
// ----------------------------------------------------------------------------
{
	[self setExportProgress:[progress floatValue]];
}


@end



@implementation SPExportItem

// ----------------------------------------------------------------------------
- (instancetype) init
// ----------------------------------------------------------------------------
{
    return [self initWithPath:nil andTitle:nil andAuthor:nil andSubtune:0 andLoopCount:0];
}
// ----------------------------------------------------------------------------
- (instancetype) initWithPath:(NSString*)filePath andTitle:(NSString*)titleString andAuthor:(NSString*)authorString andSubtune:(int)subtuneIndex andLoopCount:(int)loops
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		path = filePath;
		title = titleString;
		author = authorString;
		subtune = subtuneIndex;
		loopCount = loops;
		exporter = nil;
	}
	return self;
}


// ----------------------------------------------------------------------------
- (NSString*) path
// ----------------------------------------------------------------------------
{
	return path;
}


// ----------------------------------------------------------------------------
- (void) setPath:(NSString*)filePath
// ----------------------------------------------------------------------------
{
	path = filePath;
}


// ----------------------------------------------------------------------------
- (NSString*) title
// ----------------------------------------------------------------------------
{
	return title;
}


// ----------------------------------------------------------------------------
- (void) setTitle:(NSString*)titleString
// ----------------------------------------------------------------------------
{
	title = titleString;
}


// ----------------------------------------------------------------------------
- (NSString*) author
// ----------------------------------------------------------------------------
{
	return author;
}


// ----------------------------------------------------------------------------
- (void) setAuthor:(NSString*)authorString
// ----------------------------------------------------------------------------
{
	author = authorString;
}


// ----------------------------------------------------------------------------
- (int) subtune
// ----------------------------------------------------------------------------
{
	return subtune;
}


// ----------------------------------------------------------------------------
- (void) setSubtune:(int)subtuneIndex
// ----------------------------------------------------------------------------
{
	subtune = subtuneIndex;
}


// ----------------------------------------------------------------------------
- (int) loopCount
// ----------------------------------------------------------------------------
{
	return loopCount;
}


// ----------------------------------------------------------------------------
- (void) setLoopCount:(int)loops
// ----------------------------------------------------------------------------
{
	loopCount = loops;
}


// ----------------------------------------------------------------------------
- (SPExporter*) exporter
// ----------------------------------------------------------------------------
{
	return exporter;
}


// ----------------------------------------------------------------------------
- (void) setExporter:(SPExporter*)theExporter
// ----------------------------------------------------------------------------
{
	exporter = theExporter;
}
@end

@implementation ExportSettings
@synthesize     mFileType;
@synthesize         mTimeInSeconds;
@synthesize             mWithFadeOut;
@synthesize                 mFadeOutTime;
@synthesize                 mBitRate;
@synthesize             mUseVBR;
@synthesize             mQuality;

@synthesize             mBlankScreen;
@synthesize             mIncludeStilComment;
@synthesize             mCompressOutputFile;
- (id) init
{
    self = [super init];
    mTimeInSeconds = 180;
    mWithFadeOut = NO;
    mFadeOutTime = 3;
    mBitRate = 128;
    mUseVBR = NO;
    mQuality = 0.5f;

    mBlankScreen = NO;
    mIncludeStilComment = NO;
    mCompressOutputFile = NO;
    return self;
}
@end
