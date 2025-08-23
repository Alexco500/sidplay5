#import "SPCollectionUtilities.h"
#import "SPStilBrowserController.h"
#import "SPPreferencesController.h"
#import "SPPlayerWindow.h"


@implementation SPCollectionUtilities

static SPCollectionUtilities* sharedInstance = nil;

// ----------------------------------------------------------------------------
+ (SPCollectionUtilities*) sharedInstance
{
    if (sharedInstance == nil)
        sharedInstance = [[SPCollectionUtilities alloc] init];
    
    return sharedInstance;
}

// ----------------------------------------------------------------------------
- (id) init
{
    self = [super init];
    if (self != nil)
    {
        rootPath = nil;
        
        rsyncMirrorList = [[NSMutableArray alloc] init];
    }
    return self;
}

// ----------------------------------------------------------------------------
- (NSString*) rootPath
{
    return rootPath;
}

// ----------------------------------------------------------------------------
- (void) setRootPath:(NSString*)path
{
    rootPath = path;
    [[SPStilBrowserController sharedInstance] setCollectionRootPath:path];
}

// ----------------------------------------------------------------------------
- (NSString*) pathOfRandomCollectionItemInPath:(NSString*)root
{
    if (rootPath == nil)
        return nil;
    
    if (root == nil)
        root = rootPath;
    
    // Get directories in root
    NSArray* rootItems = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:NULL];
    NSMutableDictionary* folderItemCounts = [NSMutableDictionary dictionaryWithCapacity:rootItems.count];
    
    int totalFiles = 0;
    
    for(NSString* file in rootItems)
    {
        if ([file characterAtIndex:0] == '.')
            continue;
        
        if ([file caseInsensitiveCompare:@"DOCUMENTS"] == NSOrderedSame)
            continue;
        
        NSString* path = [root stringByAppendingPathComponent:file];
        
        BOOL folder = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&folder];
        
        if (folder)
        {
            NSArray* folderItems = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
            folderItemCounts[path] = @((int)folderItems.count);
        }
        else
            totalFiles++;
    }
    
    //NSLog(@"folderItemCounts: %@\n", folderItemCounts);
    
    NSArray* folders = folderItemCounts.allKeys;
    int totalSubFolders = 0;
    for (NSString* folder in folders)
    {
        totalSubFolders += [folderItemCounts[folder] integerValue];
    }
    
    if (totalSubFolders == 0 && totalFiles != 0)
    {
        int randomFileIndex = random() % totalFiles;
        //NSLog(@"total sub folders: %d, totalFiles: %d, random: %d\n", totalSubFolders, totalFiles, randomFileIndex);
        NSString* randomFile = rootItems[randomFileIndex];
        if ([randomFile.pathExtension caseInsensitiveCompare:@"sid"] == NSOrderedSame)
            return [root stringByAppendingPathComponent:randomFile];
    }
    
    if (totalSubFolders == 0)
        return nil;
    
    int randomSubFolder = random() % totalSubFolders;
    //NSLog(@"total sub folders: %d, random: %d\n", totalSubFolders, randomSubFolder);
    
    NSString* folderToPick = nil;
    int subFolderIndex = 0;
    
    for (NSString* folder in folders)
    {
        int oldSubFolderIndex = subFolderIndex;
        
        NSInteger itemCount = [folderItemCounts[folder] integerValue];
        folderToPick = folder;
        
        subFolderIndex += itemCount;
        
        if (oldSubFolderIndex <= randomSubFolder && subFolderIndex > randomSubFolder)
        {
            subFolderIndex = randomSubFolder - oldSubFolderIndex;
            break;
        }
    }
    
    //NSLog(@"pick: %@, subfolder %d\n", folderToPick, subFolderIndex);
    
    NSArray* subFolders = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folderToPick error:NULL];
    NSString* subFolder = subFolders[subFolderIndex];
    NSString* path = [folderToPick stringByAppendingPathComponent:subFolder];
    
    BOOL folder = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&folder];
    if (folder && exists)
    {
        return [self pathOfRandomCollectionItemInPath:path];
    }
    else
    {
        if (exists && ([path.pathExtension caseInsensitiveCompare:@"sid"] == NSOrderedSame) )
            return path;
        else
            return [self pathOfRandomCollectionItemInPath:nil];
    }
}

// ----------------------------------------------------------------------------
- (NSString*) collectionNameOfPath:(NSString*)path
{
    NSString* hvscDocumentsPath = [path stringByAppendingPathComponent:@"/DOCUMENTS/hv_sids.txt"];
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:hvscDocumentsPath isDirectory:NULL];
    if (exists)
    {
        NSString* string = [NSString stringWithContentsOfFile:hvscDocumentsPath encoding:NSASCIIStringEncoding error:NULL];
        if (string != nil)
        {
            NSRange range = [string rangeOfString:@"release" options:(NSCaseInsensitiveSearch|NSLiteralSearch)];
            if (range.location != NSNotFound)
            {
                NSRange versionRange = NSMakeRange(range.location + range.length + 1, 4);
                NSString* versionString = [string substringWithRange:versionRange];
                float version = versionString.floatValue;
                if (version == floorf(version) && version > 6.0f)
                    return [NSString stringWithFormat:@"HVSC #%d", (int) version];
                else
                    return [NSString stringWithFormat:@"HVSC %.1f", version];
            }
        }
    }
    
    return path.lastPathComponent;
}

