#import <Cocoa/Cocoa.h>


@interface SPBrowserState : NSObject
{
	NSString* currentPath;
	NSMutableArray* rootItems;
	NSMutableArray* expandedFolderItems;
	NSMutableArray* selectedItems;
}

- (id) initWithPath:(NSString*)path andItems:(NSMutableArray*)items andExpandedFolders:(NSMutableArray*)expandedFolders andSelectedItems:(NSMutableArray*)selected;
- (NSString*) currentPath;
- (NSMutableArray*) rootItems;
- (NSMutableArray*) expandedFolderItems;
- (NSMutableArray*) selectedItems;


@end
