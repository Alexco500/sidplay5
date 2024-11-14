#import "SPCollectionUtilities.h"
#import "SPRemixKwedOrgController.h"

extern NSString* SPUrlRequestUserAgentString;

@implementation SPRemixKwedOrgController


static NSString* SPRemixKwedOrgDatabaseDumpUrl = @"http://www.sidmusic.org/rko_database.txt";

// ----------------------------------------------------------------------------
- (id) init
{
    self = [super init];
    if (self != nil)
    {
        databaseAvailable = NO;
        databaseDownloadData = nil;
        databaseDownloadSession = nil;
        remixKwedOrgDatabase = nil;
        foundRemixes = nil;
        
        for (int i = 0; i < REMIX_RATING_COUNT; i++)
        {
            ratingImages[i] = [NSImage imageNamed:[NSString stringWithFormat:@"remixRating%d", i]];
        }
    }
    return self;
}

// ----------------------------------------------------------------------------
- (void) dealloc
{
    // changed finalize back to dealloc
    if (databaseDownloadSession != nil)
    {
        [databaseDownloadSession invalidateAndCancel];
        databaseDownloadSession = nil;
    }
    
}

// ----------------------------------------------------------------------------
- (void) acquireDatabase
{
    remixKwedOrgDatabase = [[NSMutableDictionary alloc] initWithCapacity:1000];
    databaseAvailable = NO;
    
    NSURL* url = [NSURL URLWithString:SPRemixKwedOrgDatabaseDumpUrl];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    [request setValue:SPUrlRequestUserAgentString forHTTPHeaderField:@"User-Agent"];
    databaseDownloadData = [NSMutableData data];
    // moved from NSURLConnection to NSURLSession, according to
    // https://www.objc.io/issues/5-ios7/from-nsurlconnection-to-nsurlsession/
    databaseDownloadSession = [NSURLSession sharedSession];
    NSURLSessionDataTask *dwnTask = [databaseDownloadSession dataTaskWithRequest:request
                                                               completionHandler:
                                     ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
        } else {
            [self->databaseDownloadData appendData:data];
            [self connectionDidFinishLoading];
        }
    }];
    
    [dwnTask resume];
}

// ----------------------------------------------------------------------------
- (void) setOwnerWindow:(NSWindow*)owner
{
    ownerWindow = owner;
}

// ----------------------------------------------------------------------------
- (void) findRemixesForHvscPath:(NSString*)path withTitle:(NSString*)title
{
    if (databaseAvailable)
    {
        NSString* properPath = path;
        if ([properPath characterAtIndex:0] == '/')
            properPath = [path stringByRemovingPrefix:@"/"];
        foundRemixes = remixKwedOrgDatabase[properPath];
        
        if (foundRemixes.count > 0)
        {
            remixSelectionCaption.stringValue = [NSString stringWithFormat:@"Remixes of '%@' at Remix.Kwed.Org:", title];
            
            remixTableView.doubleAction = @selector(confirmRemixSheet:);
            remixTableView.target = self;
            
            NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"rating" ascending:NO selector:@selector(compare:)];
            remixTableView.sortDescriptors = @[sortDescriptor];
            [foundRemixes sortUsingDescriptors:remixTableView.sortDescriptors];
            
            [remixTableView reloadData];
            
            [ownerWindow beginSheet:remixSelectionPanel
                  completionHandler:^(NSModalResponse returnCode) {
                [self didEndRemixSheetWithReturnCode: returnCode];
            }
            ];
        }
        else
        {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"No remixes found"];
            [alert setInformativeText:@"There are no remixes of this tune available from http://remix.kwed.org/."];
            [alert setAlertStyle:NSAlertStyleInformational]; // or NSAlertStyleWarning, or NSAlertStyleCritical
            [alert addButtonWithTitle:@"OK"];
            
            [alert runModal];
        }
    }
    else
    {
        foundRemixes = nil;
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"No remix database available"];
        [alert setInformativeText:@"The remix database could not be downloaded, please try again later."];
        [alert setAlertStyle:NSAlertStyleInformational]; // or NSAlertStyleWarning, or NSAlertStyleCritical
        [alert addButtonWithTitle:@"OK"];
        
        [alert runModal];
    }
}
// ----------------------------------------------------------------------------
- (void) didEndRemixSheetWithReturnCode:(long)returnCode
{
    if (returnCode == NSModalResponseOK)
    {
        NSInteger selectedRow = remixTableView.selectedRow;
        if (foundRemixes != nil)
        {
            SPRemixKwedOrgDatabaseEntry* remix = foundRemixes[selectedRow];
            if (remix != nil)
            {
                NSString* rkoUrlString = [NSString stringWithFormat:@"http://remix.kwed.org/?search_id=%ld", (long)remix.identifier];
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:rkoUrlString]];
            }
        }
    }
}

