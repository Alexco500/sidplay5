
#import "SPAnalyzerWindowController.h"
#import "SPColorProvider.h"
#import "SPAnalyzerFrequencyView.h"


static const int sOctaveCount = 8;
static const int sKeysPerOctave = 12;
static const int sKeyCount = sOctaveCount * sKeysPerOctave;
static const float sKeyHeight = 10.0f;
static const float sOctaveHeight = sKeyHeight * sKeysPerOctave;
static const BOOL sEbonyKeys[sKeysPerOctave] = { NO, YES, NO, YES, NO, NO, YES, NO, YES, NO, YES, NO };

// taken from JCH's player... 
static unsigned short sNoteMap[sKeyCount] = 
{
	0x0116, 0x0127, 0x0138, 0x014b, 0x015f, 0x0173, 0x018a, 0x01a1, 0x01ba, 0x01d4, 0x01f0, 0x020e,
	0x022d, 0x024e, 0x0271, 0x0296, 0x02bd, 0x02e7, 0x0313, 0x0342, 0x0374, 0x03a9, 0x03e0, 0x041b,
	0x045a, 0x049b, 0x04e2, 0x052c, 0x057b, 0x05ce, 0x0627, 0x0685, 0x06e8, 0x0751, 0x07c1, 0x0837,
	0x08b4, 0x0937, 0x09c4, 0x0a57, 0x0af5, 0x0b9c, 0x0c4e, 0x0d09, 0x0dd0, 0x0ea3, 0x0f82, 0x106e,
	0x1168, 0x126e, 0x1388, 0x14af, 0x15eb, 0x1739, 0x189c, 0x1a13, 0x1ba1, 0x1d46, 0x1f04, 0x20dc,
	0x22d0, 0x24dc, 0x2710, 0x295e, 0x2bd6, 0x2e72, 0x3138, 0x3426, 0x3742, 0x3a8c, 0x3e08, 0x41b8,
	0x45a0, 0x49b8, 0x4e20, 0x52bc, 0x57ac, 0x5ce4, 0x6270, 0x684c, 0x6e84, 0x7518, 0x7c10, 0x8370,
	0x8b40, 0x9370, 0x9c40, 0xa578, 0xaf58, 0xb9c8, 0xc4e0, 0xd098, 0xdd08, 0xea30, 0xf820, 0xfd2e,
};


// ----------------------------------------------------------------------------
static inline int sFindNoteIndexForFrequency(unsigned short inFrequency, float& outRelativeError)
// ----------------------------------------------------------------------------
{
	int diffToPrevious;
	int diffToNext;
	outRelativeError = 0.0f;
	
	for (int i = 0; i < sKeyCount; i++)
	{
		diffToPrevious = (i > 0) ? (sNoteMap[i] - sNoteMap[i-1]) : sNoteMap[i];
		diffToNext = (i < (sKeyCount-1)) ? (sNoteMap[i+1] - sNoteMap[i]) : (0xffff - sNoteMap[i]);
		
		if (inFrequency >= (sNoteMap[i] - diffToPrevious/2) && inFrequency < (sNoteMap[i] + diffToNext/2))
		{
			int absoluteError = abs(inFrequency - sNoteMap[i]);
			if (inFrequency < sNoteMap[i])
				outRelativeError = - float(absoluteError) / float(diffToPrevious);
			else if (inFrequency > sNoteMap[i])
				outRelativeError = float(absoluteError) / float(diffToNext);
			
			return i;
		}
	}
	
	return -1;
}



@implementation SPAnalyzerFrequencyView


