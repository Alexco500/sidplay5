#import "SPExportController.h"
#import "SPExportOptionsPanel.h"
#import "SPPlayerWindow.h"
#import "SPPreferencesController.h"
#import "SPExportTaskWindow.h"


@implementation SPExportController


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	currentExportPanel = nil;
	itemsToExport = nil;
	exportDirectoryPath = nil;
	NSProcessInfo* processInfo = [NSProcessInfo processInfo];
	numberOfConcurrentExportTasks = MIN(8, [processInfo activeProcessorCount]);
	
	exportSettings.Init();
}


// ----------------------------------------------------------------------------
- (void) exportFile:(SPExportItem*)item withType:(ExportFileType)type
// ----------------------------------------------------------------------------
{
	exportSettings.mFileType = type;
	
	itemsToExport = [NSArray arrayWithObject:item];
	SPExporter* exporter = [[SPExporter alloc] initWithItem:item withController:self andWindow:ownerWindow loadNow:YES];
	if (exporter == nil)
		return;
		
	[item setExporter:exporter];
	exportSettings = [exporter exportSettings];
	
	if (type == EXPORT_TYPE_PRG)
		currentExportPanel = exportPrgFilePanel;
	else if ([self isCompressedFileType:type])
		currentExportPanel = exportCompressedFilePanel;
	else
		currentExportPanel = exportFilePanel;
	
	[currentExportPanel setExportController:self];
	
	[NSApp beginSheet:(NSWindow*)currentExportPanel modalForWindow:(NSWindow*)ownerWindow modalDelegate:self didEndSelector:@selector(didEndExportSheet:returnCode:contextInfo:) contextInfo:NULL];
}


// ----------------------------------------------------------------------------
- (void) exportFiles:(NSMutableArray*)items withType:(ExportFileType)type
// ----------------------------------------------------------------------------
{
	exportSettings.mFileType = type;

	itemsToExport = [NSArray arrayWithArray:items];
	
	if (type == EXPORT_TYPE_PRG)
		currentExportPanel = exportMultiplePrgFilesPanel;
	else if ([self isCompressedFileType:type])
		currentExportPanel = exportMultipleCompressedFilesPanel;
	else
		currentExportPanel = exportMultipleFilesPanel;

	[currentExportPanel setExportController:self];
	[currentExportPanel updateFileListTextView:items];

	[NSApp beginSheet:(NSWindow*)currentExportPanel modalForWindow:(NSWindow*)ownerWindow modalDelegate:self didEndSelector:@selector(didEndExportSheet:returnCode:contextInfo:) contextInfo:NULL];
}


// ----------------------------------------------------------------------------
- (IBAction) cancelExportSheet:(id)sender
// ----------------------------------------------------------------------------
{
	[NSApp endSheet:(NSWindow*)currentExportPanel returnCode:NSModalResponseCancel];
}


// ----------------------------------------------------------------------------
- (IBAction) confirmExportSheet:(id)sender
// ----------------------------------------------------------------------------
{
	[currentExportPanel timeChanged:nil];
	[NSApp endSheet:(NSWindow*)currentExportPanel returnCode:NSModalResponseOK];
}


// ----------------------------------------------------------------------------
- (void) didEndExportSheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
// ----------------------------------------------------------------------------
{
    [sheet orderOut:self];
	
	exportSettings = [currentExportPanel exportSettings];
	currentExportPanel = nil;

	if (returnCode == NSModalResponseOK)
	{
		if ([itemsToExport count] == 1)
			[self selectDestinationFilename];
		else
			[self selectDestinationDirectory];
	}
}


// ----------------------------------------------------------------------------
- (BOOL) isCompressedFileType:(ExportFileType)type
// ----------------------------------------------------------------------------
{
	switch (type)
	{
		case EXPORT_TYPE_MP3:
		case EXPORT_TYPE_AAC:
			return YES;
			break;
			
		case EXPORT_TYPE_ALAC:
		case EXPORT_TYPE_AIFF:
		default:
			return NO;
			break;
	}
}


// ----------------------------------------------------------------------------
- (int) calculateExpectedFileSizeForSettings:(ExportSettings*)settings
// ----------------------------------------------------------------------------
{
	int fileSize = 0;
	
	switch(settings->mFileType)
	{
		case EXPORT_TYPE_MP3:
			if (settings->mUseVBR)
				fileSize = -1;
			else
				fileSize = settings->mTimeInSeconds * settings->mBitRate * 1000 / 8;
			break;
			
		case EXPORT_TYPE_AAC:
			if (settings->mUseVBR)
				fileSize = -1;
			else
				fileSize = settings->mTimeInSeconds * settings->mBitRate * 1000 / 8;
			break;
			
		case EXPORT_TYPE_ALAC:
			fileSize = -1;
			break;
			
		case EXPORT_TYPE_AIFF:
			fileSize = settings->mTimeInSeconds * gPreferences.mPlaybackSettings.mFrequency * sizeof(short); 
			break;
			
		default:
			break;
	}
	
	return fileSize;
}


// ----------------------------------------------------------------------------
- (void) selectDestinationFilename
// ----------------------------------------------------------------------------
{
	SPExporter* exporter = [[itemsToExport objectAtIndex:0] exporter];
	NSString* suggestedFilename = [exporter suggestedFilename];
	NSString* suggestedExtension = [exporter suggestedFileExtension]; 

	NSSavePanel* savePanel = [NSSavePanel savePanel];
    [savePanel setNameFieldStringValue:suggestedFilename];
    savePanel.allowedFileTypes = [NSArray arrayWithObject:suggestedExtension];
	[savePanel setCanSelectHiddenExtension:YES];
	
    [savePanel beginSheetModalForWindow:ownerWindow completionHandler:^(NSInteger result)
    {
        if (result == NSFileHandlingPanelOKButton)
        {
            [exportTaskWindow orderFront:self];
            
            SPExporter* exporter = [[itemsToExport objectAtIndex:0] exporter];
            [exporter setExportSettings:exportSettings];
            [exporter setDestinationPath:[savePanel.URL path]];
            [exporterArray addObject:exporter];
            [self updateExporterState];
        }
    }
    ];
}