#pragma mark Download complete
// ----------------------------------------------------------------------------
- (void)connectionDidFinishLoading
{
    NSString* escapedRkoDatabaseString = [[NSString alloc] initWithData:databaseDownloadData encoding:NSISOLatin1StringEncoding];
    NSString* rkoDatabaseString = [escapedRkoDatabaseString stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    NSArray* rkoDatabaseLines = [rkoDatabaseString componentsSeparatedByString:@"\n"];
    
    for (NSString* rkoDatabaseLine in rkoDatabaseLines)
    {
        NSArray* rkoDatabaseLineComponents = [rkoDatabaseLine componentsSeparatedByString:@"\t"];
        
        SPRemixKwedOrgDatabaseEntry* entry = [[SPRemixKwedOrgDatabaseEntry alloc] init];
        
        if (rkoDatabaseLineComponents.count == 6)
        {
            entry.identifier = [rkoDatabaseLineComponents[0] integerValue];
            entry.hvscPath = rkoDatabaseLineComponents[1];
            entry.subtuneIndex = [rkoDatabaseLineComponents[2] integerValue];
            entry.title = rkoDatabaseLineComponents[3];
            entry.arranger = rkoDatabaseLineComponents[4];
            entry.rating = [rkoDatabaseLineComponents[5] integerValue];
            
            NSMutableArray* remixArray = remixKwedOrgDatabase[entry.hvscPath];
            if (remixArray != nil)
                [remixArray addObject:entry];
            else
            {
                remixArray = [[NSMutableArray alloc] initWithObjects:entry, nil];
                remixKwedOrgDatabase[entry.hvscPath] = remixArray;
            }
        }
    }
    
    databaseAvailable = remixKwedOrgDatabase.count > 0;
    
    databaseDownloadData = nil;
    databaseDownloadSession = nil;
}

#pragma mark UBAction methods
// ----------------------------------------------------------------------------
- (IBAction) cancelRemixSheet:(id)sender
{
    [NSApp endSheet:(NSWindow*)remixSelectionPanel returnCode:NSModalResponseCancel];
}

// ----------------------------------------------------------------------------
- (IBAction) confirmRemixSheet:(id)sender
{
    if (sender == remixTableView && remixTableView.clickedRow == -1)
        return;
    
    [NSApp endSheet:(NSWindow*)remixSelectionPanel returnCode:NSModalResponseOK];
}

// ----------------------------------------------------------------------------
- (IBAction) showRemix64Page:(id)sender
{
    NSInteger selectedRow = remixTableView.selectedRow;
    if (foundRemixes != nil)
    {
        SPRemixKwedOrgDatabaseEntry* remix = foundRemixes[selectedRow];
        if (remix != nil)
        {
            NSString* remix64UrlString = [NSString stringWithFormat:@"https://www.remix64.com/voting/gb/box/?id=%ld00", (long)remix.identifier];
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:remix64UrlString]];
        }
    }
}
#pragma mark -
#pragma mark data source methods
// ----------------------------------------------------------------------------
- (int)numberOfRowsInTableView:(NSTableView*)tableView
{
    if (foundRemixes == nil)
        return 0;
    else
        return (int)foundRemixes.count;
}

// ----------------------------------------------------------------------------
- (id)tableView:(NSTableView*)tableView objectValueForTableColumn:(NSTableColumn*)tableColumn row:(int)index
{
    if (foundRemixes == nil)
        return @"";
    
    SPRemixKwedOrgDatabaseEntry* remix = foundRemixes[index];
    
    if ([tableColumn.identifier isEqualToString:@"rating"])
        return ratingImages[remix.rating];
    else if ([tableColumn.identifier isEqualToString:@"title"])
        return remix.title;
    else if ([tableColumn.identifier isEqualToString:@"arranger"])
        return remix.arranger;
    else if ([tableColumn.identifier isEqualToString:@"subtune"])
        return [NSString stringWithFormat:@"%ld", (long)remix.subtuneIndex];
    
    return @"";
}

// ---------------------------------------------------------------------------
- (void)tableView:(NSTableView*)tableView sortDescriptorsDidChange:(NSArray*)oldDescriptors
{
    if (foundRemixes == nil)
        return;
    
    [foundRemixes sortUsingDescriptors:tableView.sortDescriptors];
    [tableView reloadData];
}

// ----------------------------------------------------------------------------
- (BOOL)tableView:(NSTableView*)tableView shouldEditTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
    return NO;
}

#pragma mark -
#pragma mark tableView delegate methods

// ----------------------------------------------------------------------------
- (NSString*)tableView:(NSTableView*)tableView toolTipForCell:(NSCell*)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn*)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation
{
    if (foundRemixes == nil)
        return nil;
    
    if ([tableColumn.identifier isEqualToString:@"rating"])
    {
        SPRemixKwedOrgDatabaseEntry* remix = foundRemixes[row];
        
        switch (remix.rating)
        {
            case 0:
                return @"No Rating Yet";
            case 1:
                return @"Awful";
            case 2:
                return @"Poor";
            case 3:
                return @"Average";
            case 4:
                return @"Good";
            case 5:
                return @"Very Good";
            case 6:
                return @"Outstanding";
            default:
                return nil;
        }
    }
    else
        return nil;
}
@end

@implementation SPRemixKwedOrgDatabaseEntry

@synthesize identifier;
@synthesize hvscPath;
@synthesize subtuneIndex;
@synthesize title;
@synthesize arranger;
@synthesize rating;

@end


