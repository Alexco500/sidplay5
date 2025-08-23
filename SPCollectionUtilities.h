#import <Cocoa/Cocoa.h>


@interface SPCollectionUtilities : NSObject
{
    NSString* rootPath;
    
    NSMutableArray* rsyncMirrorList;
    id rsyncMirrorListNotificationTarget;
    SEL rsyncMirrorListNotificationSelector;
}

+ (SPCollectionUtilities*) sharedInstance;

- (id) init;

@property (NS_NONATOMIC_IOSONLY, copy) NSString *rootPath;

- (NSString*) pathOfRandomCollectionItemInPath:(NSString*)root;

- (NSString*) collectionNameOfPath:(NSString*)path;
- (NSString*) makePathRelativeToCollectionRoot:(NSString*)absolutePath;
- (NSString*) absolutePathFromRelativePath:(NSString*)relativePath;

- (void) downloadRsyncMirrorsListAndNotify:(SEL)selector ofTarget:(id)target;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSMutableArray *rsyncMirrorList;

@end

@interface NSString (PathUtilities)

+ (NSString*) commonRootPathOfFilename:(NSString*)filename andFilename:(NSString*)otherFilename;
- (NSString*) stringByRemovingPrefix:(NSString *)prefix;
- (NSString*) relativePathToFilename:(NSString*)otherFilename;

@end
