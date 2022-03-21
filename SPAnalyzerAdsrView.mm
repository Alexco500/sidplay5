
#import "SPAnalyzerWindowController.h"
#import "SPColorProvider.h"
#import "SPAnalyzerAdsrView.h"


@implementation SPAnalyzerAdsrView


// ----------------------------------------------------------------------------
- (id) initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{
        
    }
    return self;
}


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	backgroundColor = [NSColor colorWithCalibratedWhite:0.220f alpha:1.0f];
	verticalLineColor = [NSColor colorWithCalibratedWhite:0.266f alpha:1.0f];
	seperatorColor = [NSColor colorWithCalibratedWhite:0.14f alpha:1.0f];
	
	for (int voice = 0; voice < SID_VOICE_COUNT; voice++)
		voiceColors[voice] = [[SPColorProvider sharedInstance] analyzerVoiceColor:voice shade:0];

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
	NSRect bounds = [self bounds];
	NSBezierPath* path = [NSBezierPath bezierPath];
	
	const float rowHeight = 22.0f;
	
	[backgroundColor set];
	NSRectFill(rect);
	
	[verticalLineColor set];
	path = [NSBezierPath bezierPath];
	
	double cycleToPixelRatio = [[SPAnalyzerWindowController sharedInstance] cycleToPixelRatio];
	double totalTime = [[SPAnalyzerWindowController sharedInstance] totalCaptureTime];
	
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
			float xpos = floorf(bounds.origin.x + x) + 0.5f;
			
			[path moveToPoint:NSMakePoint(xpos, rect.origin.y)];
			[path lineToPoint:NSMakePoint(xpos, rect.origin.y + lineHeight)];
			
			[path stroke];
		}
	}
	
	[seperatorColor set];
	path = [NSBezierPath bezierPath];
	
	[path moveToPoint:NSMakePoint(bounds.origin.x, bounds.origin.y + 0.5f)];
	[path lineToPoint:NSMakePoint(bounds.origin.x + NSWidth(bounds), bounds.origin.y + 0.5f)];
	
	[path moveToPoint:NSMakePoint(bounds.origin.x, bounds.origin.y + NSHeight(bounds) - 0.5f)];
	[path lineToPoint:NSMakePoint(bounds.origin.x + NSWidth(bounds), bounds.origin.y + NSHeight(bounds) - 0.5f)];
	
	[path stroke];
	
	if ([[SPAnalyzerWindowController sharedInstance] analyzeResultAvailable])
	{
		SidAdsrStream* adsrStream[SID_VOICE_COUNT];
	
		NSBezierPath* voicePath[SID_VOICE_COUNT];
		NSBezierPath* envelopePath[SID_VOICE_COUNT];
		
		for (int i = 0; i < SID_VOICE_COUNT; i++)
		{
			voicePath[i] = [NSBezierPath bezierPath];
			envelopePath[i] = [NSBezierPath bezierPath];
		}
		
		unsigned int startTime = MAX(drawStart / cycleToPixelRatio, 0);
		unsigned int endTime = drawEnd / cycleToPixelRatio;
		
		//NSLog(@"draw: %d -> %d, index: %d -> %d\n", startTime, endTime, startIndex, endIndex);
		
		float width = 9.0f;
		float height = 9.0f;
		NSRect imageRect = NSMakeRect(0.0f, 0.0f, width, height);

		NSPoint knobPositions[SID_VOICE_COUNT][2000];
		int knobPositionCount[SID_VOICE_COUNT] = { 0, 0, 0 };
		BOOL drawKnobs = YES;
		
		NSRect visibleRect = [[self enclosingScrollView] documentVisibleRect];
		
		for (int i = 0; i < SID_VOICE_COUNT; i++)
		{
			if (![[SPAnalyzerWindowController sharedInstance] voiceEnabled:i])
				continue;
			
			[voiceParamKnobImage[i] setFlipped:[self isFlipped]];

			adsrStream[i] = [[SPAnalyzerWindowController sharedInstance] adsrStream:i];
			
			long size = adsrStream[i]->size();
			int searchIndex = 0;
			while (searchIndex < size && (*adsrStream[i])[searchIndex].mTimeStamp < startTime)
				searchIndex++;
			
			int startIndex = MAX(searchIndex - 1, 0);
			
			while (searchIndex < size && (*adsrStream[i])[searchIndex].mTimeStamp < endTime)
				searchIndex++;
			
			long endIndex = MIN(searchIndex + 1, size);
			
			if (size == 1)
			{
				startIndex = 0;
				endIndex = 1;
			}
			
			NSPoint currentPos = NSMakePoint(0.0f, 0.0f);
			
			for (long index = startIndex; index < endIndex; index++)
			{
				SidAdsrState frame = (*adsrStream[i])[index];
				SidAdsrState frame2 = (*adsrStream[i])[(index + 1) < size ? index + 1 : index];
				if ((index + 1) >= size)
					frame2.mTimeStamp = totalTime;

				float attack = float((frame.mValue >> 12) & 0x0f) / 15.0f;
				float decay = float((frame.mValue >> 8) & 0x0f) / 15.0f;
				float sustain = float((frame.mValue >> 4) & 0x0f) / 15.0f;
				float release = float((frame.mValue) & 0x0f) / 15.0f;

				//NSLog(@"v: %d, index: %d, frame1: %d, frame2: %d, value: 0x%04x, attack: %f (size: %d, total: %d)\n", i, index, frame.mTimeStamp, frame2.mTimeStamp, frame.mValue, attack, size, totalTime);

				float yOffset = (2 - i) * rowHeight + 4.5f;
					
				NSPoint point1 = NSMakePoint(floorf(double(frame.mTimeStamp) * cycleToPixelRatio) + 0.5f, yOffset);
				NSPoint point2 = NSMakePoint(floorf(double(frame2.mTimeStamp) * cycleToPixelRatio) + 0.5f, yOffset);

				float envWidth = 24.0f;
				float envHeight = rowHeight - 8.0f;
				float componentWidth = (envWidth - 4.0f) / 4.0f;
				float width = point2.x - point1.x;
				NSPoint envDiagramPoint = NSMakePoint(floorf(point1.x + width * 0.5f) + 0.5f, yOffset + 2.0f);

				if (width > 24.0f)
				{
					/*
					float leftEnvelopeEdge = envDiagramPoint.x - envWidth * 0.5f;
					float rightEnvelopeEdge = envDiagramPoint.x + envWidth * 0.5f;
					
					if (leftEnvelopeEdge < visibleRect.origin.x)
						envDiagramPoint.x = visibleRect.origin.x + envWidth * 0.5f + 4.0f;
					
					if (rightEnvelopeEdge > visibleRect.origin.x + NSWidth(visibleRect))
						envDiagramPoint.x = visibleRect.origin.x + NSWidth(visibleRect) - envWidth * 0.5f - 4.0f;
					*/
					 
					[envelopePath[i] moveToPoint:NSMakePoint(envDiagramPoint.x - 2.0f * componentWidth, envDiagramPoint.y)];
					[envelopePath[i] lineToPoint:NSMakePoint(envDiagramPoint.x - 2.0f * componentWidth + attack * componentWidth, envDiagramPoint.y + envHeight)];
					[envelopePath[i] lineToPoint:NSMakePoint(envDiagramPoint.x - 2.0f * componentWidth + attack * componentWidth + decay * componentWidth, envDiagramPoint.y + envHeight * sustain)];
					[envelopePath[i] lineToPoint:NSMakePoint(envDiagramPoint.x + 2.0f * componentWidth - release * componentWidth, envDiagramPoint.y + envHeight * sustain)];
					[envelopePath[i] lineToPoint:NSMakePoint(envDiagramPoint.x + 2.0f * componentWidth, envDiagramPoint.y)];
				}

				[voicePath[i] moveToPoint:point1];
				[voicePath[i] lineToPoint:point2];
				
				if (point1.x > currentPos.x)
				{
					currentPos = point1;
					
					if (drawKnobs && knobPositionCount[i] < 2000)
					{
						knobPositions[i][knobPositionCount[i]] = point1;
						knobPositionCount[i]++;
					}
				}
			}
			
			[voiceColors[i] set];
			[voicePath[i] stroke];
			[envelopePath[i] stroke];

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
}

@end
