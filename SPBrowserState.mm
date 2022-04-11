#import "SPBrowserState.h"


@implementation SPBrowserState

// ----------------------------------------------------------------------------
- (instancetype) init
// ----------------------------------------------------------------------------
{
    return [self initWithPath:nil andItems:nil andExpandedFolders:nil andSelectedItems:nil];
}
// ----------------------------------------------------------------------------
- (instancetype) initWithPath:(NSString*)path andItems:(NSMutableArray*)items andExpandedFolders:(NSMutableArray*)expandedFolders andSelectedItems:(NSMutableArray*)selected
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		currentPath = [NSString stringWithString:path];
		rootItems = [NSMutableArray arrayWithArray:items];
		expandedFolderItems = [NSMutableArray arrayWithArray:expandedFolders];
		selectedItems = [NSMutableArray arrayWithArray:selected];
	}
	return self;
}


// ----------------------------------------------------------------------------
- (NSString*) currentPath
// ----------------------------------------------------------------------------
{
	return currentPath;
}


// ----------------------------------------------------------------------------
- (NSMutableArray*) rootItems
// ----------------------------------------------------------------------------
{
	return rootItems;
}


// ----------------------------------------------------------------------------
- (NSMutableArray*) expandedFolderItems
// ----------------------------------------------------------------------------
{
	return expandedFolderItems;
}


// ----------------------------------------------------------------------------
- (NSMutableArray*) selectedItems
// ----------------------------------------------------------------------------
{
	return selectedItems;
}


@end
