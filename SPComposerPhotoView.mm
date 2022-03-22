#import "SPInfoContainerView.h"
#import "SPComposerPhotoView.h"
#import "SPApplicationStorageController.h"
#import "SPPlayerWindow.h"
#import "PlayerLibSidplay.h"
#import "SPPreferencesController.h"


#if 1

@implementation SPComposerPhotoView


static NSString* SPComposerUrlPrefix = @"http://twinbirds.com/sidplay/composers/";


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[super awakeFromNib];

	index = COMPOSER_CONTAINER_INDEX;
	height = 122.0f;
	collapsedHeight = 21.0f;
	player = NULL;
	imageDownloadInProgress = NO;
	imageDownload = nil;
	currentImageLocation = nil;

	[self setCollapsed:gPreferences.mComposerPhotoCollapsed];
	[container addInfoView:self atIndex:index];
	[self setImageFromPath:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTuneInfo:) name:SPTuneChangedNotification object:nil];
}


// ----------------------------------------------------------------------------
- (void) updateTuneInfo:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	if (player == NULL)
		player = (PlayerLibSidplay*) [[container ownerWindow] player];

	if (player != NULL && player->isTuneLoaded())
	{
		if (player->hasTuneInformationStrings())
			[self updateWithComposerName:[NSString stringWithCString:player->getCurrentAuthor() encoding:NSISOLatin1StringEncoding]];
		else
			[self setImageFromPath:nil];
	}
}


// ----------------------------------------------------------------------------
- (void) updateWithComposerName:(NSString*)composer
// ----------------------------------------------------------------------------
{
	if (composer.length == 0)
		return;

	//if (isCollapsed)
	//	return;

	currentImageLocation = nil;
	NSString* url = nil;
	NSString* composerPath = [SPApplicationStorageController composerPhotoPath];

	// try to find handle in composer name
	NSString* name = nil;
	
	for (int i = 0; i < composer.length; i++)
	{
		if ([composer characterAtIndex:i] == '(' )
		{
			NSRange handleRange;
			handleRange.location = i + 1;
			NSRange closingBracketRange = [composer rangeOfString:@")"];
			if (closingBracketRange.location != NSNotFound)
			{
				handleRange.length = closingBracketRange.location - handleRange.location;
				name = [composer substringWithRange:handleRange];
			}
 			break;
		}
	}
	
	if (name != nil)
	{
		// if handle is longer than 3 characters, lowercase it, except for first character
		if (name.length > 3 )
		{
			NSString* lowerCasedRest = [name substringFromIndex:1].lowercaseString;
			name = [name stringByReplacingCharactersInRange:NSMakeRange(1, name.length - 1) withString:lowerCasedRest];
		}
		
		if ([name isEqualToString:@"Odie"])
			name = @"Sean_Connolly";
		else if ([name isEqualToString:@"Ratt"])
			name = @"Antony_Crowther";
		else if ([name isEqualToString:@"Mad b"])
			name = @"Youth";
		else if ([name isEqualToString:@"youth"])
			name = @"Youth";
		else if ([name isEqualToString:@"Jip"])
			name = @"Yip";
		else if ([name isEqualToString:@"Yogibear"])
			name = @"Joachim_Wijnhoven";
		else if ([name isEqualToString:@"Ranger"])
			name = @"Markus_Siebold";
		else if ([name isEqualToString:@"Diflex"])
			name = @"Markus_Schneider";
		else if ([name isEqualToString:@"Gez"])
			name = @"Gerard_Gourley";
		else if ([name isEqualToString:@"Gaxx"])
			name = @"Gavin_Raeburn";
		else if ([name isEqualToString:@"Soundemon"])
			name = @"SounDemoN";
		else if ([name isEqualToString:@"Red devil"])
			name = @"Red_Devil";
		else if ([name isEqualToString:@"The blue ninja"])
			name = @"The_Blue_Ninja";
		else if ([name isEqualToString:@"!cube"])
			name = @"Cube";
		else if ([name isEqualToString:@"The syndrom"])
			name = @"The_Syndrom";
	} 
	else
	{
		name = [NSString stringWithString:composer];

		NSRange openingBracketRange = [name rangeOfString:@"("];
		NSRange ampersandRange = [name rangeOfString:@"&"];
		NSRange slashRange = [name rangeOfString:@"/"];

		if (openingBracketRange.location != NSNotFound)
		{
			name = [name substringToIndex:openingBracketRange.location];
		}
		else if (ampersandRange.location != NSNotFound)
		{
			name = [name substringToIndex:ampersandRange.location];
		}
		else if (slashRange.location != NSNotFound)
		{
			name = [name substringToIndex:slashRange.location];
		}

		name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

		if ([name isEqualToString:@"Jens-Christian Huus"])
			name = @"JCH";
		else if ([name isEqualToString:@"Tomas Danko"])
			name = @"Danko";
		else if ([name isEqualToString:@"Chris Hülsbeck"])
			name = @"Chris_Huelsbeck";
		else if ([name isEqualToString:@"Jori Olkkonen"])
			name = @"Yip";
		else if ([name isEqualToString:@"Fredrik Segerfalk"])
			name = @"Moppe";
		else if ([name isEqualToString:@"Glenn Rune Gallefoss"])
			name = @"GRG";
		else if ([name isEqualToString:@"Jeroen Kimmel"])
			name = @"Red";
		else if ([name isEqualToString:@"Kristian Røstøen"])
			name = @"Kristian_Roestoeen";
	}
	
	name = [name stringByReplacingOccurrencesOfString:@" " withString:@"_"];
	NSString* fileName = [NSString stringWithFormat:@"%@.jpg", name];
	
	url = [SPComposerUrlPrefix stringByAppendingString:fileName];
	NSString* destinationPath = [composerPath stringByAppendingPathComponent:fileName];
	currentImageLocation = destinationPath;
	
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:destinationPath];
	
	if (exists)
		[self setImageFromPath:currentImageLocation];
	else
	{
		NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
		[request setValue:SPUrlRequestUserAgentString forHTTPHeaderField:@"User-Agent"];
		
		if (imageDownload != nil)
			[imageDownload cancel];
		   
		// create the connection with the request and start loading the data 
		imageDownload = [[NSURLDownload alloc] initWithRequest:request delegate:self]; 
		if (imageDownload) 
		{
			//NSLog(@"Created download %@ for %@\n", imageDownload, url);
			[imageDownload setDestination:destinationPath allowOverwrite:YES]; 
			imageDownloadInProgress = YES;
		}	
	}
}