// ----------------------------------------------------------------------------
- (id)initWithFrame:(NSRect)frame
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
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	ebonyRowColor = [NSColor colorWithCalibratedWhite:0.203f alpha:1.0f];
	ivoryRowColor = [NSColor colorWithCalibratedWhite:0.219f alpha:1.0f];
	lineColor = [NSColor colorWithCalibratedWhite:0.203f alpha:1.0f];
	verticalLineColor = [NSColor colorWithCalibratedWhite:0.266f alpha:1.0f];

	for (int shade = 0; shade < 3; shade++)
	{
		for (int voice = 0; voice < SID_VOICE_COUNT; voice++)
		{
			voiceColors[shade][voice] = [[SPColorProvider sharedInstance] analyzerVoiceColor:voice shade:shade];
		}
	}

	[super awakeFromNib];
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
	
	[NSBezierPath setDefaultLineWidth:1.0f];
	NSBezierPath* path = [NSBezierPath bezierPath];
	
	for (int octave = 0; octave < sOctaveCount; octave++)
	{
		for (int key = 0; key < 12; key++)
		{
			float ypos = octave * sOctaveHeight + key * sKeyHeight;
		
			if (ypos >= (rect.origin.y - sKeyHeight) && ypos < (rect.origin.y + NSHeight(rect) + sKeyHeight))
			{
				if (sEbonyKeys[key])
					[ebonyRowColor set];
				else
					[ivoryRowColor set];
				
				NSRect rowRect = NSMakeRect(rect.origin.x, ypos, NSWidth(rect), sKeyHeight);
				NSRectFill(rowRect);
				
				if (key == 0 || key == 5)
				{
					ypos = ypos + ((key == 0) ? 0.5f : -0.5f);
					[lineColor set];
					
					[path moveToPoint:NSMakePoint(rect.origin.x, ypos)];
					[path lineToPoint:NSMakePoint(rect.origin.x + NSWidth(rect), ypos)];
					
					[path stroke];
				}
			}
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
	 
	if (![[SPAnalyzerWindowController sharedInstance] analyzeResultAvailable])
		return;
		
	SidFrequencyStream* frequencyStream[SID_VOICE_COUNT];
	
	unsigned int startTime = MAX(drawStart / cycleToPixelRatio, 0);
	unsigned int endTime = drawEnd / cycleToPixelRatio;

	//NSLog(@"draw: %d -> %d, index: %d -> %d\n", startTime, endTime, startIndex, endIndex);

	NSBezierPath* deviationPaths[SID_VOICE_COUNT];
	deviationPaths[0] = [NSBezierPath bezierPath];
	deviationPaths[1] = [NSBezierPath bezierPath];
	deviationPaths[2] = [NSBezierPath bezierPath];
	
	for (int i = 0; i < SID_VOICE_COUNT; i++)
	{
		if (![[SPAnalyzerWindowController sharedInstance] voiceEnabled:i])
			continue;
		
		frequencyStream[i] = [[SPAnalyzerWindowController sharedInstance] frequencyStream:i];
		
		int size = (int)frequencyStream[i]->size();
		int searchIndex = 0;
		while (searchIndex < size && (*frequencyStream[i])[searchIndex].mTimeStamp < startTime)
			searchIndex++;
		
		int startIndex = MAX(searchIndex - 1, 0);
		
		while (searchIndex < size && (*frequencyStream[i])[searchIndex].mTimeStamp < endTime)
			searchIndex++;
		
		int endIndex = MIN(searchIndex + 1, size - 1);

		if (size == 1)
		{
			startIndex = 0;
			endIndex = 1;
		}
		
		NSBezierPath* deviationPath = deviationPaths[i];
		
		float currentXPos = 0.0f;
		
		for (int index = startIndex; index < endIndex; index++)
		{
			SidFrequencyState frame = (*frequencyStream[i])[index];
			SidFrequencyState frame2 = (*frequencyStream[i])[(index + 1) < size ? index + 1 : index];
			if ((index + 1) >= size)
				frame2.mTimeStamp = totalTime;

			unsigned short frequency = frame.mValue & 0xffff;
			bool gateBit = frame.mValue >> 31;
			float deviation;
			int noteIndex = sFindNoteIndexForFrequency(frequency, deviation);
			
			float xpos = floorf(double(frame.mTimeStamp) * cycleToPixelRatio);
			float width = floorf(double(frame2.mTimeStamp) * cycleToPixelRatio - xpos);
			float ypos = noteIndex * sKeyHeight + 1.0f;
			float height = sKeyHeight - 1.0f;

			if (xpos >= currentXPos && ypos >= (rect.origin.y - sKeyHeight) && ypos < (rect.origin.y + NSHeight(rect) + sKeyHeight))
			{
				// Draw note bar
				[voiceColors[gateBit ? 0 : 1][i] set];
				NSRectFill(NSMakeRect(xpos, ypos, MAX(width, 1.0f), height));
				
				// Draw frequency deviation line
				float deviationYPos = floorf(ypos + sKeyHeight * 0.5f + deviation * sKeyHeight * 0.9f) + 0.5f;
				[voiceColors[2][i] set];
				[deviationPath moveToPoint:NSMakePoint(xpos, deviationYPos)];
				[deviationPath lineToPoint:NSMakePoint(xpos + MAX(width, 1.0f), deviationYPos)];
				
				currentXPos = xpos + width;
			}
		}

		[deviationPath stroke];
	}
}


@end
