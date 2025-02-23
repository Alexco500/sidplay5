#import <Cocoa/Cocoa.h>
#import "SPExporter.h"

@class SPExportOptionsPanel;
@class SPPlayerWindow;
@class SPExportTaskWindow;


@interface SPExportController : NSObject
{
	SPExportOptionsPanel* currentExportPanel;
	SPPlayerWindow* ownerWindow;

	ExportSettings* exportSettings;
	NSArray* itemsToExport;
	NSString* exportDirectoryPath;
	int numberOfConcurrentExportTasks;
	
	IBOutlet SPExportOptionsPanel* exportFilePanel;
	IBOutlet SPExportOptionsPanel* exportCompressedFilePanel;
	IBOutlet SPExportOptionsPanel* exportMultipleFilesPanel;
	IBOutlet SPExportOptionsPanel* exportMultipleCompressedFilesPanel;
	IBOutlet SPExportOptionsPanel* exportPrgFilePanel;
	IBOutlet SPExportOptionsPanel* exportMultiplePrgFilesPanel;
	IBOutlet NSArrayController *exporterArray;
	IBOutlet SPExportTaskWindow* exportTaskWindow;
	IBOutlet NSTextField* exportTasksCount;
}

- (void) exportFile:(SPExportItem*)item withType:(enum ExportFileType)type;
- (void) exportFiles:(NSMutableArray*)items withType:(enum ExportFileType)type;
- (void) selectDestinationFilename;
- (void) selectDestinationDirectory;

- (IBAction) cancelExportSheet:(id)sender;
- (IBAction) confirmExportSheet:(id)sender;
- (void) exportFinished:(SPExporter*)exporter;

- (void) updateExporterState;

- (BOOL) isCompressedFileType:(enum ExportFileType)type;
- (int) calculateExpectedFileSizeForSettings:(ExportSettings*)settings;

- (void) setOwnerWindow:(SPPlayerWindow*)window;

@property (NS_NONATOMIC_IOSONLY) ExportSettings* exportSettings;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *itemsToExport;

@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger activeExportTasksCount;

- (IBAction) toggleExportTasksWindow:(id)sender;

- (IBAction) clearExportTasksButtonClicked:(id)sender;
- (IBAction) numberOfConcurrentExportTasksChanged:(id)sender;


@end