// ----------------------------------------------------------------------------
- (void) setImageFromPath:(NSString*)imagePath
// ----------------------------------------------------------------------------
{
	NSImage* image = nil;
	
	if (imagePath != nil)
		image = [[NSImage alloc] initWithContentsOfFile:imagePath];
	else
		image = [NSImage imageNamed:@"unknown_composer"];
		
	float imageWidth = image.size.width;
	float imageHeight = image.size.height;
	float diff = (imageHeight + 32.0f) - height;
	
	if (diff != 0.0f)
	{
		height = imageHeight + 32.0f;
		NSRect photoFrame = photoView.frame;
		photoFrame.origin.y -= diff;
		photoFrame.size.width = imageWidth;
		photoFrame.size.height = imageHeight;
		photoView.frame = photoFrame;	
		[container positionSubviewsWithAnimation:YES];
	}
	
	photoView.image = image;
}


#pragma mark -
#pragma mark NSURLDownload delegate methods

// ----------------------------------------------------------------------------
- (void) download:(NSURLDownload*)download didFailWithError:(NSError*)error 
// ----------------------------------------------------------------------------
{ 
	//NSLog(@"download failed: %@\n", download);

	imageDownloadInProgress = NO;
	[self setImageFromPath:nil];
} 


// ----------------------------------------------------------------------------
- (void) downloadDidFinish:(NSURLDownload*)download 
// ----------------------------------------------------------------------------
{ 
	//NSLog(@"downloadDidFinish %@\n", download);

	if (download == imageDownload)
	{
		imageDownloadInProgress = NO;
		[self setImageFromPath:currentImageLocation];
	}
} 


@end

#endif