// ----------------------------------------------------------------------------
- (NSString*) makePathRelativeToCollectionRoot:(NSString*)absolutePath
{
    if (rootPath == nil)
        return nil;
    
    NSString* commonRoot = [NSString commonRootPathOfFilename:rootPath andFilename:absolutePath];
    //NSLog(@"common path of %@ and %@: %@\n", rootPath, absolutePath, commonRoot);
    if (commonRoot != nil && ([commonRoot caseInsensitiveCompare:rootPath] == NSOrderedSame))
    {
        NSString* relativePath = [absolutePath stringByRemovingPrefix:commonRoot];
        //NSLog(@"relative: %@\n", relativePath);
        return relativePath;
    }
    
    return nil;
}

// ----------------------------------------------------------------------------
- (NSString*) absolutePathFromRelativePath:(NSString*)relativePath
{
    return [rootPath stringByAppendingPathComponent:relativePath];
}


#pragma mark -
#pragma mark sync support

static NSString* SPHvscRsyncMirrorsUrlString = @"http://www.sidmusic.org/hvsc_rsync_mirrors.txt";

// ----------------------------------------------------------------------------
- (NSMutableArray*) rsyncMirrorList
{
    return rsyncMirrorList;
}


// ----------------------------------------------------------------------------
- (void) downloadRsyncMirrorsListAndNotify:(SEL)selector ofTarget:(id)target
{
    rsyncMirrorListNotificationTarget = target;
    rsyncMirrorListNotificationSelector = selector;
    
    NSURL* url = [NSURL URLWithString:SPHvscRsyncMirrorsUrlString];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0];
    [request setValue:SPUrlRequestUserAgentString forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask* dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
        if (error != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->rsyncMirrorList removeAllObjects];
                if (self->rsyncMirrorListNotificationTarget != nil && self->rsyncMirrorListNotificationSelector != 0)
                    [self->rsyncMirrorListNotificationTarget performSelector:self->rsyncMirrorListNotificationSelector];
            });
            return;
        }
        
        if (data == nil)
            return;
            
        NSString* rsyncMirrorsListString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        
        if (rsyncMirrorsListString == nil)
            return;
        
        NSArray* rsyncMirrors = [rsyncMirrorsListString componentsSeparatedByString:@"\n"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->rsyncMirrorList removeAllObjects];
            
            for (NSString* rsyncMirror in rsyncMirrors)
            {
                if (rsyncMirror.length == 0 || [rsyncMirror characterAtIndex:0] == '#')
                    continue;
                
                [self->rsyncMirrorList addObject:rsyncMirror];
            }
            // add a fixed mirror
            [self->rsyncMirrorList addObject:@"rsync://mos6581.de/mirror/hvsc"];
            
            if (self->rsyncMirrorListNotificationTarget != nil && self->rsyncMirrorListNotificationSelector != 0)
                [self->rsyncMirrorListNotificationTarget performSelector:self->rsyncMirrorListNotificationSelector];
        });
    }];
    
    [dataTask resume];
}


@end


#pragma mark -
@implementation NSString (PathUtilities)

// ----------------------------------------------------------------------------
+ (NSString*) commonRootPathOfFilename:(NSString*)filename andFilename:(NSString*)otherFilename
{
    NSArray* filenameArray = filename.pathComponents;
    NSArray* otherArray = otherFilename.stringByStandardizingPath.pathComponents;
    
    int minLength = (int) MIN([filenameArray count], [otherArray count]);
    
    NSMutableArray* resultArray = [NSMutableArray arrayWithCapacity:minLength];
    
    for (int i = 0; i < minLength; i++)
        if ([filenameArray[i] caseInsensitiveCompare:otherArray[i]] == NSOrderedSame)
            [resultArray addObject:filenameArray[i]];
    
    if (resultArray.count == 0)
        return nil;
    
    return [NSString pathWithComponents:resultArray];
}

// ----------------------------------------------------------------------------
- (NSString *)stringByRemovingPrefix:(NSString *)prefix
{
    NSRange aRange;
    
    aRange = [self rangeOfString:prefix options:NSCaseInsensitiveSearch];
    if ((aRange.length == 0) || (aRange.location != 0))
        return self;
    return [self substringFromIndex:aRange.location + aRange.length];
}

// ----------------------------------------------------------------------------
- (NSString*) relativePathToFilename:(NSString*)otherFilename
{
    NSString* commonRoot = [[NSString commonRootPathOfFilename:self andFilename:otherFilename] stringByAppendingString:@"/"];
    if (commonRoot == nil)
        return otherFilename;
    
    NSString* uniquePart = [self.stringByStandardizingPath stringByRemovingPrefix:commonRoot];
    NSString* otherUniquePart = [otherFilename.stringByStandardizingPath stringByRemovingPrefix:commonRoot];
    
    int numberOfStepsUp = (int)uniquePart.pathComponents.count;
    if (![self hasSuffix:@"/"])
        numberOfStepsUp--; // Assume we're not a directory unless we end in /. May result in incorrect paths, but we can't do much about it.
    
    NSMutableString* stepsUpString = [NSMutableString stringWithCapacity:(numberOfStepsUp * 3)];
    for (int i = 0; i < numberOfStepsUp; i++) {
        [stepsUpString appendString:@".."];
        [stepsUpString appendString:@"/"];
    }
    
    return [stepsUpString stringByAppendingString:otherUniquePart].stringByStandardizingPath;
}

@end
