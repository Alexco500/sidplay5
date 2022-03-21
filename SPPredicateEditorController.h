#import <Cocoa/Cocoa.h>

@class SPBrowserDataSource;
@class SPPlayerWindow;

@interface SPPredicateEditorController : NSObject
{
	IBOutlet NSPredicateEditor* predicateEditor;
	//IBOutlet NSScrollView* predicateEditorScrollView;
	IBOutlet SPBrowserDataSource* browserDataSource;
	NSTextField* templateTextField;
	
	BOOL predicateEditorVisible;
}

- (void) setPredicate:(NSPredicate*)predicate;
- (void) addPredicateEditorToWindow:(SPPlayerWindow*)window;
- (void) removePredicateEditor;

- (IBAction) predicateEditorChanged:(id)sender;

- (void) predicateChangedNotification:(NSNotification*)notification;

@end
