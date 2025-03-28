#import "SPExportOptionsPanel.h"
#import "SPExporter.h"
#import "SPExportController.h"


@implementation SPExportOptionsPanel


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(timeChangedNotification:)
												 name:NSControlTextDidChangeNotification
											   object:nil];
}


// ----------------------------------------------------------------------------
- (SPExportController*) exportController
// ----------------------------------------------------------------------------
{
	return exportController;
}


// ----------------------------------------------------------------------------
- (void) setExportController:(SPExportController*)controller
// ----------------------------------------------------------------------------
{
	exportController = controller;
	exportSettings = [exportController exportSettings];
	
	timeStepper.integerValue = exportSettings.mTimeInSeconds;
	[self updateTimeTextField:(int)exportSettings.mTimeInSeconds];
	
	exportSettings.mWithFadeOut = fadeOutButton.state == NSOnState;
	exportSettings.mFadeOutTime = fadeOutTimeSlider.intValue;
	fadeOutTimeSlider.enabled = exportSettings.mWithFadeOut;

	int bitrate =(int)bitRatePopup.selectedItem.tag;
	exportSettings.mBitRate = bitrate;
	exportSettings.mUseVBR = variableBitrateButton.state == NSOnState;
	exportSettings.mQuality = qualitySlider.floatValue;
	
	[self updateFileSizeTextField];
	mp3InfoText.hidden = exportSettings.mFileType != EXPORT_TYPE_MP3;
	
	exportSettings.mBlankScreen = blankScreenButton.state == NSOnState;
	exportSettings.mIncludeStilComment = includeStilCommentButton.state == NSOnState;
	exportSettings.mCompressOutputFile = useCompressionButton.state == NSOnState;
	
	NSArray* itemsToExport = [exportController itemsToExport];
	if (itemsToExport.count == 1)
	{
		NSUInteger subTuneCount = 1;
		NSUInteger defaultSubTune = 1;

		SPExportItem* item = itemsToExport[0];
		if (item != nil)
		{
			SPExporter* exporter = [item exporter];
			if (exporter != nil)
			{
                PlayerLibSidplayWrapper* player = [exporter player];
				if (player != NULL)
				{
                    subTuneCount = [player getSubtuneCount];
					defaultSubTune = [player getDefaultSubtune];
				}
			}
		}
		
		[subTunePopup removeAllItems];
		for (NSUInteger i = 1; i < (subTuneCount + 1); i++)
		{
			if (i == defaultSubTune)
				[subTunePopup addItemWithTitle:[NSString stringWithFormat:@"%lu (default)", (unsigned long)i]];
			else
				[subTunePopup addItemWithTitle:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
			
			[subTunePopup itemAtIndex:i - 1].tag = i;
		}
		
		int subtuneToExport = [item subtune];
		if (subtuneToExport == 0)
			subtuneToExport = (int)defaultSubTune;
		
		[subTunePopup selectItemWithTag:subtuneToExport];
	}
}


// ----------------------------------------------------------------------------
- (ExportSettings*) exportSettings
// ----------------------------------------------------------------------------
{
	return exportSettings;
}


// ----------------------------------------------------------------------------
- (void) updateTimeTextField:(int)timeInSeconds
// ----------------------------------------------------------------------------
{
	int minutes = timeInSeconds / 60;
	int seconds = timeInSeconds - (minutes * 60);
	
	if (minutes > 99)
		minutes = 99;

	if (seconds > 59)
		seconds = 59;
	
	timeTextField.stringValue = [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];
}


// ----------------------------------------------------------------------------
- (void) updateFileSizeTextField
// ----------------------------------------------------------------------------
{
	int fileSize = [exportController calculateExpectedFileSizeForSettings:exportSettings];
	
	NSString* fileSizeText = nil;
	
	if (fileSize == -1)
		fileSizeText = @"(resulting file size: unknown)";
	else if (fileSize > (1024 * 1024))
		fileSizeText = [NSString stringWithFormat:@"(resulting file size: %.1f M)", (float) fileSize / (1024.0f * 1024.0f)];
	else
		fileSizeText = [NSString stringWithFormat:@"(resulting file size: %d K)", fileSize / 1024];
	
	fileSizeLabel.stringValue = fileSizeText;
}


// ----------------------------------------------------------------------------
- (void) updateFileListTextView:(NSArray*)exportItems
// ----------------------------------------------------------------------------
{
	NSString* filenameList = @"";
	
	for (SPExportItem* item in exportItems)
	{
		if ([item subtune] == 0)
			filenameList = [filenameList stringByAppendingFormat:@"%@ (NOT FOUND!)\n", [item path]];
		else
			filenameList = [filenameList stringByAppendingFormat:@"%@ (song: %d)\n", [item path], [item subtune]];
	}

	exportFilesTextView.string = filenameList;
	exportFilesTextView.font = [NSFont systemFontOfSize:10.0f];
}


// ----------------------------------------------------------------------------
- (IBAction) clickTimeStepper:(id)sender
// ----------------------------------------------------------------------------
{
	NSInteger timeInSeconds = [sender integerValue];
	exportSettings.mTimeInSeconds = timeInSeconds;
	[self updateTimeTextField:(int)timeInSeconds];
	[self updateFileSizeTextField];
}


// ----------------------------------------------------------------------------
- (void) timeChangedNotification:(NSNotification*)notification
// ----------------------------------------------------------------------------
{
	if (notification.object == timeTextField)
		[self timeChanged:timeTextField];
}


// ----------------------------------------------------------------------------
- (IBAction) timeChanged:(id)sender
// ----------------------------------------------------------------------------
{
	NSTextField* textField = sender != nil ? sender : timeTextField;
	
	NSString* timeString = textField.stringValue;
    // fixes export length issue
	if (timeString.length > 1)
	{
        NSArray *timeArray = [timeString componentsSeparatedByString:@":"];
        int cnt = (int) [timeArray count];
        NSString* minutesString;
        NSString* secondsString;
        int minutes = 0, seconds = 0;
        switch (cnt) {
            case 2:
                minutesString = [timeArray objectAtIndex:0];
                secondsString = [timeArray objectAtIndex:1];
                minutes = minutesString.intValue;
                seconds = secondsString.intValue;
                break;
            default:
                minutes = 0;
                seconds = 0;
                break;
        }
		NSUInteger timeInSeconds = minutes * 60 + seconds;
		exportSettings.mTimeInSeconds = timeInSeconds;
		timeStepper.integerValue = timeInSeconds;
		[self updateFileSizeTextField];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) subTunePopupChanged:(id)sender
// ----------------------------------------------------------------------------
{
	NSInteger subTuneIndex = [sender selectedItem].tag;
	
	NSArray* itemsToExport = [exportController itemsToExport];
	if (itemsToExport.count == 1)
	{
		SPExportItem* item = itemsToExport[0];
		if (item != nil)
		{
			SPExporter* exporter = [item exporter];
			[item setSubtune:(int)subTuneIndex];
			[exporter unloadExportItem];
			[exporter loadExportItem];
			exportSettings.mTimeInSeconds = [exporter exportSettings].mTimeInSeconds;
			[exportController setExportSettings:exportSettings];
			
			timeStepper.integerValue = exportSettings.mTimeInSeconds;
			[self updateTimeTextField:(int)exportSettings.mTimeInSeconds];
			[self updateFileSizeTextField];
		}
	}
}


// ----------------------------------------------------------------------------
- (IBAction) fadeOutButtonClicked:(id)sender
// ----------------------------------------------------------------------------
{
	exportSettings.mWithFadeOut = [sender state] == NSOnState;
	fadeOutTimeSlider.enabled = exportSettings.mWithFadeOut;
}


// ----------------------------------------------------------------------------
- (IBAction) fadeOutTimeChanged:(id)sender
// ----------------------------------------------------------------------------
{
	exportSettings.mFadeOutTime = [sender intValue];
}


// ----------------------------------------------------------------------------
- (IBAction) bitRatePopupChanged:(id)sender
// ----------------------------------------------------------------------------
{
	exportSettings.mBitRate = (int)[sender selectedItem].tag;
	[self updateFileSizeTextField];
}


// ----------------------------------------------------------------------------
- (IBAction) variableBitrateButtonClicked:(id)sender
// ----------------------------------------------------------------------------
{
	exportSettings.mUseVBR = [sender state] == NSOnState;
	[self updateFileSizeTextField];
}


// ----------------------------------------------------------------------------
- (IBAction) qualitySliderMoved:(id)sender
// ----------------------------------------------------------------------------
{
	exportSettings.mQuality = [sender floatValue];
}


// ----------------------------------------------------------------------------
- (IBAction) stilCommentButtonClicked:(id)sender
// ----------------------------------------------------------------------------
{
	exportSettings.mIncludeStilComment = [sender state] == NSOnState;
}


// ----------------------------------------------------------------------------
- (IBAction) blankScreenButtonClicked:(id)sender
// ----------------------------------------------------------------------------
{
	exportSettings.mBlankScreen = [sender state] == NSOnState;
}


// ----------------------------------------------------------------------------
- (IBAction) compressionButtonClicked:(id)sender
// ----------------------------------------------------------------------------
{
	exportSettings.mCompressOutputFile = [sender state] == NSOnState;
}


@end
