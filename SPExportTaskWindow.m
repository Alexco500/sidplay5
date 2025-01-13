#import "SPExportTaskWindow.h"
#import "SPExporter.h"


@implementation SPExportTaskWindow

// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	collectionView.maxNumberOfColumns = 1;
	collectionView.maxNumberOfRows = 32768;
	collectionView.backgroundColors = [NSColor controlAlternatingRowBackgroundColors];

	NSScrollView* scrollView = collectionView.enclosingScrollView;
	NSSize contentSize = scrollView.contentSize;
	const float minHeight = 54.0f;
	float width = contentSize.width;
	collectionView.maxItemSize = NSMakeSize(width, minHeight);
	collectionView.minItemSize = NSMakeSize(width, minHeight);

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
	collectionView.backgroundColors = [NSColor controlAlternatingRowBackgroundColors];
}


// ----------------------------------------------------------------------------
- (void)windowDidResize:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	NSScrollView* scrollView = collectionView.enclosingScrollView;
	NSSize contentSize = scrollView.contentSize;
	
	const float minHeight = 54.0f;
	float width = contentSize.width;

	collectionView.maxItemSize = NSMakeSize(width, minHeight);
	collectionView.minItemSize = NSMakeSize(width, minHeight);
}



@end
