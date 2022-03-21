#import "SPHttpBrowserItem.h"
#import "SPPlayerWindow.h"
#import "SPPlaylist.h"
#import "SPPlaylistItem.h"
#import "SongLengthDatabase.h"
#import "SPURLConnectionScheduler.h"


NSString* SPHttpBrowserItemInfoDownloadedNotification = @"SPHttpBrowserItemInfoDownloadedNotification";
NSString* SPHttpBrowserItemIndexDownloadedNotification = @"SPHttpBrowserItemIndexDownloadedNotification"; 

@implementation SPHttpBrowserItem


// ----------------------------------------------------------------------------
- (id) initWithURLString:(NSString*)urlString isFolder:(BOOL)folder forParent:(SPBrowserItem*)parentItem
// ----------------------------------------------------------------------------
{
    if (self = [super init]) 
	{
		if (urlString == nil)
			return nil;
			
		isFolder = folder;
		path = urlString;
		children = nil;
		parent = parentItem;
		fileDoesNotExist = NO;
		
		if (folder)
		{
			title = [path lastPathComponent];
            isValid = YES;
		}
		else
		{
            // Intermediate title
            title = [[path lastPathComponent] stringByDeletingPathExtension];
			author = @"<LOADING...>";
			releaseInfo = @"<LOADING...>";
            isValid = NO;

            NSURL* url = [NSURL URLWithString:path];

            NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
            [request setValue:SPUrlRequestUserAgentString forHTTPHeaderField:@"User-Agent"];
            downloadData = [NSMutableData data];
			[[SPURLConnectionScheduler sharedInstance] scheduleRequest:request withDelegate:self andPriority:0];
            //downloadConnection = [NSURLConnection connectionWithRequest:request delegate:self];
			//NSLog(@"Downloading %@\n", path);
		}
	}
	
    return self;
}


// ----------------------------------------------------------------------------
- (void) connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
// ----------------------------------------------------------------------------
{
	if (connection == indexDownloadConnection)
		[indexData setLength:0];
	else
		[downloadData setLength:0];
}


// ----------------------------------------------------------------------------
- (void) connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
// ----------------------------------------------------------------------------
{
	if (connection == indexDownloadConnection)
		[indexData appendData:data];
	else
		[downloadData appendData:data];
}


// ----------------------------------------------------------------------------
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
// ----------------------------------------------------------------------------
{
	if (connection == indexDownloadConnection)
	{
		if (indexData == nil)
			return;

		NSString* indexDataString = [[NSString alloc] initWithData:indexData encoding:NSUTF8StringEncoding];
		
		NSArray* indexDataItems = [indexDataString componentsSeparatedByString:@"\n"];
		
		[SPHttpBrowserItem fillArray:children withIndexDataItems:indexDataItems fromUrl:path andParent:nil];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:SPHttpBrowserItemIndexDownloadedNotification object:self];
		
		indexData = nil;
		indexDownloadConnection = nil;
	}
	else
	{
		char* dataBuffer = (char*) [downloadData bytes];
		int length = [downloadData length];
		
		if ((dataBuffer[0] != 'P' && dataBuffer[0] != 'R') ||
			dataBuffer[1] != 'S' ||
			dataBuffer[2] != 'I' ||
			dataBuffer[3] != 'D' )
		{
			title = @"* FILE NOT FOUND *";
			author = @"UNKNOWN";
			releaseInfo = @"UNKNOWN";
			
			defaultSubTune = 0;
			subTuneCount = 0;
			[self setPlayTimeInSeconds:0];
			
			fileDoesNotExist = YES;
			[[NSNotificationCenter defaultCenter] postNotificationName:SPHttpBrowserItemInfoDownloadedNotification object:self];
		}
		else
		{
			int presetSubtuneIndex = defaultSubTune;
			
			subTuneCount = *(unsigned short*)(dataBuffer + 0x0e);
			defaultSubTune = *(unsigned short*)(dataBuffer + 0x10);
			
	#if TARGET_RT_LITTLE_ENDIAN
			subTuneCount = Endian16_Swap(subTuneCount);
			defaultSubTune = Endian16_Swap(defaultSubTune);
	#endif		
			
			if (presetSubtuneIndex != 0)
				defaultSubTune = presetSubtuneIndex;
			
			const int maxStringLength = 32;
			char titleBuf[maxStringLength + 1];
			memcpy(titleBuf, dataBuffer + 0x16, maxStringLength);
			titleBuf[maxStringLength] = 0;
			title = [NSString stringWithCString:titleBuf encoding:NSISOLatin1StringEncoding];
			
			char authorBuf[maxStringLength + 1];
			memcpy(authorBuf, dataBuffer + 0x36, maxStringLength);
			authorBuf[maxStringLength] = 0;
			author = [NSString stringWithCString:authorBuf encoding:NSISOLatin1StringEncoding];
			
			char releasedBuf[maxStringLength + 1];
			memcpy(releasedBuf, dataBuffer + 0x56, maxStringLength);
			releasedBuf[maxStringLength] = 0;
			releaseInfo = [NSString stringWithCString:releasedBuf encoding:NSISOLatin1StringEncoding];
			
			int playtime = [[SongLengthDatabase sharedInstance] getSongLengthFromBuffer:dataBuffer withBufferLength:length andSubtune:defaultSubTune];
			[self setPlayTimeInSeconds:playtime];
		}
		
		isValid = YES;
		[[NSNotificationCenter defaultCenter] postNotificationName:SPHttpBrowserItemInfoDownloadedNotification object:self];
		
		downloadData = nil;
		//downloadConnection = nil;
		
		[[SPURLConnectionScheduler sharedInstance] connectionDidFinish:connection ofSender:self];
	}
}


