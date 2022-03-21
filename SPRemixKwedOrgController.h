#import <Cocoa/Cocoa.h>


#define REMIX_RATING_COUNT 7

@interface SPRemixKwedOrgController : NSObject
{
	BOOL databaseAvailable;
	NSMutableDictionary* remixKwedOrgDatabase;
	NSMutableData* databaseDownloadData;
	NSURLConnection* databaseDownloadConnection;
	NSMutableArray* foundRemixes;
	NSWindow* ownerWindow;
	NSImage* ratingImages[REMIX_RATING_COUNT];
	
	IBOutlet NSPanel* remixSelectionPanel;
	IBOutlet NSTextField* remixSelectionCaption;
	IBOutlet NSTableView* remixTableView;
}

- (void) acquireDatabase;
- (void) setOwnerWindow:(NSWindow*)owner;
- (void) findRemixesForHvscPath:(NSString*)path withTitle:(NSString*)title;

- (IBAction) cancelRemixSheet:(id)sender;
- (IBAction) confirmRemixSheet:(id)sender;
- (IBAction) showRemix64Page:(id)sender;

@end


@interface SPRemixKwedOrgDatabaseEntry : NSObject
{
}

@property (assign) NSInteger identifier;
@property (strong) NSString* hvscPath;
@property (assign) NSInteger subtuneIndex;
@property (strong) NSString* title;
@property (strong) NSString* arranger;
@property (assign) NSInteger rating;

@end

