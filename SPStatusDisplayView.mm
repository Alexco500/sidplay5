#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLMacro.h>
#import "SPPlayerWindow.h"
#import "SPMiniPlayerWindow.h"
#import "SPStatusDisplayView.h"



@implementation SPQCView

// ----------------------------------------------------------------------------
- (instancetype)initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
	NSOpenGLPixelFormatAttribute attributes[] =
	{
		NSOpenGLPFAAccelerated,
		NSOpenGLPFADoubleBuffer,
		0
	};

	NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];

    self = [super initWithFrame:frame pixelFormat:pixelFormat];
    if (self)
	{
		GLint zeroOpacity = 0;
		[self.openGLContext setValues:&zeroOpacity forParameter:NSOpenGLCPSurfaceOpacity];
		
		renderer = nil;
		rendererActive = NO;
        rendererVisible = NO;
	}
    return self;
}


// ----------------------------------------------------------------------------
- (void) prepareForQuit
// ----------------------------------------------------------------------------
{
	[self stopRendering];
    [NSThread sleepForTimeInterval:0.5f];
    renderer = nil;
}


// ----------------------------------------------------------------------------
- (BOOL)isOpaque
// ----------------------------------------------------------------------------
{
	return NO;
}


// ----------------------------------------------------------------------------
- (void) loadCompositionFromFile:(NSString*)path
// ----------------------------------------------------------------------------
{
	NSOpenGLContext* context = self.openGLContext;
    CGLContextObj cgl_ctx = (CGLContextObj) context.CGLContextObj;
    [context update];
    glViewport(0, 0, [self frame].size.width, [self frame].size.height);

    renderer = [[QCRenderer alloc] initWithOpenGLContext:self.openGLContext pixelFormat:self.pixelFormat file:path];
}


// ----------------------------------------------------------------------------
- (void) setEraseColor:(NSColor*)color
// ----------------------------------------------------------------------------
{
	eraseColor = color;
}


// ----------------------------------------------------------------------------
- (void) startRendering
// ----------------------------------------------------------------------------
{
	if (renderer == nil)
		return;
		
	if (rendererActive)
		return;
		
	rendererActive = YES;
	[NSThread detachNewThreadSelector:@selector(renderThread:) toTarget:self withObject:self];
}


// ----------------------------------------------------------------------------
- (void) stopRendering
// ----------------------------------------------------------------------------
{
	rendererActive = NO;
}


// ----------------------------------------------------------------------------
- (void) setRendererVisible:(BOOL)visible
// ----------------------------------------------------------------------------
{
    rendererVisible = visible;
}


// ----------------------------------------------------------------------------
- (void) renderThread:(id)object
// ----------------------------------------------------------------------------
{
    //NSLog(@"Rendering thread start");
    
    NSOpenGLContext* context = self.openGLContext;
    CGLContextObj cgl_ctx = (CGLContextObj) context.CGLContextObj;
    
    NSTimeInterval startTime = 0;
    int skipUpdateCount = 10;
    
    while (rendererActive && renderer != nil)
	{
        NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate];

        if (skipUpdateCount == 0)
        {
            if (startTime == 0)
                startTime = time;
            // Make sure we draw to the right context
            [context makeCurrentContext];
            [context lock]; //CGLLockContext(cgl_ctx);
            glClearColor([eraseColor redComponent], [eraseColor greenComponent], [eraseColor blueComponent], [eraseColor alphaComponent]);
            glClear(GL_COLOR_BUFFER_BIT);
            
            if (rendererVisible)
                [renderer renderAtTime:(time - startTime) arguments:nil];
            
            [context flushBuffer];
            [context unlock]; //CGLUnlockContext(cgl_ctx);
        }
        else
            skipUpdateCount--;
        
		NSTimeInterval timeSpent = [NSDate timeIntervalSinceReferenceDate] - time;
		[NSThread sleepForTimeInterval:(1.0f/60.0f) - timeSpent];
	}
	
    //NSLog(@"Rendering thread exit");
	[NSThread exit];
}

@end




@implementation SPStatusDisplayView


