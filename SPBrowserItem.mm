#import "SPBrowserItem.h"
#import "SongLengthDatabase.h"
#import "SPCollectionUtilities.h"
#import "SPPlaylist.h"
#import "SPPlaylistItem.h"


@implementation SPBrowserItem

// ----------------------------------------------------------------------------
- (id) initWithPath:(NSString*)thePath isFolder:(BOOL)folder forParent:(SPBrowserItem*)parentItem withDefaultSubtune:(NSInteger)subtuneIndex
// ----------------------------------------------------------------------------
{
    if (self = [super init]) 
	{
		if (thePath == nil)
			return nil;
			
		isFolder = folder;
		path = thePath;
		children = nil;
		parent = parentItem;
		playlistIndex = 0;
		loopCount = 0;
		fileDoesNotExist = NO;
		
		if (folder)
		{
			title = [path lastPathComponent];
			author = @"";
			releaseInfo = @"";
			
			defaultSubTune = 0;
			subTuneCount = 0;
			[self setPlayTimeInSeconds:0];
		}
		else
		{
			FILE* fileHandle = fopen([thePath cStringUsingEncoding:[NSString defaultCStringEncoding]], "rb");
			if (fileHandle == NULL)
			{
				title = @"* FILE NOT FOUND *";
				author = @"UNKNOWN";
				releaseInfo = @"UNKNOWN";
				
				defaultSubTune = 0;
				subTuneCount = 0;
				[self setPlayTimeInSeconds:0];
				
				fileDoesNotExist = YES;
			}
			else
			{
				static const int max_tunesize = 65536 + 0x7c;
				static char filebuffer[max_tunesize];
				size_t length = fread(filebuffer, 1, max_tunesize, fileHandle);
				fclose(fileHandle);

				if (filebuffer[0] != 'P' && filebuffer[0] != 'R')
					return nil;

				if ( filebuffer[1] != 'S' ||
					 filebuffer[2] != 'I' ||
					 filebuffer[3] != 'D' )
				{
					return nil;
				}

				subTuneCount = *(unsigned short*)(filebuffer + 0x0e);
				defaultSubTune = *(unsigned short*)(filebuffer + 0x10);

#if TARGET_RT_LITTLE_ENDIAN
				subTuneCount = Endian16_Swap(subTuneCount);
				defaultSubTune = Endian16_Swap(defaultSubTune);
#endif		
			
				if (subtuneIndex != 0)
					defaultSubTune = subtuneIndex;
			
				const int maxStringLength = 32;
				char titleBuf[maxStringLength + 1];
				memcpy(titleBuf, filebuffer + 0x16, maxStringLength);
				titleBuf[maxStringLength] = 0;
				title = [NSString stringWithCString:titleBuf encoding:NSISOLatin1StringEncoding];

				char authorBuf[maxStringLength + 1];
				memcpy(authorBuf, filebuffer + 0x36, maxStringLength);
				authorBuf[maxStringLength] = 0;
				author = [NSString stringWithCString:authorBuf encoding:NSISOLatin1StringEncoding];

				char releasedBuf[maxStringLength + 1];
				memcpy(releasedBuf, filebuffer + 0x56, maxStringLength);
				releasedBuf[maxStringLength] = 0;
				releaseInfo = [NSString stringWithCString:releasedBuf encoding:NSISOLatin1StringEncoding];
				
				int playtime = [[SongLengthDatabase sharedInstance] getSongLengthFromBuffer:filebuffer withBufferLength:length andSubtune:defaultSubTune];
				[self setPlayTimeInSeconds:playtime];
			}
		}
	}
	
    return self;
}


