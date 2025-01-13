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
    
    NSColor *strokeColor;
    strokeColor = [[SPColorProvider sharedInstance] rgbStrokeColor];
    //NSColor *fillColor;
    //fillColor = [[SPColorProvider sharedInstance] rgbFillColor];
    
    NSDictionary* stringAttributes = @{NSFontAttributeName:[NSFont fontWithName:@"Lucida Grande" size:9.0f], NSForegroundColorAttributeName:strokeColor};

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
       // CGContextShowTextAtPoint(context, xpos, ypos, sRowTitles[i], strlen(sRowTitles[i]));
        [[NSString stringWithCString:sRowTitles[i] encoding:NSISOLatin1StringEncoding] drawAtPoint:CGPointMake(xpos, ypos) withAttributes:stringAttributes];
        ypos -= rowHeight;
    }

    if (player != NULL)
	{
		if ([player isTuneLoaded] && [player hasTuneInformationStrings])
        {
            xpos = rect.origin.x + 3.0f + columnWidth;
            ypos = rect.origin.y + rect.size.height - 9.0f;
            
            [[NSString stringWithCString:[player getCurrentTitle] encoding:NSISOLatin1StringEncoding] drawAtPoint:CGPointMake(xpos, ypos) withAttributes:stringAttributes];
            ypos -= rowHeight;
            
            [[NSString stringWithCString:[player getCurrentAuthor] encoding:NSISOLatin1StringEncoding] drawAtPoint:CGPointMake(xpos, ypos) withAttributes:stringAttributes];
            ypos -= rowHeight;
            
            [[NSString stringWithCString:[player getCurrentReleaseInfo] encoding:NSISOLatin1StringEncoding] drawAtPoint:CGPointMake(xpos, ypos) withAttributes:stringAttributes];
            ypos -= rowHeight;
            
            snprintf(stringBuffer, 255, "%d (default: %d)", [player getSubtuneCount], [player getDefaultSubtune]);
            [[NSString stringWithCString:stringBuffer encoding:NSISOLatin1StringEncoding] drawAtPoint:CGPointMake(xpos, ypos) withAttributes:stringAttributes];
            ypos -= rowHeight;
            
            snprintf(stringBuffer, 255, "%d", [player getSidChips]);
            [[NSString stringWithCString:stringBuffer encoding:NSISOLatin1StringEncoding] drawAtPoint:CGPointMake(xpos, ypos) withAttributes:stringAttributes];
            ypos -= rowHeight;
            
            snprintf(stringBuffer, 255, "$%04x", [player getCurrentLoadAddress]);
            [[NSString stringWithCString:stringBuffer encoding:NSISOLatin1StringEncoding] drawAtPoint:CGPointMake(xpos, ypos) withAttributes:stringAttributes];
            ypos -= rowHeight;
            
            snprintf(stringBuffer, 255, "$%04x", [player getCurrentInitAddress]);
            [[NSString stringWithCString:stringBuffer encoding:NSISOLatin1StringEncoding] drawAtPoint:CGPointMake(xpos, ypos) withAttributes:stringAttributes];
            ypos -= rowHeight;
            
            snprintf(stringBuffer, 255, "$%04x", [player getCurrentPlayAddress]);
            [[NSString stringWithCString:stringBuffer encoding:NSISOLatin1StringEncoding] drawAtPoint:CGPointMake(xpos, ypos) withAttributes:stringAttributes];
            ypos -= rowHeight;
            
            snprintf(stringBuffer, 255, "%s", [player getCurrentFormat]);
            [[NSString stringWithCString:stringBuffer encoding:NSISOLatin1StringEncoding] drawAtPoint:CGPointMake(xpos, ypos) withAttributes:stringAttributes];
            ypos -= rowHeight;
            
            snprintf(stringBuffer, 255, "%d bytes", [player getCurrentFileSize]);
            [[NSString stringWithCString:stringBuffer encoding:NSISOLatin1StringEncoding] drawAtPoint:CGPointMake(xpos, ypos) withAttributes:stringAttributes];
            ypos -= rowHeight;
            
            snprintf(stringBuffer, 255, "%s", [player getCurrentChipModel]);
            [[NSString stringWithCString:stringBuffer encoding:NSISOLatin1StringEncoding] drawAtPoint:CGPointMake(xpos, ypos) withAttributes:stringAttributes];
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
