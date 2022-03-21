#import <Cocoa/Cocoa.h>


@interface SPCollectionUtilities : NSObject
{
	NSString* rootPath;
	
	NSMutableData* ryncMirrorListData;
	NSURLConnection* rsyncMirrorListUrlConnection;
	NSMutableArray* rsyncMirrorList;
	id rsyncMirrorListNotificationTarget;
	SEL rsyncMirrorListNotificationSelector;
}

+ (SPCollectionUtilities*) sharedInstance;

- (id) init;

- (NSString*) rootPath;
- (void) setRootPath:(NSString*)path;

- (NSString*) pathOfRandomCollectionItemInPath:(NSString*)root;

- (NSString*) collectionNameOfPath:(NSString*)path;
- (NSString*) makePathRelativeToCollectionRoot:(NSString*)absolutePath;
- (NSString*) absolutePathFromRelativePath:(NSString*)relativePath;

- (void) downloadRsyncMirrorsListAndNotify:(SEL)selector ofTarget:(id)target;
- (NSMutableArray*) rsyncMirrorList;

@end

@interface NSString (PathUtilities)

+ (NSString*) commonRootPathOfFilename:(NSString*)filename andFilename:(NSString*)otherFilename;
- (NSString*) stringByRemovingPrefix:(NSString *)prefix;
- (NSString*) relativePathToFilename:(NSString*)otherFilename;

@end