// ----------------------------------------------------------------------------
- (instancetype)initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{
		displayVisible = NO;
		resourcesLoaded = NO;
		showRemainingTime = NO;
		inStartState = YES;
		
		leftBackGroundImage = nil;
		middleBackGroundImage = nil;
		rightBackGroundImage = nil;
		timeDividerImage = nil;
		minusImage = nil;
		sidplayLogoImage = nil;

		leftArrowImage = nil;
		rightArrowImage = nil;
		mouseDownInLeftArrow = NO;
		mouseDownInRightArrow = NO;
		mouseDownInSubtuneInfo = NO;
		
		currentPlaybackSeconds = -1;
		currentSonglengthInSeconds = -1;
		
		currentTimeDigits[0] = 0;
		currentTimeDigits[1] = 0;
		currentTimeDigits[2] = 0;
		currentTimeDigits[3] = 0;
			
		logoView = nil;
		logoVisible = YES;
		
		tuneInfo = nil;
	}
    return self;
}


// ----------------------------------------------------------------------------
- (void) setPlaybackSeconds:(NSInteger)seconds
// ----------------------------------------------------------------------------
{
	if (seconds == currentPlaybackSeconds)
		return;

	if (seconds >= 0)
		currentPlaybackSeconds = seconds;
	
	int remainingTime = (int)MAX(0, currentSonglengthInSeconds - currentPlaybackSeconds);
	
	int timeToShowInSeconds = (int)(showRemainingTime ? remainingTime: currentPlaybackSeconds);
	
	if (timeToShowInSeconds < 60)
	{
		currentTimeDigits[0] = 0;
		currentTimeDigits[1] = 0;
		currentTimeDigits[2] = timeToShowInSeconds / 10;
		currentTimeDigits[3] = timeToShowInSeconds - currentTimeDigits[2] * 10;
	} 
	else
	{
		int minutes = timeToShowInSeconds / 60;
		currentTimeDigits[0] = ( minutes / 10 ) % 10;
		currentTimeDigits[1] = minutes - currentTimeDigits[0] * 10;
		int tmp = timeToShowInSeconds - minutes * 60;
		currentTimeDigits[2] = tmp / 10;
		currentTimeDigits[3] = tmp - currentTimeDigits[2] * 10;
	}

	if (inStartState)
	{
		[self setLogoVisible:NO];
		displayVisible = YES;
		inStartState = NO;
	}
	[self setNeedsDisplay:YES];
}


// ----------------------------------------------------------------------------
- (void) setTitle:(NSString*)title andAuthor:(NSString*)author andReleaseInfo:(NSString*)releaseInfo andSubtune:(NSInteger)subtune ofSubtunes:(NSInteger)subtuneCount withSonglength:(int)timeInSeconds
// ----------------------------------------------------------------------------
{
	NSColor* color = [NSColor colorWithDeviceRed:0.298f green:0.298f blue:0.298f alpha:1.0f];
	NSDictionary* boldAttrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:11.0f], 
																		 NSForegroundColorAttributeName: color};
	NSDictionary* normalAttrs = @{NSFontAttributeName: [NSFont systemFontOfSize:10.0f],
																		 NSForegroundColorAttributeName: color};
	
	tuneInfo = [[NSMutableAttributedString alloc] initWithString:title attributes:boldAttrs];
	NSAttributedString* additionalTuneInfo = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n%@\n%@", author, releaseInfo] attributes:normalAttrs];
	[tuneInfo appendAttributedString:additionalTuneInfo];
	
	NSMutableParagraphStyle* style = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
	style.alignment = NSRightTextAlignment;
	
	NSDictionary* subtuneAttrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:11.0f], 
																			NSParagraphStyleAttributeName: style,
																			NSForegroundColorAttributeName: color};
	subtuneInfo = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"Song %02ld of %02ld", (long)subtune, (long)subtuneCount] attributes:subtuneAttrs];
	currentSubtuneDigits[0] = subtune / 10;
	currentSubtuneDigits[1] = subtune % 10;
	subtuneCountDigits[0] = subtuneCount / 10;
	subtuneCountDigits[1] = subtuneCount % 10;

	currentSonglengthInSeconds = timeInSeconds;
	[self setPlaybackSeconds:-1];

	if (inStartState)
	{
		[self setLogoVisible:NO];
		displayVisible = YES;
		inStartState = NO;
	}
	
	[self setNeedsDisplay:YES];
}


