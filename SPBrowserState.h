#import <Cocoa/Cocoa.h>


@interface SPBrowserState : NSObject
{
	NSString* currentPath;
	NSMutableArray* rootItems;
	NSMutableArray* expandedFolderItems;
	NSMutableArray* selectedItems;
}

- (instancetype) initWithPath:(NSString*)path andItems:(NSMutableArray*)items andExpandedFolders:(NSMutableArray*)expandedFolders andSelectedItems:(NSMutableArray*)selected NS_DESIGNATED_INITIALIZER;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *currentPath;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMutableArray *rootItems;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMutableArray *expandedFolderItems;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMutableArray *selectedItems;


@end
