#import "SPSmartPlaylist.h"
#import "SPPlaylistItem.h"
#import "SPApplicationStorageController.h"
#import	"SPCollectionUtilities.h"


NSString* SPSmartPlaylistChangedNotification = @"SPSmartPlaylistChangedNotification";

@implementation SPSmartPlaylist


// ----------------------------------------------------------------------------
- (id) init
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil) 
	{
		predicate = nil;
		cachedItems = [NSMutableArray arrayWithCapacity:100];
		isCachingItems = NO;
		smartPlaylistQuery = [[NSMetadataQuery alloc] init];
		[smartPlaylistQuery setDelegate:self];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(spotlightResultNotification:) name:nil object:smartPlaylistQuery];
	}
	return self;
}


// ----------------------------------------------------------------------------
- (id) initWithCoder:(NSCoder*)coder
// ----------------------------------------------------------------------------
{
	if (self = [self init])
	{
		if (self = [super initWithCoder:coder])
		{
			if ([coder allowsKeyedCoding])
				[self setPredicate:[coder decodeObjectForKey:@"SPKeyPredicate"]];
			else
				[self setPredicate:[coder decodeObject]];
				
			[self startSpotlightQuery:[[SPCollectionUtilities sharedInstance] rootPath]];
		}
	}
	return self;
}


// ----------------------------------------------------------------------------
- (void) encodeWithCoder:(NSCoder*)coder
// ----------------------------------------------------------------------------
{
	[super encodeWithCoder:coder];
    if ([coder allowsKeyedCoding])
        [coder encodeObject:predicate forKey:@"SPKeyPredicate"];
	else
		[coder encodeObject:predicate];
}


// ----------------------------------------------------------------------------
- (NSPredicate*) predicate
// ----------------------------------------------------------------------------
{
	return predicate;
}


// ----------------------------------------------------------------------------
- (void) setPredicate:(NSPredicate*)thePredicate
// ----------------------------------------------------------------------------
{
	predicate = [thePredicate copy];
}


// ----------------------------------------------------------------------------
- (NSMutableArray*) items
// ----------------------------------------------------------------------------
{
	return cachedItems;
}


// ----------------------------------------------------------------------------
- (NSInteger) count
// ----------------------------------------------------------------------------
{
	if (cachedItems == nil)
		return 0;
	else
		return [cachedItems count];
}


// ----------------------------------------------------------------------------
- (SPPlaylistItem*) itemAtIndex:(NSInteger)index
// ----------------------------------------------------------------------------
{
	if (cachedItems == nil)
		return nil;
	else
		return [cachedItems objectAtIndex:index];
}


// ----------------------------------------------------------------------------
- (NSPredicate*) convertPredicate:(NSPredicate*)originalPredicate
// ----------------------------------------------------------------------------
{
	NSPredicate* newPredicate = nil;
	if ([originalPredicate isKindOfClass:[NSCompoundPredicate class]])
	{
		NSArray* subPredicates = [(NSCompoundPredicate*)originalPredicate subpredicates];
		NSMutableArray* newSubPredicates = [NSMutableArray arrayWithCapacity:[subPredicates count]];
		for (NSPredicate* subPredicate in subPredicates)
		{
			if ([subPredicate isKindOfClass:[NSComparisonPredicate class]])
			{
				NSComparisonPredicate* comparisonPredicate = (NSComparisonPredicate*) subPredicate;
				NSExpression* expression = [comparisonPredicate rightExpression];
				if ([expression expressionType] == NSConstantValueExpressionType)
				{
					NSString* searchString = [expression constantValue];
					NSPredicateOperatorType operatorType = [comparisonPredicate predicateOperatorType];
					if (operatorType == NSContainsPredicateOperatorType)
					{
						if ([searchString length] < 2)
							return nil;
							
						searchString = [NSString stringWithFormat:@"*%@*", searchString];
						operatorType = NSLikePredicateOperatorType;
					}
					NSExpression* newExpression = [NSExpression expressionForConstantValue:searchString];
					NSPredicate* newSubPredicate = [NSComparisonPredicate predicateWithLeftExpression:[comparisonPredicate leftExpression] 
																				      rightExpression:newExpression
																			                 modifier:[comparisonPredicate comparisonPredicateModifier]
																							     type:operatorType
																							  options:[comparisonPredicate options]];
					[newSubPredicates addObject:newSubPredicate];
				}
			}
			else if ([subPredicate isKindOfClass:[NSCompoundPredicate class]])
			{
				NSPredicate* newSubPredicate = [self convertPredicate:subPredicate];
				[newSubPredicates addObject:newSubPredicate];
			}
		}

		NSCompoundPredicateType type = [(NSCompoundPredicate*)originalPredicate compoundPredicateType];
		newPredicate = [[NSCompoundPredicate alloc] initWithType:type subpredicates:newSubPredicates];
	}
	else
		newPredicate = originalPredicate;

	return newPredicate;
}