// ----------------------------------------------------------------------------
- (id) initWithMetaDataItem:(NSMetadataItem*)item
// ----------------------------------------------------------------------------
{
    if (self = [super init]) 
	{
		isFolder = NO;
		children = nil;
		parent = nil;
		playlistIndex = 0;
		loopCount = 0;

		title = [item valueForAttribute:@"kMDItemTitle"];
		author = [item valueForAttribute:@"kMDItemComposer"]; 
		releaseInfo = [item valueForAttribute:@"org_sidmusic_Released"]; 
		defaultSubTune = [[item valueForAttribute:@"org_sidmusic_DefaultSubtune"] integerValue]; 
		subTuneCount = [[item valueForAttribute:@"org_sidmusic_SubtuneCount"] integerValue]; 
		path = [item valueForAttribute:@"kMDItemPath"];
		
		int playtime = [[SongLengthDatabase sharedInstance] getSongLengthByPath:path andSubtune:defaultSubTune];
		[self setPlayTimeInSeconds:playtime];
	}
	
	return self;
}


// ----------------------------------------------------------------------------
+ (void) fillArray:(NSMutableArray*)browserItems withDirectoryContentsAtPath:(NSString*)rootPath andParent:(SPBrowserItem*)parentItem
// ----------------------------------------------------------------------------
{
	NSDirectoryEnumerator* enumerator = [[NSFileManager defaultManager] enumeratorAtPath:rootPath];
	NSString* file;

	while(file = [enumerator nextObject])
	{
		if ([file characterAtIndex:0] == '.')
		{
			[enumerator skipDescendents];
			continue;
		}

		if ([file caseInsensitiveCompare:@"DOCUMENTS"] == NSOrderedSame)
		{
			[enumerator skipDescendents];
			continue;
		}

        if ([file containsString:@"_2SID"] || [file containsString:@"_3SID"])
            continue;
        
		NSString* path = [rootPath stringByAppendingPathComponent:file];
		BOOL folder = NO;
		BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&folder];
		if (!exists)
			continue;
			
		if (([[file pathExtension] caseInsensitiveCompare:@"sid"] == NSOrderedSame) || folder)
		{
			SPBrowserItem* item = [[SPBrowserItem alloc] initWithPath:path isFolder:folder forParent:parentItem withDefaultSubtune:0];
			if (item != nil)
				[browserItems addObject:item];
		}
		
		if (folder)
			[enumerator skipDescendents];
	}
}


// ----------------------------------------------------------------------------
+ (void) fillArray:(NSMutableArray*)browserItems withMetaDataQueryResults:(NSArray*)results
// ----------------------------------------------------------------------------
{
	for (id item in results)
	{
		SPBrowserItem* browserItem = [[SPBrowserItem alloc] initWithMetaDataItem:(NSMetadataItem*)item];
		[browserItems addObject:browserItem];
	}
}


// ----------------------------------------------------------------------------
+ (void) fillArray:(NSMutableArray*)browserItems withPlaylist:(SPPlaylist*)playlist
// ----------------------------------------------------------------------------
{
	for (int i = 0; i < [playlist count]; i++)
	{	
		SPPlaylistItem* playlistItem = [playlist itemAtIndex:i];
		NSString* absolutePath = [[SPCollectionUtilities sharedInstance] absolutePathFromRelativePath:[playlistItem path]];
		SPBrowserItem* browserItem = [[SPBrowserItem alloc] initWithPath:absolutePath isFolder:NO forParent:nil withDefaultSubtune:[playlistItem subtune]];
		if (browserItem != nil)
		{
			[browserItem setPlaylistIndex:i];
			[browserItem setLoopCount:[playlistItem loopCount]];
			[browserItems addObject:browserItem];
		}
	}
}


// ----------------------------------------------------------------------------
- (void) addChild:(SPBrowserItem*)item
// ----------------------------------------------------------------------------
{
	[children addObject:item];
}


// ----------------------------------------------------------------------------
- (id) childAtIndex:(int)index
// ----------------------------------------------------------------------------
{
	if (index < [children count])
		return [children objectAtIndex:index];
	else
		return nil;
}


// ----------------------------------------------------------------------------
- (BOOL) hasChildren
// ----------------------------------------------------------------------------
{
	return ([children count] > 0);
}


// ----------------------------------------------------------------------------
- (NSMutableArray*) children
// ----------------------------------------------------------------------------
{
	if (children == nil && isFolder)
	{
		children = [[NSMutableArray alloc] init];
		[SPBrowserItem fillArray:children withDirectoryContentsAtPath:path andParent:self];
	}

	return children;
}


