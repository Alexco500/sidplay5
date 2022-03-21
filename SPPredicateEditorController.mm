#import "SPPredicateEditorController.h"
#import "SPBrowserDataSource.h"
#import "SPPlayerWindow.h"
#import "SPPlaylist.h"
#import "SPSmartPlaylist.h"
#import "SPCollectionUtilities.h"


@implementation SPPredicateEditorController


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	predicateEditorVisible = NO;
	
	// Make the text field in the predicate editor a little wider
	NSArray* templates = [predicateEditor rowTemplates];
	NSPredicateEditorRowTemplate* rowTemplate = [templates objectAtIndex:1];
	NSArray* views = [rowTemplate templateViews];
	templateTextField = [views objectAtIndex:2];
	NSRect frame = [templateTextField frame];
	frame.size.width = 200.0f;
	[templateTextField setFrame:frame];
	[templateTextField setTag:6581];
	[templateTextField setContinuous:YES];
	[predicateEditor setContinuous:YES];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(predicateChangedNotification:)
												 name:NSControlTextDidChangeNotification
											   object:nil];
}


// ----------------------------------------------------------------------------
- (void) setPredicate:(NSPredicate*)predicate
// ----------------------------------------------------------------------------
{
	[predicateEditor setObjectValue:predicate];
	if ([predicateEditor numberOfRows] == 0)
		[predicateEditor addRow:self];
}


// ----------------------------------------------------------------------------
- (void) addPredicateEditorToWindow:(SPPlayerWindow*)window
// ----------------------------------------------------------------------------
{
	if (predicateEditorVisible)
		return;
	
	float height = [predicateEditor numberOfRows] * [predicateEditor rowHeight];
	[window addTopSubView:predicateEditor withHeight:height];
	
	predicateEditorVisible = YES;
}


// ----------------------------------------------------------------------------
- (void) removePredicateEditor
// ----------------------------------------------------------------------------
{
	if (!predicateEditorVisible)
		return;
	
	SPPlayerWindow* window = (SPPlayerWindow*) [predicateEditor window];
	[window removeTopSubView];
	[predicateEditor removeFromSuperview];
	
	predicateEditorVisible = NO;
}


// ----------------------------------------------------------------------------
- (IBAction) predicateEditorChanged:(id)sender
// ----------------------------------------------------------------------------
{
	NSPredicate* predicate = [predicateEditor objectValue];
	if (predicate != nil)
	{
		//NSLog(@"predicate: %@\n", predicate);

		[browserDataSource setInProgress:YES];
		
		SPSmartPlaylist* smartPlaylist = (SPSmartPlaylist*) [browserDataSource playlist];
		[smartPlaylist setPredicate:predicate];
		[smartPlaylist startSpotlightQuery:[[SPCollectionUtilities sharedInstance] rootPath]];
		[smartPlaylist saveToFile];
	}
}


// ----------------------------------------------------------------------------
- (void) predicateChangedNotification:(NSNotification*)notification
// ----------------------------------------------------------------------------
{
	if ([[notification object] tag] == 6581)
		[self predicateEditorChanged:predicateEditor];
}



#pragma mark -
#pragma mark predicate editor delegate methods


// ----------------------------------------------------------------------------
- (void) ruleEditorRowsDidChange:(NSNotification *)notification
// ----------------------------------------------------------------------------
{
	if (!predicateEditorVisible)
		return;

	SPPlayerWindow* window = (SPPlayerWindow*) [predicateEditor window];
	float height = [predicateEditor numberOfRows] * [predicateEditor rowHeight];
	[window addTopSubView:predicateEditor withHeight:height];
}


@end