// ----------------------------------------------------------------------------
- (void) cancelDownload
// ----------------------------------------------------------------------------
{
	/*
	if (downloadConnection != nil)
	{
		[downloadConnection cancel];
		downloadConnection = nil;
	}
	*/
    
    if (downloadData != nil)
    {
        //NSLog(@"Canceling request for %@\n", path);
        [[SPURLConnectionScheduler sharedInstance] cancelRequestsForDelegate:self];
        downloadData = nil;
    }
}


// ----------------------------------------------------------------------------
- (void) finalize
// ----------------------------------------------------------------------------
{
    [self cancelDownload];
	[super finalize];
}


// ----------------------------------------------------------------------------
- (BOOL) isValid
// ----------------------------------------------------------------------------
{
    return isValid;
}


// ----------------------------------------------------------------------------
+ (void) fillArray:(NSMutableArray*)browserItems withIndexDataItems:(NSArray*)indexItems fromUrl:(NSString*)urlString andParent:(SPBrowserItem*)parentItem
// ----------------------------------------------------------------------------
{
    for (NSString* indexItem in indexItems)
    {
        if ([indexItem length] == 0)
            continue;
            
        BOOL isFolder = [indexItem hasSuffix:@"/"];

        NSString* newUrlString = [NSString stringWithFormat:@"%@%@", urlString, indexItem];
        
		SPHttpBrowserItem* item = [[SPHttpBrowserItem alloc] initWithURLString:newUrlString isFolder:isFolder forParent:parentItem];
		if (item != nil)
			[browserItems addObject:item];
    }
}


// ----------------------------------------------------------------------------
+ (void) fillArray:(NSMutableArray*)browserItems withSharedPlaylist:(SPPlaylist*)playlist fromUrl:(NSString*)urlString
// ----------------------------------------------------------------------------
{
	for (int i = 0; i < [playlist count]; i++)
	{	
		SPPlaylistItem* playlistItem = [playlist itemAtIndex:i];
        NSString* absoluteURLString = [NSString stringWithFormat:@"%@%@", urlString, [playlistItem path]];
		SPBrowserItem* browserItem = [[SPHttpBrowserItem alloc] initWithURLString:absoluteURLString isFolder:NO forParent:nil];
		if (browserItem != nil)
		{
			[browserItem setPlaylistIndex:i];
			[browserItem setLoopCount:[playlistItem loopCount]];
			[browserItem setDefaultSubTune:[playlistItem subtune]];
			[browserItems addObject:browserItem];
		}
	}
}


// ----------------------------------------------------------------------------
- (NSMutableArray*) children
// ----------------------------------------------------------------------------
{
	if (children == nil && isFolder)
	{
		children = [[NSMutableArray alloc] init];

		NSURL* url = [NSURL URLWithString:path];
		NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
		[request setValue:SPUrlRequestUserAgentString forHTTPHeaderField:@"User-Agent"];
		indexData = [NSMutableData data];
		indexDownloadConnection = [NSURLConnection connectionWithRequest:request delegate:self];
	}
	
	return children;
}

@end
