#import "SPInfoContainerView.h"
#import "SPOscilloscopeView.h"
#import "SPPlayerWindow.h"
#import "PlayerLibSidplayWrapper.h"
#import "SPPreferencesController.h"
#import "SPColorProvider.h"


@implementation SPOscilloscopeView

// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[super awakeFromNib];

	index = OSCILLOSCOPE_CONTAINER_INDEX;
	height = 128.0f;
	[self setCollapsed:gPreferences.mOscilloscopeCollapsed];

	[container addInfoView:self atIndex:index];
}

@end


@implementation SPOscilloscopeContentView

// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	bloomFilterActive = YES;

    if (bloomFilterActive)
    {
        [self setWantsLayer:YES];
        CIFilter *filter = [CIFilter filterWithName:@"CIBloom"];
        [filter setDefaults];
        [filter setValue:@4.0f forKey:@"inputRadius"];
        filter.name = @"bloomFilter";
        self.contentFilters = @[filter];
    }
}


// ----------------------------------------------------------------------------
- (void) mouseDown:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	[super mouseDown:event];
	
//    bloomFilterActive = !bloomFilterActive;
//    
//    if (bloomFilterActive)
//    {
//        [self setWantsLayer:YES];
//        CIFilter *filter = [CIFilter filterWithName:@"CIBloom"]; 
//        [filter setDefaults]; 
//        [filter setValue:[NSNumber numberWithFloat:4.0f] forKey:@"inputRadius"]; 
//        [filter setName:@"bloomFilter"]; 
//        [self setContentFilters:[NSArray arrayWithObject:filter]];
//    }
//    else
//    {
//        [self setWantsLayer:NO];
//    }
//    
//    [self setNeedsDisplay:YES];
}


// ----------------------------------------------------------------------------
- (void) drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
    NSRect bounds = self.bounds;

    CGRect contextRect;
	contextRect.origin.x = rect.origin.x;
	contextRect.origin.y = rect.origin.y;
	contextRect.size.width = rect.size.width;
	contextRect.size.height = rect.size.height;

	CGContextRef context = (CGContextRef) [NSGraphicsContext currentContext].graphicsPort;

	SPInfoContainerView* container = self.enclosingScrollView.documentView;

	if ([container hasDarkBackground])
		CGContextSetRGBFillColor(context, 0.0f, 0.0f, 0.0f, 0.6f);
	else
		CGContextSetRGBFillColor(context, 0.0f, 0.0f, 0.0f, 1.0f);
	CGContextFillRect(context, contextRect);

	if ([[container ownerWindow] audioDriverIsAvailable] == NO)
		return;
	
	float fadeVolume = [[container ownerWindow] fadeVolume];
	
    short* sampleBuffer = [[container ownerWindow] audioDriverSampleBuffer];
    bool isPlaying = [[container ownerWindow] audioDriverIsPlaying];
	
	float zeroLineHeight = contextRect.size.height * 0.5f + 0.5f;
	float width = contextRect.size.width;
	float height = contextRect.size.height;
	
	if (isPlaying)
		CGContextSetRGBStrokeColor(context, 0.2f, 1.0f, 1.0f, 1.0f);
	else
	{
		float error = 0.1f * (random() & 0xffff) / 65535.0f;
		float brightness = error + 0.9f;
		
		CGContextSetRGBStrokeColor(context, 0.2f, brightness, brightness, 1.0f);
	}

	CGContextBeginPath(context);
	CGContextSetLineWidth(context, 1.2f);
	
	if (isPlaying && sampleBuffer != NULL)
	{
		static CGPoint linePoints[1024];
		
		for (int i = 0; i < width; i++)
		{
			linePoints[i].x = i + 0.5f;
			linePoints[i].y = zeroLineHeight + fadeVolume * (sampleBuffer[i] * height * 1.8f / 65536.0f);
		}

		CGContextAddLines(context, linePoints, width);
		CGContextDrawPath(context, kCGPathStroke);
		
		/*
		PlayerLibSidplay* player = (PlayerLibSidplay*) [[container ownerWindow] player];
		if (player != NULL)
		{
			CGContextSelectFont(context, "Lucida Grande", 10.0f, kCGEncodingFontSpecific); 
			CGContextSetRGBStrokeColor(context, 1.0f, 1.0f, 1.0f, 0.9f);
			CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 0.9f);

			CGAffineTransform textTransform = CGAffineTransformMakeScale(1.0f, -1.0f);
			CGContextSetTextMatrix(context, textTransform);
			CGContextSetTextDrawingMode(context, kCGTextFill);

			const int descriptionStringLength = 1023;
			char descriptionString[descriptionStringLength + 1];

			snprintf(descriptionString, descriptionStringLength, "%s - %s (%d/%d)", player->getCurrentAuthor(), player->getCurrentTitle(), player->getCurrentSubtune(), player->getSubtuneCount());

			CGContextShowTextAtPoint(context, contextRect.origin.x + 3.0f, contextRect.origin.y + 10.0f, descriptionString, strlen(descriptionString));			
		}
		*/
	}
	else
	{
		static CGPoint linePoints[2];
		linePoints[0].x = contextRect.origin.x;
		linePoints[0].y = zeroLineHeight;
		linePoints[1].x = width;
		linePoints[1].y = zeroLineHeight;

		CGContextAddLines(context, linePoints, 2);
		CGContextDrawPath(context, kCGPathFillStroke);
	}
	
    NSColor* darkColor = nil;
    NSColor* brightColor = nil;
    darkColor = [NSColor colorWithDeviceRed:0.117f green:0.117f blue:0.117f alpha:1.0f];
    brightColor = [NSColor colorWithDeviceRed:0.321f green:0.321f blue:0.321f alpha:1.0f];
    
    [darkColor set];
    NSFrameRect(bounds);
    bounds = NSInsetRect(bounds, 1.0f, 1.0f);
    [brightColor set];
    NSFrameRect(bounds);
}

@end
