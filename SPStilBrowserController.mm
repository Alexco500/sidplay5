#import "SPStilBrowserController.h"
#import "SPCollectionUtilities.h"
#import "SPBrowserDataSource.h"
#import "SPPlayerWindow.h"
#import "SPPreferencesController.h"


@implementation SPStilBrowserController

static SPStilBrowserController* sharedInstance = nil;


// ----------------------------------------------------------------------------
+ (SPStilBrowserController*) sharedInstance
// ----------------------------------------------------------------------------
{
	if (sharedInstance == nil)
		sharedInstance = [[SPStilBrowserController alloc] init];
		
	return sharedInstance;
}


// ----------------------------------------------------------------------------
- (id) init
// ----------------------------------------------------------------------------
{
	if (self = [super initWithWindowNibName:@"StilBrowser"])
	{
		ownerWindow = nil;
		stilDatabasePath = nil;
		indexedStilDatabase = [NSMutableDictionary dictionaryWithCapacity:10000];
		indexingInProgress = NO;
		stilDataBaseValid = NO;
		currentPath = nil;
		cancelSearch = NO;
		searchInProgress = NO;
		currentSearchString = @"";
        
		//[self showWindow:self];
	}
	
	return self;
}


// ----------------------------------------------------------------------------
- (void) windowDidLoad
// ----------------------------------------------------------------------------
{
	[textView setTextColor:[NSColor blackColor]];
	[textView setString:@" "];
	[[self window] setAlphaValue:0.0f];
	[[self window] orderOut:self];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowWillClose:)
												 name:NSWindowWillCloseNotification
											   object:[self window]];
    
    [databasePathTextField setStringValue:@""];
}


// ----------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	[[ownerWindow stilBrowserMenuItem] setTitle:@"Show STIL Browser"];
}	


// ----------------------------------------------------------------------------
- (void) toggleWindow:(id)sender
// ----------------------------------------------------------------------------
{
	NSArray* animations = nil;
	NSWindow* window = [self window];

	if ([window isVisible])
	{
		[sender setTitle:@"Show STIL Browser"];
		[window setAlphaValue:1.0f];
		NSDictionary* windowFadeOut = [NSDictionary dictionaryWithObjectsAndKeys:window, NSViewAnimationTargetKey,
																			NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
		animations = [NSArray arrayWithObjects:windowFadeOut, nil];	
	}	
	else
	{
		[sender setTitle:@"Hide STIL Browser"];
		[window setAlphaValue:0.0f];
		[window orderFront:self];
		NSDictionary* windowFadeIn = [NSDictionary dictionaryWithObjectsAndKeys:window, NSViewAnimationTargetKey,
																			NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil];
		animations = [NSArray arrayWithObjects:windowFadeIn, nil];
        
        [databasePathTextField setStringValue:stilDatabasePath];
	}
	
    animation = [[NSViewAnimation alloc] initWithViewAnimations:animations];
    [animation setAnimationBlockingMode:NSAnimationNonblocking];
	
	BOOL isShiftPressed = [[NSApp currentEvent] modifierFlags] & NSShiftKeyMask ? YES : NO;

    [animation setDuration:isShiftPressed ? 3.0 : 0.2];
	[animation setDelegate:self];
    [animation startAnimation];
}


// ----------------------------------------------------------------------------
- (void) setOwnerWindow:(SPPlayerWindow*)window
// ----------------------------------------------------------------------------
{
	ownerWindow = window;
	[[self window] orderOut:self];
}


// ----------------------------------------------------------------------------
- (void) setCollectionRootPath:(NSString*)rootPath
// ----------------------------------------------------------------------------
{
	while (searchInProgress)
	{
		cancelSearch = YES;
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];
	}

	[textView setString:@" "];
	stilDataBaseValid = NO;
	indexingInProgress = YES;
	[databasePathTextField setStringValue:@"No STIL database available"];
	
	// Index the STIL database file if it exists in this collection
	stilDatabasePath = [rootPath stringByAppendingPathComponent:@"/DOCUMENTS/STIL.txt"];
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:stilDatabasePath isDirectory:NULL];
	if (exists)
		[NSThread detachNewThreadSelector:@selector(indexStilFromPath:) toTarget:self withObject:stilDatabasePath];
	else
		indexingInProgress = NO;
}


// ----------------------------------------------------------------------------
- (void) indexingFinished:(id)object
// ----------------------------------------------------------------------------
{
	NSNumber* result = (NSNumber*) object;

	if ([result boolValue])
	{
		[databasePathTextField setStringValue:stilDatabasePath];
		stilDataBaseValid = YES;
	}
	else
		stilDataBaseValid = NO;
		
	indexingInProgress = NO;
}