// ----------------------------------------------------------------------------
- (void) startSpotlightQuery:(NSString*)rootPath
// ----------------------------------------------------------------------------
{
	if (rootPath == nil)
		return;

	abortCaching = YES;

	//NSLog(@"Caching smart playlist results for %@ (%@)\n", [self name], [self identifier]);
	[smartPlaylistQuery stopQuery]; 
	
	//NSLog(@"Original predicate: %@\n", predicate);
	NSPredicate* newPredicate = [self convertPredicate:predicate];
	if (newPredicate == nil)
		return;
		
	//NSLog(@"new predicate: %@\n", newPredicate);

	NSString* predicateString = [NSString stringWithFormat:@"(%@) && (kMDItemContentType == 'org.sidmusic.sidtune')", [newPredicate predicateFormat]];
	//predicateString = [predicateString stringByReplacingOccurrencesOfString:@"CONTAINS" withString:@"LIKE"];
	//NSLog(@"final predicate: %@\n", predicateString);
	NSPredicate* extendedPredicate = [NSPredicate predicateWithFormat:predicateString];
    [smartPlaylistQuery setPredicate:extendedPredicate];           
	[smartPlaylistQuery setSearchScopes:[NSArray arrayWithObject:rootPath]];
    [smartPlaylistQuery startQuery];
	
	isCachingItems = YES;
}


// ----------------------------------------------------------------------------
- (void) spotlightResultNotification:(NSNotification *)notification
// ----------------------------------------------------------------------------
{
    if ([[notification name] isEqualToString:NSMetadataQueryDidStartGatheringNotification])
	{

    }
	else if ([[notification name] isEqualToString:NSMetadataQueryDidFinishGatheringNotification])
	{
		[NSThread detachNewThreadSelector:@selector(spotlightResultConsumerThread:) toTarget:self withObject:nil];
    }
	else if ([[notification name] isEqualToString:NSMetadataQueryGatheringProgressNotification])
	{

    }
	else if ([[notification name] isEqualToString:NSMetadataQueryDidUpdateNotification])
	{
		[NSThread detachNewThreadSelector:@selector(spotlightResultConsumerThread:) toTarget:self withObject:nil];
    }
}


// ----------------------------------------------------------------------------
- (void) spotlightResultConsumerThread:(id)object
// ----------------------------------------------------------------------------
{
	isCachingItems = YES;
	abortCaching = NO;
	
	[cachedItems removeAllObjects];
	[smartPlaylistQuery stopQuery];
	int resultCount = (int)[smartPlaylistQuery resultCount];
	for (NSInteger i = 0; i < resultCount; i++)
	{
		if (abortCaching)
			return;
		
		NSMetadataItem* metaDataItem = [smartPlaylistQuery resultAtIndex:i];
		NSString* relativePath = [[metaDataItem valueForAttribute:@"kMDItemPath"] stringByRemovingPrefix:[[SPCollectionUtilities sharedInstance] rootPath]];

		SPPlaylistItem* item = [[SPPlaylistItem alloc] initWithPath:relativePath andSubtuneIndex:0 andLoopCount:1];
		[cachedItems addObject:item];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPSmartPlaylistChangedNotification object:self];
	[smartPlaylistQuery enableUpdates];

	isCachingItems = NO;
}


// ----------------------------------------------------------------------------
- (BOOL) isCachingItems
// ----------------------------------------------------------------------------
{
	return isCachingItems;
}


// ----------------------------------------------------------------------------
- (BOOL) saveToFile
// ----------------------------------------------------------------------------
{
	NSString* filename = [identifier stringByAppendingPathExtension:[SPSmartPlaylist fileExtension]];
	path = [[SPApplicationStorageController playlistPath] stringByAppendingPathComponent:filename];
	
	NSData* data = [NSKeyedArchiver archivedDataWithRootObject:self];
	BOOL success = [data writeToFile:path atomically:YES];
	return success;
}


// ----------------------------------------------------------------------------
+ (NSString*) fileExtension
// ----------------------------------------------------------------------------
{
	static NSString* extension = @"smartsidplaylist";

	return extension;
}


// ----------------------------------------------------------------------------
+ (SPSmartPlaylist*) playlistFromFile:(NSString*)path
// ----------------------------------------------------------------------------
{
	NSData* data = [NSData dataWithContentsOfFile:path];
	SPSmartPlaylist* playlist = [NSKeyedUnarchiver unarchiveObjectWithData:data];

	return playlist;
}




@end
