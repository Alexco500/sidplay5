
#import "SPAnalyzerWindowController.h"
#import "SPColorProvider.h"
#import "SPAnalyzerPulseWidthView.h"


@implementation SPAnalyzerPulseWidthView


// ----------------------------------------------------------------------------
- (instancetype)initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{
		voiceParamKnobImage[0] = nil;
		voiceParamKnobImage[1] = nil;
		voiceParamKnobImage[2] = nil;
    }
    return self;
}


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	voiceParamKnobImage[0] = [NSImage imageNamed:@"point1"];		
	voiceParamKnobImage[1] = [NSImage imageNamed:@"point2"];		
	voiceParamKnobImage[2] = [NSImage imageNamed:@"point3"];		
	
	[super awakeFromNib];
}


// ----------------------------------------------------------------------------
- (BOOL) isOpaque
// ----------------------------------------------------------------------------
{
	return YES;
}


// ----------------------------------------------------------------------------
- (void)drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
	if (![SPAnalyzerWindowController isInitialized])
		return;

	// Draws from cache if possible, otherwise calls drawContent:
	[super drawRect:rect];

	[[SPAnalyzerWindowController sharedInstance] drawCursorInRect:rect];
}
	

// ----------------------------------------------------------------------------
- (void)drawContent:(NSRect)rect
// ----------------------------------------------------------------------------
{
	if (![SPAnalyzerWindowController isInitialized])
		return;
	
	NSRect bounds = self.bounds;
	
	[NSBezierPath setDefaultLineWidth:1.0f];
	NSBezierPath* path = [NSBezierPath bezierPath];
	
	NSColor* backgroundColor = [NSColor colorWithCalibratedWhite:0.220f alpha:1.0f];
	NSColor* backgroundLineColor = [NSColor colorWithCalibratedWhite:0.259f alpha:1.0f];
	//NSColor* lineColor = [NSColor colorWithCalibratedRed:0.675f green:0.498f blue:0.796f alpha:1.0f];
	
	[backgroundColor set];
	NSRectFill(rect);
	
	[backgroundLineColor set];
	
	double cycleToPixelRatio = 1.0f;
	double totalTime = self.frame.size.width;
	
	cycleToPixelRatio = [[SPAnalyzerWindowController sharedInstance] cycleToPixelRatio];
	totalTime = [[SPAnalyzerWindowController sharedInstance] totalCaptureTime];
	
	const double lineHeight = rect.size.height;
	double desiredStep = 100.0f;
	double pixelStep = desiredStep * cycleToPixelRatio;
	
	if (pixelStep < desiredStep)
		pixelStep *= floorf(desiredStep / pixelStep);
	
	double timeStep = pixelStep / cycleToPixelRatio;
	
	double drawStart = rect.origin.x - pixelStep;
	double drawEnd = rect.origin.x + NSWidth(rect) + pixelStep;
	
	for (double t = 0.0; t < totalTime; t += timeStep)
	{
		double x = t * cycleToPixelRatio;
		
		if (x >= drawStart && x <= drawEnd)
		{
			double xpos = floorf(bounds.origin.x + x) + 0.5;
			
			[path moveToPoint:NSMakePoint(xpos, rect.origin.y)];
			[path lineToPoint:NSMakePoint(xpos, rect.origin.y + lineHeight)];
			
			[path stroke];
		}
	}
	
	if (![[SPAnalyzerWindowController sharedInstance] analyzeResultAvailable])
		return;

	SidPulseWidthStream* pulseWidthStream[SID_VOICE_COUNT];
	
	pulseWidthStream[0] = [[SPAnalyzerWindowController sharedInstance] pulseWidthStream:0];
	pulseWidthStream[1] = [[SPAnalyzerWindowController sharedInstance] pulseWidthStream:1];
	pulseWidthStream[2] = [[SPAnalyzerWindowController sharedInstance] pulseWidthStream:2];
	
	unsigned int startTime = MAX(drawStart / cycleToPixelRatio, 0);
	unsigned int endTime = drawEnd / cycleToPixelRatio;
	
	//NSLog(@"draw: %d -> %d, index: %d -> %d\n", startTime, endTime, startIndex, endIndex);
	
	NSBezierPath* voicePath[SID_VOICE_COUNT];
	
	voicePath[0] = [NSBezierPath bezierPath];
	voicePath[1] = [NSBezierPath bezierPath];
	voicePath[2] = [NSBezierPath bezierPath];

	float width = 9.0f;
	float height = 9.0f;
	NSRect imageRect = NSMakeRect(0.0f, 0.0f, width, height);
	[voiceParamKnobImage[0] setFlipped:self.flipped];
	[voiceParamKnobImage[1] setFlipped:self.flipped];
	[voiceParamKnobImage[2] setFlipped:self.flipped];

	NSPoint knobPositions[SID_VOICE_COUNT][2000];
	int knobPositionCount[SID_VOICE_COUNT] = { 0, 0, 0 };

	BOOL drawKnobs = NO;
	
	for (int i = 0; i < SID_VOICE_COUNT; i++)
	{
		if (![[SPAnalyzerWindowController sharedInstance] voiceEnabled:i])
			continue;
		
		int size = (int)pulseWidthStream[i]->size();
		int searchIndex = 0;
		while (searchIndex < size && (*pulseWidthStream[i])[searchIndex].mTimeStamp < startTime)
			searchIndex++;
		
		int startIndex = MAX(searchIndex - 1, 0);
		
		while (searchIndex < size && (*pulseWidthStream[i])[searchIndex].mTimeStamp < endTime)
			searchIndex++;
		
		int endIndex = MIN(searchIndex + 1, size);

		if (size == 1)
		{
			startIndex = 0;
			endIndex = 1;
		}
		
		NSPoint currentPos = NSMakePoint(0.0f, 0.0f);
		float yOffset = 6.0f;
		float drawHeight = NSHeight(bounds) - yOffset * 2.0f;
		
		for (int index = startIndex; index < endIndex; index++)
		{
			SidPulseWidthState frame = (*pulseWidthStream[i])[index];
			SidPulseWidthState frame2 = (*pulseWidthStream[i])[(index + 1) < size ? index + 1 : index];
			if ((index + 1) >= size)
				frame2.mTimeStamp = totalTime;

			unsigned short pulseWidth = frame.mValue;
			unsigned short pulseWidth2 = frame2.mValue;
			
			NSPoint point1 = NSMakePoint(floorf(double(frame.mTimeStamp) * cycleToPixelRatio) + 0.5f, floorf(drawHeight * float(pulseWidth) / 4095.0f) + yOffset + 0.5f);
			NSPoint point2 = NSMakePoint(floorf(double(frame2.mTimeStamp) * cycleToPixelRatio) + 0.5f, point1.y);
			NSPoint point3 = NSMakePoint(point2.x, floorf(drawHeight * float(pulseWidth2) / 4095.0f) + yOffset + 0.5f);
			
			//NSLog(@"index: %d, ypos: %f, pulsewidth: %d\n", index, point1.y, pulseWidth);
			
			if (point3.x > currentPos.x)
			{
				currentPos = point3;

				[voicePath[i] moveToPoint:point1];
				[voicePath[i] lineToPoint:point2];
				[voicePath[i] lineToPoint:point3];
				
				if (drawKnobs && knobPositionCount[i] < 2000)
				{
					knobPositions[i][knobPositionCount[i]] = point1;
					knobPositionCount[i]++;
				}
			}
			else
			{
				[voicePath[i] lineToPoint:point3];
			}
			
			/*
			if (point1.x > currentPos.x)
			{
				//NSLog(@"index: %d, point1: %@, point2: %@, point3: %@\n", index, NSStringFromPoint(point1), NSStringFromPoint(point2), NSStringFromPoint(point3));

				currentPos = point1;
				
				[voicePath[i] moveToPoint:point1];
				[voicePath[i] lineToPoint:point2];
				[voicePath[i] lineToPoint:point3];

				if (drawKnobs && knobPositionCount[i] < 2000)
				{
					knobPositions[i][knobPositionCount[i]] = point1;
					knobPositionCount[i]++;
				}
			}
			else
			{
				currentPos = point1;
				[voicePath[i] lineToPoint:point3];
			}
			*/
		}

		[[[SPColorProvider sharedInstance] analyzerVoiceColor:i shade: 0] set];
		[voicePath[i] stroke];

		if (drawKnobs)
		{
			for (int j = 0; j < knobPositionCount[i]; j++)
			{
				NSRect imageFrame = NSMakeRect(knobPositions[i][j].x - 4.0f, knobPositions[i][j].y - 4.0f, width, height);
				[voiceParamKnobImage[i] drawInRect:imageFrame fromRect:imageRect operation:NSCompositeSourceOver fraction:1.0f];
			}
		}
	}
}


@end