// ----------------------------------------------------------------------------
- (void) loadResources
// ----------------------------------------------------------------------------
{
	inStartState = YES;
	
	leftBackGroundImage = [NSImage imageNamed:@"display_left"];
	middleBackGroundImage = [NSImage imageNamed:@"display_middle"];
	rightBackGroundImage = [NSImage imageNamed:@"display_right"];

	for (int i = 0; i < 10; i++)
	{
		smallNumberImages[i] = [NSImage imageNamed:[NSString stringWithFormat:@"numbersmall%d", i]];
		largeNumberImages[i] = [NSImage imageNamed:[NSString stringWithFormat:@"numberlarge%d", i]];
	}
	
	minusImage = [NSImage imageNamed:@"minus"];
	timeDividerImage = [NSImage imageNamed:@"timedivider"];
	
	leftArrowImage = [NSImage imageNamed:@"NSGoLeftTemplate"];
	rightArrowImage = [NSImage imageNamed:@"NSGoRightTemplate"];
	
	//sidplayLogoImage = [NSImage imageNamed:@"sidplay_logo"]; 
	
	//NSLog(@"%@: loading resources for window: %@\n", self, [self window]);
	
	if ([self.window isKindOfClass:[SPPlayerWindow class]] || [self.window isKindOfClass:[SPMiniPlayerWindow class]])
	{
		NSString* logoCompositionPath = [NSString stringWithFormat:@"%@%@",[NSBundle mainBundle].resourcePath,@"/logo.qtz"];

		logoView = [[SPQCView alloc] initWithFrame:self.frame];
		logoView.bounds = self.bounds;
		[logoView setEraseColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]];

        [logoView loadCompositionFromFile:logoCompositionPath];
        
        [self addSubview:logoView positioned:NSWindowAbove relativeTo:self];
        [logoView startRendering];
        
        [self setLogoVisible:YES];
    }
		
	resourcesLoaded = YES;
}


// ----------------------------------------------------------------------------
- (void) prepareForQuit
// ----------------------------------------------------------------------------
{
    [logoView prepareForQuit];
    logoView = nil;
}


// ----------------------------------------------------------------------------
- (void) startLogoRendering
// ----------------------------------------------------------------------------
{
}


// ----------------------------------------------------------------------------
- (NSOpenGLView*) logoView;
// ----------------------------------------------------------------------------
{
	return logoView;
}


// ----------------------------------------------------------------------------
- (BOOL) displayVisible
// ----------------------------------------------------------------------------
{
	return displayVisible;
}


// ----------------------------------------------------------------------------
- (void) setDisplayVisible:(BOOL)visible
// ----------------------------------------------------------------------------
{
	displayVisible = visible;
}


// ----------------------------------------------------------------------------
- (BOOL) logoVisible
// ----------------------------------------------------------------------------
{
	return logoVisible;
}


// ----------------------------------------------------------------------------
- (void) setLogoVisible:(BOOL)visible
// ----------------------------------------------------------------------------
{
    [logoView setRendererVisible:visible];
    
//	if (!logoVisible && visible)
//	{
//        [self addSubview:logoView positioned:NSWindowAbove relativeTo:self];
//		[logoView startRendering];
//	}
//	else if (logoVisible && !visible)
//	{
//		[logoView removeFromSuperview];
//        [logoView stopRendering];
//	}
	
	logoVisible = visible;
    [self setNeedsDisplay:YES];
}


