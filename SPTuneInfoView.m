#import "SPInfoContainerView.h"
#import "SPTuneInfoView.h"
#import "SPColorProvider.h"
#import "SPPlayerWindow.h"
#import "PlayerLibSidplayWrapper.h"
#import "SPPreferencesController.h"


@implementation SPTuneInfoView

// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[super awakeFromNib];

	index = TUNEINFO_CONTAINER_INDEX;
	height = 158.0f;
	[self setCollapsed:gPreferences.mTuneInfoCollapsed];
	
	[container addInfoView:self atIndex:index];
}

@end


#pragma mark -
@implementation SPTuneInfoContentView

#define TUNE_INFO_ITEMS 10

// ----------------------------------------------------------------------------
- (instancetype)initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{
//		tuneInfoHeaders = [NSMutableArray arrayWithCapacity:TUNE_INFO_ITEMS];
//		tuneInfoStrings = [NSMutableArray arrayWithCapacity:TUNE_INFO_ITEMS];
		
		player = NULL;
	}
    return self;
}


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
//	[tuneInfoHeaders addObject:@"Title"];
//	[tuneInfoHeaders addObject:@"Author"];
//	[tuneInfoHeaders addObject:@"Released"];
//	[tuneInfoHeaders addObject:@"Songs"];
//	[tuneInfoHeaders addObject:@"Load Address"];
//	[tuneInfoHeaders addObject:@"Init Address"];
//	[tuneInfoHeaders addObject:@"Play Address"];
//	[tuneInfoHeaders addObject:@"Format"];
//	[tuneInfoHeaders addObject:@"File size"];
//	[tuneInfoHeaders addObject:@"SID Chip"];
//	
//	for (int i = 0; i < TUNE_INFO_ITEMS; i++)
//		[tuneInfoStrings addObject:@""];
//	
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTuneInfo:) name:SPTuneChangedNotification object:nil];
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(containerBackgroundChanged:) name:SPInfoContainerBackgroundChangedNotification object:nil];
//
//	[tuneInfoTableView setGridColor:[[SPColorProvider sharedInstance] gridColor]];
//	[tuneInfoTableView reloadData];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTuneInfo:) name:SPTuneChangedNotification object:nil];
    
}


// ----------------------------------------------------------------------------
- (void) updateTuneInfo:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
    [self setNeedsDisplay:YES];
    
    
//	if (player == NULL)
//	{
//		SPInfoContainerView* container = [[self enclosingScrollView] documentView];
//		player = (PlayerLibSidplay*) [[container ownerWindow] player];
//	}
//	
//	if (player != NULL)
//	{
//		[tuneInfoStrings removeAllObjects];
//		
//		if (player->isTuneLoaded() && player->hasTuneInformationStrings())
//		{
//			[tuneInfoStrings addObject:[NSString stringWithCString:player->getCurrentTitle() encoding:NSISOLatin1StringEncoding]];
//			[tuneInfoStrings addObject:[NSString stringWithCString:player->getCurrentAuthor() encoding:NSISOLatin1StringEncoding]];
//			[tuneInfoStrings addObject:[NSString stringWithCString:player->getCurrentReleaseInfo() encoding:NSISOLatin1StringEncoding]];
//			[tuneInfoStrings addObject:[NSString stringWithFormat:@"%d (default: %d)", player->getSubtuneCount(), player->getDefaultSubtune()]];
//			[tuneInfoStrings addObject:[NSString stringWithFormat:@"$%04x", player->getCurrentLoadAddress()]];
//			[tuneInfoStrings addObject:[NSString stringWithFormat:@"$%04x", player->getCurrentInitAddress()]];
//			[tuneInfoStrings addObject:[NSString stringWithFormat:@"$%04x", player->getCurrentPlayAddress()]];
//			[tuneInfoStrings addObject:[NSString stringWithCString:player->getCurrentFormat() encoding:NSISOLatin1StringEncoding]];
//			[tuneInfoStrings addObject:[NSString stringWithFormat:@"%d bytes", player->getCurrentFileSize()]];
//			[tuneInfoStrings addObject:[NSString stringWithCString:player->getCurrentChipModel() encoding:NSASCIIStringEncoding]];
//		}
//		else
//		{
//			for (int i = 0; i < TUNE_INFO_ITEMS; i++)
//				[tuneInfoStrings addObject:@""];
//		}
//		
//		[tuneInfoTableView reloadData];
//	}
}


static const int sRowCount = 10;
static const char* sRowTitles[] =
{
    "Title",
    "Author",
    "Released",
    "Songs",
    "Used SIDs",
    "Load Address",
    "Init Address",
    "Play Address",
    "Format",
    "File size",
    "SID Chip",
};



// ----------------------------------------------------------------------------
- (void)drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
    [super drawRect:rect];
    
    const float rowHeight = 13.0f;
    const float	columnWidth = 80.0f;
    
    CGContextRef context = (CGContextRef) [NSGraphicsContext currentContext].graphicsPort;
    NSArray* colors = [[SPColorProvider sharedInstance] alternatingRowBackgroundColors];
    NSColor* even = colors[1];
    NSColor* odd = colors[0];
    
    for (int i = 0; i < sRowCount; i++)
    {
        NSRect rowRect = rect;
        rowRect.origin.y = i * rowHeight;
        rowRect.size.height = rowHeight;
        
        if (i & 1)
            [odd set];
        else
            [even set];
        
        //NSRectFill(rowRect);
    }
    