// ----------------------------------------------------------------------------
- (void) selectDestinationDirectory
// ----------------------------------------------------------------------------
{
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	openPanel.allowedFileTypes = [NSArray arrayWithObject:@""];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:NO];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setTitle:@"Select export destination"];
	[openPanel setPrompt:@"Choose"];

    [openPanel beginSheetModalForWindow:ownerWindow completionHandler:^(NSInteger result)
     {
         if (result == NSFileHandlingPanelOKButton)
         {
             [exportTaskWindow orderFront:self];
             
             NSMutableArray* exportersToAdd = [NSMutableArray arrayWithCapacity:[itemsToExport count]];
             
             for (SPExportItem* item in itemsToExport)
             {
                 //NSLog(@"Adding exporter for %@\n", [item path]);
                 
                 SPExporter* exporter = [[SPExporter alloc] initWithItem:item withController:self andWindow:ownerWindow loadNow:NO];
                 if (exporter == nil)
                     continue;
                 
                 [item setExporter:exporter];
                 [exporter setExportSettings:exportSettings];
                 
                 exportDirectoryPath = [openPanel.URL path];
                 
                 [exporter setFileName:[exporter suggestedFilename]];
                 [exportersToAdd addObject:exporter];
             }
             
             [exporterArray addObjects:exportersToAdd];
             [self updateExporterState];
         }
     }
     ];
}



// ----------------------------------------------------------------------------
- (void) exportFinished:(SPExporter*)exporter
// ----------------------------------------------------------------------------
{
	[self updateExporterState];
}


// ----------------------------------------------------------------------------
- (void) updateExporterState
// ----------------------------------------------------------------------------
{
	int exportersInProgress = 0;
	
	for (SPExporter* exporter in [exporterArray arrangedObjects])
	{
		if ([exporter exportInProgress])
			exportersInProgress++;
	}

	if (exportersInProgress < numberOfConcurrentExportTasks)
	{
		int exportersToStart = numberOfConcurrentExportTasks - exportersInProgress;
		for (SPExporter* exporter in [exporterArray arrangedObjects])
		{
			if (![exporter exportInProgress] && ![exporter exportStopped])
			{
				if ([exporter loadExportItem])
					[exporter determineExportFilePath:exportDirectoryPath];

				[exporter startExport];
				exportersToStart--;
			}
			
			if (exportersToStart == 0)
				break;
		}
	}

	exportersInProgress = 0;
	
	for (SPExporter* exporter in [exporterArray arrangedObjects])
	{
		if ([exporter exportInProgress])
			exportersInProgress++;
	}
}


// ----------------------------------------------------------------------------
- (void) setOwnerWindow:(SPPlayerWindow*)window
// ----------------------------------------------------------------------------
{
	ownerWindow = window;
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowWillClose:)
												 name:NSWindowWillCloseNotification
											   object:exportTaskWindow];
}


// ----------------------------------------------------------------------------
- (ExportSettings) exportSettings
// ----------------------------------------------------------------------------
{
	return exportSettings;
}


// ----------------------------------------------------------------------------
- (void) setExportSettings:(ExportSettings)settings
// ----------------------------------------------------------------------------
{
	exportSettings = settings;
}


// ----------------------------------------------------------------------------
- (NSArray*) itemsToExport
// ----------------------------------------------------------------------------
{
	return itemsToExport;
}


// ----------------------------------------------------------------------------
- (void) windowWillClose:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	[[ownerWindow exportTaskWindowMenuItem] setTitle:@"Show Export Tasks"];
}	


// ----------------------------------------------------------------------------
- (NSInteger) activeExportTasksCount
// ----------------------------------------------------------------------------
{
	NSInteger count = 0;
	
	for (SPExporter* exporter in [exporterArray arrangedObjects])
	{
		if (![exporter exportStopped])
			count++;
	}

	return count;
}


// ----------------------------------------------------------------------------
- (IBAction) toggleExportTasksWindow:(id)sender
// ----------------------------------------------------------------------------
{
	if ([exportTaskWindow isVisible])
	{
		[sender setTitle:@"Show Export Tasks"];
		[exportTaskWindow orderOut:sender];
	}
	else
	{
		[sender setTitle:@"Hide Export Tasks"];
		[exportTaskWindow orderFront:sender];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) clearExportTasksButtonClicked:(id)sender
// ----------------------------------------------------------------------------
{
	NSMutableArray* exportersToRemove = [NSMutableArray arrayWithCapacity:10];
	for (SPExporter* exporter in [exporterArray arrangedObjects])
	{
		if ([exporter exportStopped])
			[exportersToRemove addObject:exporter];
	}

	[exporterArray removeObjects:exportersToRemove];

	[self updateExporterState];
}


// ----------------------------------------------------------------------------
- (IBAction) numberOfConcurrentExportTasksChanged:(id)sender
// ----------------------------------------------------------------------------
{
	[exportTasksCount setIntValue:[sender intValue]];
	numberOfConcurrentExportTasks = [sender intValue]; 
	[self updateExporterState];
}

@end