// ----------------------------------------------------------------------------
- (void)drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	if (!resourcesLoaded)
		[self loadResources];

	rect = self.bounds;

	// Draw background
	NSDrawThreePartImage(rect, leftBackGroundImage, middleBackGroundImage, rightBackGroundImage, NO, NSCompositeSourceOver, 0.8f, NO);
	
	if (logoVisible)
		logoView.frame = self.bounds;

	if (!displayVisible)
		return;
		
	// Draw time information
	float xpos = rect.origin.x + rect.size.width - 70.0f;
	float ypos = floorf(rect.origin.y + 6.0f);
	timeDisplayFrame = NSMakeRect(xpos, ypos, 4.0f * 13.0f + 11.0f, 19.0f);

	if (showRemainingTime)
	{
		NSRect minusImageFrame = NSMakeRect(xpos - 13.0f, ypos, minusImage.size.width, minusImage.size.height);
		NSRect minusImageRect = NSMakeRect(0.0f, 0.0f, minusImage.size.width, minusImage.size.height);
		[minusImage setFlipped:self.flipped];
		[minusImage drawInRect:minusImageFrame fromRect:minusImageRect operation:NSCompositeSourceOver fraction:1.0f];
	}
	
	for (int i = 0; i < 4; i++)
	{
		NSImage* image = largeNumberImages[currentTimeDigits[i]];
		NSRect imageFrame = NSMakeRect(xpos, ypos, image.size.width, image.size.height);
		NSRect imageRect = NSMakeRect(0.0f, 0.0f, image.size.width, image.size.height);
			
		[image setFlipped:self.flipped];
		[image drawInRect:imageFrame fromRect:imageRect operation:NSCompositeSourceOver fraction:1.0f];
		
		xpos += image.size.width + 3.0f;
		
		if (i == 1)
		{
			imageFrame = NSMakeRect(xpos, ypos, timeDividerImage.size.width, timeDividerImage.size.height);
			imageRect = NSMakeRect(0.0f, 0.0f, timeDividerImage.size.width, timeDividerImage.size.height);
				
			[timeDividerImage setFlipped:self.flipped];
			[timeDividerImage drawInRect:imageFrame fromRect:imageRect operation:NSCompositeSourceOver fraction:1.0f];

			xpos += image.size.width + 1.0f;
		}
	}
	
	const float rightDisplayWidth = 100.0f;
	
	// Draw the title/author/release info
	NSRect tuneInfoFrame;
	if (tuneInfo != nil)
	{
		tuneInfoFrame = NSInsetRect(rect, 8.0f, 3.0f);
		tuneInfoFrame.size.width = rect.size.width - rightDisplayWidth;
		
		[tuneInfo drawInRect:tuneInfoFrame];
	}
	
	// Draw the subtune information
	if (subtuneInfo != nil)
	{
		float leftWidth = leftArrowImage.size.width;
		float leftHeight = leftArrowImage.size.height;
		float rightWidth = rightArrowImage.size.width;
		float rightHeight = rightArrowImage.size.height;

		subtuneInfoFrame = NSInsetRect(rect, 8.0f, 3.0f);
		subtuneInfoFrame.size.width = rightDisplayWidth;
		subtuneInfoFrame.origin.x = rect.size.width - rightDisplayWidth - 7.0f;
		subtuneInfoFrame.origin.y -= 1.0f;
		[subtuneInfo drawInRect:subtuneInfoFrame];
		
		NSRect subtuneBounds = [subtuneInfo boundingRectWithSize:subtuneInfoFrame.size options:0];
		
		xpos = rect.size.width - ceilf(NSWidth(subtuneBounds)) - 10.0f - leftWidth - rightWidth;
		ypos = floorf(rect.origin.y + 29.0f);

		leftArrowFrame = NSMakeRect(xpos, ypos, leftWidth, leftHeight);
		NSRect imageRect = NSMakeRect(0.0f, 0.0f, leftWidth, leftHeight);
			
		[leftArrowImage setFlipped:self.flipped];
		[leftArrowImage drawInRect:leftArrowFrame fromRect:imageRect operation:NSCompositeSourceOver fraction:mouseDownInLeftArrow ? 1.0f : 0.64f];

		xpos += leftWidth + 1.0f;

		rightArrowFrame = NSMakeRect(xpos, ypos, rightWidth, rightHeight);
		imageRect = NSMakeRect(0.0f, 0.0f, rightWidth, rightHeight);
			
		[rightArrowImage setFlipped:self.flipped];
		[rightArrowImage drawInRect:rightArrowFrame fromRect:imageRect operation:NSCompositeSourceOver fraction:mouseDownInRightArrow ? 1.0f : 0.64f];
	}
}


/*
// ----------------------------------------------------------------------------
- (NSMenu*)menuForEvent:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	NSPoint mousePosition = [event locationInWindow];
	NSPoint mousePositionInView = [self convertPoint:mousePosition fromView:nil];

	if (displayVisible && NSPointInRect(mousePositionInView, subtuneInfoFrame))
	{
		mouseDownInSubtuneInfo = YES;
		NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
		for (int i = 0; i < 10; i++)
			[menu addItemWithTitle:[NSString stringWithFormat:@"Subtune %d", i] action:@selector(subtuneSelectedFromMenu:) keyEquivalent:@""];
		return menu;
	}

	return [[self class] defaultMenu];
}
*/


