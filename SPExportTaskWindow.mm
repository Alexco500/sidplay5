#import "SPExportTaskWindow.h"
#import "SPExporter.h"


@implementation SPExportTaskWindow

// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[collectionView setMaxNumberOfColumns:1];
	[collectionView setMaxNumberOfRows:32768];
	[collectionView setBackgroundColors:[NSColor controlAlternatingRowBackgroundColors]];

	NSScrollView* scrollView = [collectionView enclosingScrollView];
	NSSize contentSize = [scrollView contentSize];
	const float minHeight = 54.0f;
	float width = contentSize.width;
	[collectionView setMaxItemSize:NSMakeSize(width, minHeight)];
	[collectionView setMinItemSize:NSMakeSize(width, minHeight)];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowDidResize:)
												 name:NSWindowDidResizeNotification
											   object:self];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowDidResize:)
												 name:NSSystemColorsDidChangeNotification
											   object:self];
}


// ----------------------------------------------------------------------------
- (void)systemColorsDidChange:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	[collectionView setBackgroundColors:[NSColor controlAlternatingRowBackgroundColors]];
}


// ----------------------------------------------------------------------------
- (void)windowDidResize:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	NSScrollView* scrollView = [collectionView enclosingScrollView];
	NSSize contentSize = [scrollView contentSize];
	
	const float minHeight = 54.0f;
	float width = contentSize.width;

	[collectionView setMaxItemSize:NSMakeSize(width, minHeight)];
	[collectionView setMinItemSize:NSMakeSize(width, minHeight)];
}



@end
