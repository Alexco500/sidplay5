#import "SPApplicationStorageController.h"


@implementation SPApplicationStorageController

static NSString* sApplicationSupportPath = nil;
static NSString* sComposerPhotoPath = nil;
static NSString* sPlaylistPath = nil;
static NSString* sVisualizerPath = nil;


// ----------------------------------------------------------------------------
+ (NSString*) applicationSupportPath
// ----------------------------------------------------------------------------
{
	if (sApplicationSupportPath == nil)
	{
		FSRef folder;
		OSErr err = FSFindFolder(kUserDomain, kApplicationSupportFolderType, false, &folder);
		if (err == noErr)
		{
			CFURLRef url =  CFURLCreateFromFSRef(kCFAllocatorDefault, &folder);
			sApplicationSupportPath = [(__bridge NSURL*)url path];
			sApplicationSupportPath = [sApplicationSupportPath stringByAppendingPathComponent:@"SIDPLAY"];
		   
			BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:sApplicationSupportPath];
			if (!exists)
                [[NSFileManager defaultManager] createDirectoryAtPath:sApplicationSupportPath withIntermediateDirectories:YES attributes:nil error:NULL];
		}
	}

	return sApplicationSupportPath;
}


// ----------------------------------------------------------------------------
+ (NSString*) composerPhotoPath
// ----------------------------------------------------------------------------
{
	if (sComposerPhotoPath == nil)
	{
		sComposerPhotoPath = [[SPApplicationStorageController applicationSupportPath] stringByAppendingPathComponent:@"Photos"];

		BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:sComposerPhotoPath];
		if (!exists)
            [[NSFileManager defaultManager] createDirectoryAtPath:sComposerPhotoPath withIntermediateDirectories:YES attributes:nil error:NULL];
	}
	
	return sComposerPhotoPath;
}


// ----------------------------------------------------------------------------
+ (NSString*) playlistPath
// ----------------------------------------------------------------------------
{
	if (sPlaylistPath == nil)
	{
		sPlaylistPath = [[SPApplicationStorageController applicationSupportPath] stringByAppendingPathComponent:@"Playlists"];

		BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:sPlaylistPath];
		if (!exists)
            [[NSFileManager defaultManager] createDirectoryAtPath:sPlaylistPath withIntermediateDirectories:YES attributes:nil error:NULL];
	}
	
	return sPlaylistPath;
}


// ----------------------------------------------------------------------------
+ (NSString*) visualizerPath
// ----------------------------------------------------------------------------
{
	if (sVisualizerPath == nil)
	{
		sVisualizerPath = [[SPApplicationStorageController applicationSupportPath] stringByAppendingPathComponent:@"Visualizers"];

		BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:sVisualizerPath];
		if (!exists)
            [[NSFileManager defaultManager] createDirectoryAtPath:sVisualizerPath withIntermediateDirectories:YES attributes:nil error:NULL];
	}
	
	return sVisualizerPath;
}


@end