/*
// ----------------------------------------------------------------------------
- (void) updateUvMetersWithVoice1:(float)levelVoice1 andVoice2:(float)levelVoice2 andVoice3:(float)levelVoice3
// ----------------------------------------------------------------------------
{
	if (!logoVisible || !resourcesLoaded)
		return;
		
	if ([logoView superview] == nil)
		return;
		
	[logoView setValue:[NSNumber numberWithFloat:levelVoice1] forInputKey:@"protocol_Voice1_Gate"];
	[logoView setValue:[NSNumber numberWithFloat:levelVoice2] forInputKey:@"protocol_Voice2_Gate"];
	[logoView setValue:[NSNumber numberWithFloat:levelVoice3] forInputKey:@"protocol_Voice3_Gate"];
}
*/


// ----------------------------------------------------------------------------
- (void) mouseDown:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	NSPoint mousePosition = event.locationInWindow;
	NSPoint mousePositionInView = [self convertPoint:mousePosition fromView:nil];
	
	if (displayVisible && NSPointInRect(mousePositionInView, leftArrowFrame))
	{
		mouseDownInLeftArrow = YES;
		[self setNeedsDisplay:YES];
		return;
	}
	else if (displayVisible && NSPointInRect(mousePositionInView, rightArrowFrame))
	{
		mouseDownInRightArrow = YES;
		[self setNeedsDisplay:YES];
		return;
	}
	else if (displayVisible && NSPointInRect(mousePositionInView, timeDisplayFrame))
	{
		showRemainingTime = !showRemainingTime;
		[self setPlaybackSeconds:-1];
		return;
	}
	else
	{
		if (!inStartState)
		{
			if (logoVisible && !displayVisible)
			{
				[self setLogoVisible:NO];
				displayVisible = YES;
			}
			else if (!logoVisible && displayVisible)
			{
				[self setLogoVisible:YES];
				displayVisible = NO;
			}
		}
		
		mouseDownInLeftArrow = NO;
		mouseDownInRightArrow = NO;
		return;
	}
	// Code will never be executed
	//[super mouseDown:event];
}


// ----------------------------------------------------------------------------
- (void) mouseUp:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	NSPoint mousePosition = event.locationInWindow;
	NSPoint mousePositionInView = [self convertPoint:mousePosition fromView:nil];
	
	if (displayVisible && NSPointInRect(mousePositionInView, leftArrowFrame) && mouseDownInLeftArrow)
	{
		mouseDownInLeftArrow = NO;
		[self setNeedsDisplay:YES];
		[(SPPlayerWindow*)self.window previousSubtune:self];
	}
	else if (displayVisible && NSPointInRect(mousePositionInView, rightArrowFrame) && mouseDownInRightArrow)
	{
		mouseDownInRightArrow = NO;
		[self setNeedsDisplay:YES];
		[(SPPlayerWindow*)self.window nextSubtune:self];
	}
	else
	{
		mouseDownInLeftArrow = NO;
		mouseDownInRightArrow = NO;
		[self setNeedsDisplay:YES];
	}
}

/*
// ----------------------------------------------------------------------------
- (void) viewWillMoveToSuperview:(NSView*)newSuperview
// ----------------------------------------------------------------------------
{
	//NSLog(@"%@: viewWillMoveToSuperview: %@\n", self, newSuperview);

	if (newSuperview == nil)
	{
		[logoView stopRendering];
		[logoView removeFromSuperview];
		logoVisible = NO;
	}

	[super viewWillMoveToSuperview:newSuperview];
}
*/

/*
// ----------------------------------------------------------------------------
- (void) viewWillMoveToWindow:(NSWindow*)newWindow
// ----------------------------------------------------------------------------
{
	//NSLog(@"%@: viewWillMoveToWindow: %@\n", self, newWindow);

	if (newWindow == nil || ![newWindow isKindOfClass:[SPPlayerWindow class]] || ![newWindow isVisible])
	{
		[logoView stopRendering];
		[logoView removeFromSuperview];
		logoVisible = NO;
	}
	else if (newWindow != nil && [newWindow isKindOfClass:[SPPlayerWindow class]])
	{
		SPPlayerWindow* window = (SPPlayerWindow*) newWindow;
		[window setStatusDisplay:self];
		
		// this is not a good idea
		[self addSubview:logoView positioned:NSWindowAbove relativeTo:self];
		[logoView startRendering];
		logoVisible = YES;
	}

	[super viewWillMoveToWindow:newWindow];
}
*/


@end