// ----------------------------------------------------------------------------
- (void) indexStilFromPath:(NSString*)path
// ----------------------------------------------------------------------------
{
	//NSDate* start = [NSDate date];

	FILE* fp = fopen([path cStringUsingEncoding:NSASCIIStringEncoding], "r");
	if (fp == NULL)
	{
		[self performSelectorOnMainThread:@selector(indexingFinished:) withObject:[NSNumber numberWithBool:NO] waitUntilDone:NO];
		return;
	}
		
	const int lineBufferSize = 256;
	char lineBuffer[lineBufferSize];
	NSString* currentFile = nil;
	NSString* currentEntry = @"";
	
	while (fgets(lineBuffer, lineBufferSize - 1, fp) != NULL)
	{
		int length = strlen(lineBuffer);
		if (lineBuffer[length - 2] == '\r')
		{
			lineBuffer[length - 2] = '\n';
			lineBuffer[length - 1] = 0;
		}
	
		if (lineBuffer[0] == '/')
		{
			if (currentFile != nil && currentEntry != nil)
				[indexedStilDatabase setObject:currentEntry forKey:currentFile];

			int length = strlen(lineBuffer);
			if (lineBuffer[length - 1] == '\n')
				lineBuffer[length - 1] = 0;

			if (lineBuffer[length - 2] == '/')
				lineBuffer[length - 2] = 0;
				
			currentFile = [NSString stringWithCString:lineBuffer encoding:NSISOLatin1StringEncoding];
			currentEntry = @"";
		}
		else if (lineBuffer[0] != '\r' && lineBuffer[1] != '\n' && lineBuffer[0] != '#')
		{
			NSString* line = [NSString stringWithCString:lineBuffer encoding:NSISOLatin1StringEncoding];
			currentEntry = [currentEntry stringByAppendingString:line];
		}
	}

	//NSDate* end = [NSDate date];
	//NSLog(@"Indexing STIL database %@ took %f seconds\n", path, [end timeIntervalSinceDate:start]);

	[self performSelectorOnMainThread:@selector(indexingFinished:) withObject:[NSNumber numberWithBool:YES] waitUntilDone:NO];
}


// ----------------------------------------------------------------------------
- (void) displayEntryForRelativePath:(NSString*)relativePath
// ----------------------------------------------------------------------------
{
	//NSLog(@"Trying to lookup STIL for %@\n", relativePath);
	
	if (indexingInProgress)
		return;
	
	/*
	while (indexingInProgress)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];
	*/
	 
	if (!stilDataBaseValid)
		return;
	
	if (relativePath == nil)
	{
		[textView setString:@" "];
		return;
	}
	
	currentPath = relativePath;
	NSString* result = nil;
	NSString* entry = [indexedStilDatabase objectForKey:relativePath];
	if (entry != nil)
		result = [NSString stringWithFormat:@"STIL information for %@:\n\n%@", relativePath, entry];
	else
		result = [NSString stringWithFormat:@"No STIL information for %@", relativePath];
		
	NSDictionary* defaultAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Monaco" size:9.0f], NSFontAttributeName, nil];

	NSMutableAttributedString* attributedResult = [[NSMutableAttributedString alloc] initWithString:result attributes:defaultAttributes];

	NSRange keyRange = [result rangeOfString:relativePath];
	NSDictionary* linkAttributes = [NSDictionary dictionaryWithObjectsAndKeys:relativePath, NSLinkAttributeName,
																			  [NSColor blueColor], NSForegroundColorAttributeName,
																			  [NSNumber numberWithBool:YES], NSUnderlineStyleAttributeName, nil];
	[attributedResult addAttributes:linkAttributes range:keyRange];

	NSString* lowerCaseResult = [result lowercaseString];
	NSRange currentRange = NSMakeRange(0, [lowerCaseResult length]);
	NSRange itemRange = NSMakeRange(0, 0);

	while (itemRange.location != NSNotFound)
	{
		itemRange = [lowerCaseResult rangeOfString:@" /" options:NSLiteralSearch range:currentRange];
		if (itemRange.location != NSNotFound)
		{
			itemRange.location++;
			currentRange.location = itemRange.location;
			currentRange.length = [lowerCaseResult length] - currentRange.location;
		
			NSRange endRange = [lowerCaseResult rangeOfString:@".sid" options:NSLiteralSearch range:currentRange];
			if (endRange.location != NSNotFound)
			{
				itemRange.length = endRange.location + 4 - itemRange.location;
				NSString* foundFile = [result substringWithRange:itemRange];
				NSDictionary* linkAttributes = [NSDictionary dictionaryWithObjectsAndKeys:foundFile, NSLinkAttributeName,
																						  [NSColor blueColor], NSForegroundColorAttributeName,
																						  [NSNumber numberWithBool:YES], NSUnderlineStyleAttributeName, nil];

				[attributedResult addAttributes:linkAttributes range:itemRange];
				
				currentRange.location = itemRange.location + itemRange.length;
				currentRange.length = [lowerCaseResult length] - currentRange.location;
			}
			else
				itemRange.location = NSNotFound;
		}
	}
		
	[[textView textStorage] setAttributedString:attributedResult];	
}


