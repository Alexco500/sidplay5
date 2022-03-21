
#import "SPAnalyzerWindowController.h"
#import "SPColorProvider.h"
#import "SPAnalyzerWaveformView.h"


@implementation SPAnalyzerWaveformView


// ----------------------------------------------------------------------------
- (id) initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{
        // Initialization code here.
    }
    return self;
}


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	lineColors[0] = [NSColor colorWithCalibratedWhite:0.203f alpha:1.0f];
	lineColors[1] = [NSColor colorWithCalibratedWhite:0.219f alpha:1.0f];
	verticalLineColor = [NSColor colorWithCalibratedWhite:0.266f alpha:1.0f];
	seperatorColor = [NSColor colorWithCalibratedWhite:0.14f alpha:1.0f];

	for (int voice = 0; voice < SID_VOICE_COUNT; voice++)
		voiceColors[voice] = [[SPColorProvider sharedInstance] analyzerVoiceColor:voice shade:0];
	
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

	const float rowHeight = 10.0f;
	const int rows = 7;

	for (int i = 0; i < rows; i++)
	{
		float ypos = rowHeight * i + 1.0f;

		if (ypos >= (rect.origin.y - rowHeight) && ypos < (rect.origin.y + NSHeight(rect) + rowHeight))
		{
			[lineColors[i % 2] set];
			
			NSRect rowRect = NSMakeRect(rect.origin.x, ypos, NSWidth(rect), rowHeight);
			NSRectFill(rowRect);
		}
	}
	
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
		const unsigned char bitMasksForRows[rows] = { 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80 };
		
		SidWaveformStream* waveformStream[SID_VOICE_COUNT];
		
		unsigned int startTime = MAX(drawStart / cycleToPixelRatio, 0);
		unsigned int endTime = drawEnd / cycleToPixelRatio;
		
		//NSLog(@"draw: %d -> %d, index: %d -> %d\n", startTime, endTime, startIndex, endIndex);
		
		for (int i = 0; i < SID_VOICE_COUNT; i++)
		{
			if (![[SPAnalyzerWindowController sharedInstance] voiceEnabled:i])
				continue;
			
			waveformStream[i] = [[SPAnalyzerWindowController sharedInstance] waveformStream:i];
			
			int size = waveformStream[i]->size();
			int searchIndex = 0;
			while (searchIndex < size && (*waveformStream[i])[searchIndex].mTimeStamp < startTime)
				searchIndex++;
			
			int startIndex = MAX(searchIndex - 1, 0);
			
			while (searchIndex < size && (*waveformStream[i])[searchIndex].mTimeStamp < endTime)
				searchIndex++;
			
			int endIndex = MIN(searchIndex + 1, size - 1);

			if (size == 1)
			{
				startIndex = 0;
				endIndex = 1;
			}
			
			float currentXPos[SID_VOICE_COUNT] = { 0.0f, 0.0f, 0.0f };
			
			for (int index = startIndex; index < endIndex; index++)
			{
				SidWaveformState frame = (*waveformStream[i])[index];
				SidWaveformState frame2 = (*waveformStream[i])[(index + 1) < size ? index + 1 : index];
				if ((index + 1) >= size)
					frame2.mTimeStamp = totalTime;
				
				unsigned char waveform = frame.mValue;
				
				float xpos = floorf(double(frame.mTimeStamp) * cycleToPixelRatio);
				float width = floorf(double(frame2.mTimeStamp) * cycleToPixelRatio - xpos);
				float lineHeight = 2.0f;
				for (int row = 0; row < rows; row++)
				{
					if (waveform & bitMasksForRows[row])
					{
						float ypos = rowHeight * row + (lineHeight + 1.0f) * (2 - i) + 2.0f;
						
						if (/*xpos >= currentXPos[i] &&*/ ypos >= (rect.origin.y - rowHeight) && ypos < (rect.origin.y + NSHeight(rect) + rowHeight))
						{
							[voiceColors[i] set];
							NSRectFill(NSMakeRect(xpos, ypos, MAX(width, 1.0f), lineHeight));
							
							currentXPos[i] = xpos + width;
						}
					}
				}
			}
		}
	}
}

@end
