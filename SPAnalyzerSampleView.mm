
#import "SPAnalyzerWindowController.h"
#import "SPAnalyzerSampleView.h"


@implementation SPAnalyzerSampleView


// ----------------------------------------------------------------------------
- (instancetype)initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{

    }
    return self;
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
	NSRect bounds = self.bounds;

	NSColor* upperColor = [NSColor colorWithCalibratedRed:0.478f green:0.564f blue:0.655f alpha:1.0f];
	NSColor* lowerColor = [NSColor colorWithCalibratedRed:0.353f green:0.482f blue:0.557f alpha:1.0f];
	
	NSGradient* gradient = [[NSGradient alloc] initWithStartingColor:upperColor endingColor:lowerColor];
    [gradient drawInRect:bounds angle:-90];
	
	NSColor* lineColor = [NSColor colorWithCalibratedRed:0.227f green:0.275f blue:0.322f alpha:1.0f];
	[lineColor set];
	
	[NSBezierPath setDefaultLineWidth:1.0f];
	NSBezierPath* path = [NSBezierPath bezierPath];

	double cycleToPixelRatio = [[SPAnalyzerWindowController sharedInstance] cycleToPixelRatio];
	
	const float margin = 4.0f;
	const float lineHeight = NSHeight(bounds) - 2.0f * margin;
	
	double drawStart = rect.origin.x - 4.0f;
	double drawEnd = rect.origin.x + NSWidth(rect) + 4.0f;
	
	float zeroLine = floorf(NSHeight(bounds) / 2.0f) + 0.5f;

	[path moveToPoint:NSMakePoint(drawStart, zeroLine)];
	
	short* samples = [[SPAnalyzerWindowController sharedInstance] renderBufferSamples];
	int sampleCount = [[SPAnalyzerWindowController sharedInstance] renderBufferSampleCount];
	int previousSampleOffset = 0;

	int sampleRate = (int)[[SPAnalyzerWindowController sharedInstance]
                           effectiveSampleRate];
	double clockRate = [[SPAnalyzerWindowController sharedInstance] effectiveCpuClockRate];
	
	const double detailThreshold = (double(sampleRate) / clockRate) / 32.0;
	
	//NSLog(@"cycleToPixelRatio: %f, detailThreshold: %f\n", cycleToPixelRatio, detailThreshold);
	
	if (sampleCount > 0)
	{
		if (cycleToPixelRatio < detailThreshold)
		{
			for (double xPos = drawStart; xPos < drawEnd; xPos += 1.0f)
			{
				double timeInCycles = xPos / cycleToPixelRatio;
				double timeInSeconds = timeInCycles / clockRate;
				
				int currentSampleOffset = timeInSeconds > 0.0f ? timeInSeconds * sampleRate : 0;
				
				short minSample = 0;
				short maxSample = 0;
				for (int sampleIndex = previousSampleOffset; sampleIndex < currentSampleOffset && sampleIndex < sampleCount; sampleIndex++)
				{
					minSample = MIN(minSample, samples[sampleIndex]);
					maxSample = MAX(maxSample, samples[sampleIndex]);
				}
				
				float relativeMinSample = float(minSample) / 32768.0f;
				float relativeMaxSample = float(maxSample) / 32768.0f;
				[path moveToPoint:NSMakePoint(xPos, zeroLine + relativeMinSample * lineHeight * 0.5f - 0.5f)]; 
				[path lineToPoint:NSMakePoint(xPos, zeroLine + relativeMaxSample * lineHeight * 0.5f + 0.5f)]; 
				
				previousSampleOffset = currentSampleOffset;
			}
		}
		else
		{
			for (double xPos = drawStart; xPos < drawEnd; xPos += 1.0f)
			{
				double timeInCycles = xPos / cycleToPixelRatio;
				double timeInSeconds = timeInCycles / clockRate;
				
				int currentSampleOffset = timeInSeconds > 0.0f ? timeInSeconds * sampleRate : 0;
				float relativeSample = float(currentSampleOffset < sampleCount ? samples[currentSampleOffset] : 0) / 32768.0f;
				[path lineToPoint:NSMakePoint(xPos, zeroLine + relativeSample * lineHeight * 0.5f)]; 
			}
		}
	}
	else
		[path lineToPoint:NSMakePoint(drawEnd, zeroLine)];
	
	[path stroke];
}

@end