// ----------------------------------------------------------------------------
- (void) displaySharedCollectionMessage
// ----------------------------------------------------------------------------
{
	NSDictionary* defaultAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Monaco" size:9.0f], NSFontAttributeName, nil];
	NSMutableAttributedString* attributedMessageString = [[NSMutableAttributedString alloc] initWithString:@"No STIL information for shared collection files" attributes:defaultAttributes];
	[[textView textStorage] setAttributedString:attributedMessageString];	
}



// ----------------------------------------------------------------------------
- (NSSearchField*) searchField
// ----------------------------------------------------------------------------
{
	return searchField;
}


// ----------------------------------------------------------------------------
- (IBAction) searchStringEntered:(id)sender
// ----------------------------------------------------------------------------
{
	if (!stilDataBaseValid)
		return;

	if ([[sender stringValue] caseInsensitiveCompare:currentSearchString] == NSOrderedSame)
		return;
		
	currentSearchString = [sender stringValue];

	while (searchInProgress)
	{
		cancelSearch = YES;
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];
	}
	
	NSString* searchString = [[sender stringValue] lowercaseString];

	if ([searchString length] < 3)
	{
		[self displayEntryForRelativePath:currentPath];
		return;
	}
	
	[textView setString:@""];
	cancelSearch = NO;
	searchInProgress = YES;
	[NSThread detachNewThreadSelector:@selector(searchForEntryThread:) toTarget:self withObject:searchString];
}


// ----------------------------------------------------------------------------
- (void) searchForEntryThread:(id)object
// ----------------------------------------------------------------------------
{
	NSString* searchString = object;
	NSDictionary* defaultAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Monaco" size:9.0f], NSFontAttributeName, nil];
	NSArray* keys = [indexedStilDatabase allKeys];

	for (NSString* key in keys)
	{
		if(cancelSearch)
			break;
		
		BOOL match = NO;
		NSString* result = nil;
		
		if ([[key lowercaseString] rangeOfString:searchString].location != NSNotFound)
		{
			result = [NSString stringWithFormat:@"STIL information for %@:\n\n%@\n", key, [indexedStilDatabase objectForKey:key]];
			match = YES;
		}
		else
		{
			NSString* entry = [indexedStilDatabase objectForKey:key];
			if (entry != nil && [[entry lowercaseString] rangeOfString:searchString].location != NSNotFound)
			{
				result = [NSString stringWithFormat:@"STIL information for %@:\n\n%@\n", key, entry];
				match = YES;
			}
		}

		if (match)
		{
			NSMutableAttributedString* attributedResult = [[NSMutableAttributedString alloc] initWithString:result attributes:defaultAttributes];
		
			NSRange keyRange = [result rangeOfString:key];
			NSDictionary* linkAttributes = [NSDictionary dictionaryWithObjectsAndKeys:key, NSLinkAttributeName,
																					  [NSColor blueColor], NSForegroundColorAttributeName,
																					  [NSNumber numberWithBool:YES], NSUnderlineStyleAttributeName, nil];
			[attributedResult addAttributes:linkAttributes range:keyRange];

			NSString* lowerCaseResult = [result lowercaseString];
			NSRange currentRange = NSMakeRange(0, [lowerCaseResult length]);
			NSRange itemRange = NSMakeRange(0, 0);
			NSColor* foundStringBackgroundColor = [NSColor colorWithCalibratedWhite:0.8f alpha:1.0f];
			NSDictionary* foundStringAttributes = [NSDictionary dictionaryWithObjectsAndKeys:foundStringBackgroundColor, NSBackgroundColorAttributeName, nil];

			while (itemRange.location != NSNotFound)
			{
				itemRange = [lowerCaseResult rangeOfString:searchString options:NSLiteralSearch range:currentRange];
				if (itemRange.location != NSNotFound)
				{
					[attributedResult addAttributes:foundStringAttributes range:itemRange];
					
					currentRange.location = itemRange.location + itemRange.length;
					currentRange.length = [lowerCaseResult length] - currentRange.location;
				}
			}

			currentRange = NSMakeRange(0, [lowerCaseResult length]);
			itemRange = NSMakeRange(0, 0);
			while (itemRange.location != NSNotFound)
			{
				itemRange = [lowerCaseResult rangeOfString:@" /" options:NSLiteralSearch range:currentRange];
				if (itemRange.location != NSNotFound)
				{
					itemRange.location++;
					currentRange.location = itemRange.location;
					currentRange.length = [lowerCaseResult length] - currentRange.location;

					NSRange endRange = [lowerCaseResult rangeOfString:@".sid" options:NSLiteralSearch range:currentRange];
					if (endRange.location != NSNotFound)
					{
						itemRange.length = endRange.location + 4 - itemRange.location;
						NSString* foundFile = [result substringWithRange:itemRange];
						NSDictionary* linkAttributes = [NSDictionary dictionaryWithObjectsAndKeys:foundFile, NSLinkAttributeName,
																								  [NSColor blueColor], NSForegroundColorAttributeName,
																								  [NSNumber numberWithBool:YES], NSUnderlineStyleAttributeName, nil];

						[attributedResult addAttributes:linkAttributes range:itemRange];
						
						currentRange.location = itemRange.location + itemRange.length;
						currentRange.length = [lowerCaseResult length] - currentRange.location;
					}
					else
						itemRange.location = NSNotFound;
				}
			}
			
			[self performSelectorOnMainThread:@selector(updateSearchResult:)
														withObject:(id)attributedResult
														waitUntilDone:YES];
		}

		//[[NSGarbageCollector defaultCollector] collectIfNeeded];
	}
	
	searchInProgress = NO;
	//[self performSelectorOnMainThread:@selector(searchFinished:) withObject:nil waitUntilDone:NO];
}