//    [[[SPColorProvider sharedInstance] gridColor] set];
//    [NSBezierPath strokeLineFromPoint:NSMakePoint(columnWidth - 0.5f, rect.size.height) toPoint:NSMakePoint(columnWidth - 0.5f, rect.size.height - sRowCount * rowHeight)];
    
    CGContextSelectFont(context, "Lucida Grande", 9.0f, kCGEncodingMacRoman);
    if ([[SPColorProvider sharedInstance] providesDarkColors])
    {
        CGContextSetRGBStrokeColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
        CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
    }
    else
    {
        CGContextSetRGBStrokeColor(context, 0.0f, 0.0f, 0.0f, 1.0f);
        CGContextSetRGBFillColor(context, 0.0f, 0.0f, 0.0f, 1.0f);
    }
    
    CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1.0f, 1.0f));
    CGContextSetTextDrawingMode(context, kCGTextFill);
    
    if (player == NULL)
    {
        SPInfoContainerView* container = self.enclosingScrollView.documentView;
        player = (PlayerLibSidplayWrapper*) [[container ownerWindow] player];
    }

    float xpos = rect.origin.x + 3.0f;
    float ypos = rect.origin.y + rect.size.height - 9.0f;
    char stringBuffer[256];

    for (int i = 0; i < sRowCount; i++)
    {
        CGContextShowTextAtPoint(context, xpos, ypos, sRowTitles[i], strlen(sRowTitles[i]));
        ypos -= rowHeight;
    }

    if (player != NULL)
	{
		if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        {
            xpos = rect.origin.x + 3.0f + columnWidth;
            ypos = rect.origin.y + rect.size.height - 9.0f;
            
            CFStringRef titleStringRef = CFStringCreateWithCString(NULL, [player getCurrentTitle], kCFStringEncodingISOLatin1);
            CFStringGetCString(titleStringRef, stringBuffer, 255, kCFStringEncodingMacRoman);
            CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));
            ypos -= rowHeight;
            
            CFStringRef authorStringRef = CFStringCreateWithCString(NULL, [player getCurrentAuthor], kCFStringEncodingISOLatin1);
            CFStringGetCString(authorStringRef, stringBuffer, 255, kCFStringEncodingMacRoman);
            CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));
            ypos -= rowHeight;
            
            CFStringRef releaseStringRef = CFStringCreateWithCString(NULL, [player getCurrentReleaseInfo], kCFStringEncodingISOLatin1);
            CFStringGetCString(releaseStringRef, stringBuffer, 255, kCFStringEncodingMacRoman);
            //            snprintf(stringBuffer, 255, player->getCurrentReleaseInfo());
            CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));
            ypos -= rowHeight;
            
            snprintf(stringBuffer, 255, "%d (default: %d)", [player getSubtuneCount], [player getDefaultSubtune]);
            CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));
            ypos -= rowHeight;
            snprintf(stringBuffer, 255, "%d", [player getSidChips]);
            CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));
            ypos -= rowHeight;            snprintf(stringBuffer, 255, "$%04x", [player getCurrentLoadAddress]);
            CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));
            ypos -= rowHeight;
            snprintf(stringBuffer, 255, "$%04x", [player getCurrentInitAddress]);
            CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));
            ypos -= rowHeight;
            snprintf(stringBuffer, 255, "$%04x", [player getCurrentPlayAddress]);
            CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));
            ypos -= rowHeight;
            snprintf(stringBuffer, 255, "%s", [player getCurrentFormat]);
            CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));
            ypos -= rowHeight;
            snprintf(stringBuffer, 255, "%d bytes", [player getCurrentFileSize]);
            CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));
            ypos -= rowHeight;
            snprintf(stringBuffer, 255, "%s", [player getCurrentChipModel]);
            CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));
            //ypos -= rowHeight;
		}
    }
}



#if 0

// ----------------------------------------------------------------------------
- (void) containerBackgroundChanged:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	[tuneInfoTableView setGridColor:[[SPColorProvider sharedInstance] gridColor]];
}


#pragma mark -
#pragma mark data source methods

// ----------------------------------------------------------------------------
- (int)numberOfRowsInTableView:(NSTableView*)tableView
// ----------------------------------------------------------------------------
{
    return [tuneInfoHeaders count];
}


// ----------------------------------------------------------------------------
- (id)tableView:(NSTableView*)tableView objectValueForTableColumn:(NSTableColumn*)tableColumn row:(int)index
// ----------------------------------------------------------------------------
{
	if ([[tableColumn identifier] isEqualToString:@"header"])
		return [tuneInfoHeaders objectAtIndex:index];
	else if ([[tableColumn identifier] isEqualToString:@"info"])
		return [tuneInfoStrings objectAtIndex:index];
		
	return @"";
}


#pragma mark -
#pragma mark delegate methods

// ----------------------------------------------------------------------------
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
// ----------------------------------------------------------------------------
{
	return NO;
}

#endif

@end