// ----------------------------------------------------------------------------
- (SPBrowserItem*) parent;
// ----------------------------------------------------------------------------
{
	return parent;
}


// ----------------------------------------------------------------------------
- (BOOL) isFolder
// ----------------------------------------------------------------------------
{
	return isFolder;
}


// ----------------------------------------------------------------------------
- (void) setIsFolder:(BOOL)flag
// ----------------------------------------------------------------------------
{
	isFolder = flag;
}

// ----------------------------------------------------------------------------
- (NSString*) title
// ----------------------------------------------------------------------------
{
	return title;
}


// ----------------------------------------------------------------------------
- (void) setTitle:(NSString*)newTitle
// ----------------------------------------------------------------------------
{
	title = newTitle;
}


// ----------------------------------------------------------------------------
- (NSString*) author
// ----------------------------------------------------------------------------
{
	return author;
}


// ----------------------------------------------------------------------------
- (void) setAuthor:(NSString*)newAuthor
// ----------------------------------------------------------------------------
{
	author = newAuthor;
}


// ----------------------------------------------------------------------------
- (NSString*) releaseInfo
// ----------------------------------------------------------------------------
{
	return releaseInfo;
}


// ----------------------------------------------------------------------------
- (void) setReleaseInfo:(NSString*)newReleaseInfo
// ----------------------------------------------------------------------------
{
	releaseInfo = newReleaseInfo;
}


// ----------------------------------------------------------------------------
- (NSString*) path
// ----------------------------------------------------------------------------
{
	return path;
}


// ----------------------------------------------------------------------------
- (void) setPath:(NSString*)newPath
// ----------------------------------------------------------------------------
{
	path = newPath;
}


// ----------------------------------------------------------------------------
- (int) playTimeInSeconds
// ----------------------------------------------------------------------------
{
	return playTimeInSeconds;
}


// ----------------------------------------------------------------------------
- (void) setPlayTimeInSeconds:(int)seconds
// ----------------------------------------------------------------------------
{
	playTimeInSeconds = seconds;
	
	playTimeMinutes = playTimeInSeconds / 60;
	playTimeSeconds = playTimeInSeconds - (playTimeMinutes * 60);
	
	if (playTimeMinutes > 99)
		playTimeMinutes = 99;

	if (playTimeSeconds > 59)
		playTimeSeconds = 59;
}


// ----------------------------------------------------------------------------
- (int) playTimeMinutes
// ----------------------------------------------------------------------------
{
	return playTimeMinutes;
}


// ----------------------------------------------------------------------------
- (int) playTimeSeconds
// ----------------------------------------------------------------------------
{
	return playTimeSeconds;
}


// ----------------------------------------------------------------------------
- (unsigned short) defaultSubTune
// ----------------------------------------------------------------------------
{
	return defaultSubTune;
}


// ----------------------------------------------------------------------------
- (void) setDefaultSubTune:(unsigned short)subtune
// ----------------------------------------------------------------------------
{
	defaultSubTune = subtune;
}


// ----------------------------------------------------------------------------
- (unsigned short) subTuneCount
// ----------------------------------------------------------------------------
{
	return subTuneCount;
}


// ----------------------------------------------------------------------------
- (void) setSubTuneCount:(unsigned short)count
// ----------------------------------------------------------------------------
{
	subTuneCount = count;
}


// ----------------------------------------------------------------------------
- (NSInteger) playlistIndex
// ----------------------------------------------------------------------------
{
	return playlistIndex;
}


// ----------------------------------------------------------------------------
- (void) setPlaylistIndex:(NSInteger)indexValue
// ----------------------------------------------------------------------------
{
	playlistIndex = indexValue;
}


// ----------------------------------------------------------------------------
- (NSInteger) loopCount
// ----------------------------------------------------------------------------
{
	return loopCount;
}


// ----------------------------------------------------------------------------
- (void) setLoopCount:(NSInteger)count
// ----------------------------------------------------------------------------
{
	loopCount = count;
}


// ----------------------------------------------------------------------------
- (BOOL) fileDoesNotExist
// ----------------------------------------------------------------------------
{
	return fileDoesNotExist;
}


@end