// ----------------------------------------------------------------------------
- (void) updateSearchResult:(id)object
// ----------------------------------------------------------------------------
{
	NSAttributedString* result = (NSAttributedString*) object;
	
	[[textView textStorage] appendAttributedString:result];
}


/*
// ----------------------------------------------------------------------------
- (void) searchFinished:(id)object
// ----------------------------------------------------------------------------
{

}
*/

#pragma mark -
#pragma mark NSAnimation delegate methods

// ----------------------------------------------------------------------------
- (void) animationDidEnd:(NSAnimation *)theAnimation
// ----------------------------------------------------------------------------
{
	NSArray* animations = [(NSViewAnimation*)theAnimation viewAnimations];
	NSDictionary* windowFade = [animations objectAtIndex:0];
	if ([windowFade objectForKey:NSViewAnimationEffectKey] == NSViewAnimationFadeOutEffect)
		[[self window] orderOut:self];
}


#pragma mark -
#pragma mark NSTextView delegate methods

// ----------------------------------------------------------------------------
- (BOOL) textView:(NSTextView*)textView clickedOnLink:(id)link atIndex:(unsigned int)charIndex
// ----------------------------------------------------------------------------
{
    if ([link isKindOfClass:[NSString class]])
    {
		NSString* absolutePath = [[SPCollectionUtilities sharedInstance] absolutePathFromRelativePath:link];
		[[ownerWindow browserDataSource] browseToFile:absolutePath andSetAsCurrentItem:NO];
		//[ownerWindow playTuneAtPath:absolutePath];
		
		if (gPreferences.mHideStilBrowserOnLinkClicked)
			[self toggleWindow:[ownerWindow stilBrowserMenuItem]];

        return YES;
    }

    return NO;
}

@end


#pragma mark -
@implementation SPBrowserPanel


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[self setFloatingPanel:YES];
}

@end


#pragma mark -
@implementation SPBrowserTextView


// ----------------------------------------------------------------------------
+ (NSCursor*) fingerCursor
// ----------------------------------------------------------------------------
{
    static NSCursor	*fingerCursor = nil;

    if (fingerCursor == nil)
        fingerCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"fingerCursor"] hotSpot:NSMakePoint(0, 0)];

    return fingerCursor;
}


// ----------------------------------------------------------------------------
- (void) mouseMoved:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	NSPoint mousePosition = [event locationInWindow];
	NSPoint mousePositionInView = [self convertPoint:mousePosition fromView:nil];

    NSView* contentView = [[self enclosingScrollView] contentView];
    NSPoint mouseLocInContentView = [contentView convertPoint:mousePositionInView fromView:self];

	int charIndex;

    if ([contentView mouse:mouseLocInContentView inRect:[contentView bounds]])
    {
        int glyphIndex = [[self layoutManager] glyphIndexForPoint:mousePositionInView inTextContainer:[self textContainer]];
        charIndex = [[self layoutManager] characterIndexForGlyphAtIndex:glyphIndex];
    }
    else
        charIndex = -1;

    if (charIndex != -1)
    {
        //	They're pointing at some text; get its attributes and show them.
        NSDictionary* attributes = [[self textStorage] attributesAtIndex:charIndex  effectiveRange:NULL];

		NSObject* link = [attributes objectForKey:NSLinkAttributeName];

		if (link != nil)
		{
			[[SPBrowserTextView fingerCursor] set];
			return;
		}
    }

	[super mouseMoved:event];
}


@end
