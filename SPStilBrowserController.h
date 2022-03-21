#import <Cocoa/Cocoa.h>


@class SPPlayerWindow;

@interface SPStilBrowserController : NSWindowController <NSAnimationDelegate>
{
	SPPlayerWindow* ownerWindow;
	NSString* stilDatabasePath;
	NSMutableDictionary* indexedStilDatabase;
	BOOL indexingInProgress;
	BOOL stilDataBaseValid;
	NSViewAnimation* animation;
	NSString* currentPath;
	BOOL cancelSearch;
	BOOL searchInProgress;
	NSString* currentSearchString;

	IBOutlet NSTextView* textView;
	IBOutlet NSSearchField* searchField;
	IBOutlet NSTextField* databasePathTextField;
}

+ (SPStilBrowserController*) sharedInstance;

- (void) toggleWindow:(id)sender;
- (void) setOwnerWindow:(SPPlayerWindow*)window;
- (void) setCollectionRootPath:(NSString*)rootPath;
- (void) indexStilFromPath:(NSString*)path;
- (void) indexingFinished:(id)object;

- (void) displayEntryForRelativePath:(NSString*)relativePath;
- (void) displaySharedCollectionMessage;

- (NSSearchField*) searchField;

- (void) searchForEntryThread:(id)object;
- (void) updateSearchResult:(id)object;

- (IBAction) searchStringEntered:(id)sender;

@end


@interface SPBrowserPanel : NSPanel
{

}

@end


@interface SPBrowserTextView : NSTextView
{

}

+ (NSCursor*) fingerCursor;

@end
