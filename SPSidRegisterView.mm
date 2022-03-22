#import "SPInfoContainerView.h"
#import "SPColorProvider.h"
#import "SPPlayerWindow.h"
#import "PlayerLibSidplay.h"
#import "SPSidRegisterView.h"
#import "SPPreferencesController.h"


@implementation SPSidRegisterView

// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[super awakeFromNib];

	index = SIDREGISTER_CONTAINER_INDEX;
	height = 133.0f;
	[self setCollapsed:gPreferences.mSidRegistersCollapsed];

	[container addInfoView:self atIndex:index];
}



@end


struct NoteMapEntry
{
	unsigned short mFrequency;
	const char *mNoteString;
};

static const int sNoteCount = 8 * 12;

// taken from JCH's player... 
static NoteMapEntry sNoteMap[sNoteCount] = 
{
	{ 0x0116, "C-1" }, { 0x0127, "C#1" }, { 0x0138, "D-1" }, { 0x014b, "D#1" }, { 0x015f, "E-1" }, { 0x0173, "F-1" }, { 0x018a, "F#1" }, { 0x01a1, "G-1" }, { 0x01ba, "G#1" }, { 0x01d4, "A-1" }, { 0x01f0, "A#1" }, { 0x020e, "B-1" },	
	{ 0x022d, "C-2" }, { 0x024e, "C#2" }, { 0x0271, "D-2" }, { 0x0296, "D#2" }, { 0x02bd, "E-2" }, { 0x02e7, "F-2" }, { 0x0313, "F#2" }, { 0x0342, "G-2" }, { 0x0374, "G#2" }, { 0x03a9, "A-2" }, { 0x03e0, "A#2" }, { 0x041b, "B-2" },
	{ 0x045a, "C-3" }, { 0x049b, "C#3" }, { 0x04e2, "D-3" }, { 0x052c, "D#3" }, { 0x057b, "E-3" }, { 0x05ce, "F-3" }, { 0x0627, "F#3" }, { 0x0685, "G-3" }, { 0x06e8, "G#3" }, { 0x0751, "A-3" }, { 0x07c1, "A#3" }, { 0x0837, "B-3" },
	{ 0x08b4, "C-4" }, { 0x0937, "C#4" }, { 0x09c4, "D-4" }, { 0x0a57, "D#4" }, { 0x0af5, "E-4" }, { 0x0b9c, "F-4" }, { 0x0c4e, "F#4" }, { 0x0d09, "G-4" }, { 0x0dd0, "G#4" }, { 0x0ea3, "A-4" }, { 0x0f82, "A#4" }, { 0x106e, "B-4" },
	{ 0x1168, "C-5" }, { 0x126e, "C#5" }, { 0x1388, "D-5" }, { 0x14af, "D#5" }, { 0x15eb, "E-5" }, { 0x1739, "F-5" }, { 0x189c, "F#5" }, { 0x1a13, "G-5" }, { 0x1ba1, "G#5" }, { 0x1d46, "A-5" }, { 0x1f04, "A#5" }, { 0x20dc, "B-5" },
	{ 0x22d0, "C-6" }, { 0x24dc, "C#6" }, { 0x2710, "D-6" }, { 0x295e, "D#6" }, { 0x2bd6, "E-6" }, { 0x2e72, "F-6" }, { 0x3138, "F#6" }, { 0x3426, "G-6" }, { 0x3742, "G#6" }, { 0x3a8c, "A-6" }, { 0x3e08, "A#6" }, { 0x41b8, "B-6" },
	{ 0x45a0, "C-7" }, { 0x49b8, "C#7" }, { 0x4e20, "D-7" }, { 0x52bc, "D#7" }, { 0x57ac, "E-7" }, { 0x5ce4, "F-7" }, { 0x6270, "F#7" }, { 0x684c, "G-7" }, { 0x6e84, "G#7" }, { 0x7518, "A-7" }, { 0x7c10, "A#7" }, { 0x8370, "B-7" },
	{ 0x8b40, "C-8" }, { 0x9370, "C#8" }, { 0x9c40, "D-8" }, { 0xa578, "D#8" }, { 0xaf58, "E-8" }, { 0xb9c8, "F-8" }, { 0xc4e0, "F#8" }, { 0xd098, "G-8" }, { 0xdd08, "G#8" }, { 0xea30, "A-8" }, { 0xf820, "A#8" }, { 0xfd2e, "B-8" },
};

static const char* sUnknownNote = "";

static const char* sLookUpNoteStringForFrequency(unsigned short frequency)
{
	int lowerstep;
	int higherstep;

	for (int i = 0; i < sNoteCount; i++)
	{
		lowerstep = (i > 0) ? (sNoteMap[i].mFrequency - sNoteMap[i-1].mFrequency) : sNoteMap[i].mFrequency;
		higherstep = (i < (sNoteCount-1)) ? (sNoteMap[i+1].mFrequency - sNoteMap[i].mFrequency) : (0xffff - sNoteMap[i].mFrequency);
		
		if (frequency >= (sNoteMap[i].mFrequency - lowerstep/2) && frequency <  (sNoteMap[i].mFrequency + higherstep/2))
			return sNoteMap[i].mNoteString;
	}
	
	return sUnknownNote;
}


@implementation SPSidRegisterContentView


// ----------------------------------------------------------------------------
- (instancetype)initWithFrame:(NSRect)frame
// ----------------------------------------------------------------------------
{
    self = [super initWithFrame:frame];
    if (self)
	{
		player = NULL;
		registers = NULL;
	}
    return self;
}


// ----------------------------------------------------------------------------
- (void)drawRect:(NSRect)rect
// ----------------------------------------------------------------------------
{
    [super drawRect:rect];
    
	const float rowHeight = 13.0f;
	const float rowCount = 8;
	const float	columnWidth = 120.0f;

	CGContextRef context = (CGContextRef) [NSGraphicsContext currentContext].graphicsPort;
	NSArray* colors = [[SPColorProvider sharedInstance] alternatingRowBackgroundColors];
	NSColor* even = colors[1];
	NSColor* odd = colors[0];

	for (int i = 0; i < rowCount; i++)
	{
		NSRect rowRect = rect;
		rowRect.origin.y = i * rowHeight;
		rowRect.size.height = rowHeight;

		if (i & 1)
			[odd set];
		else
			[even set];
			
		//NSRectFill(rowRect);
	}
	
//	[[[SPColorProvider sharedInstance] gridColor] set];
//	[NSBezierPath strokeLineFromPoint:NSMakePoint(columnWidth - 0.5f, rect.size.height) toPoint:NSMakePoint(columnWidth - 0.5f, rect.size.height - 5.0f * rowHeight)];
//	[NSBezierPath strokeLineFromPoint:NSMakePoint(2.0f * columnWidth - 0.5f, rect.size.height) toPoint:NSMakePoint(2.0f * columnWidth - 0.5f, rect.size.height - 5.0f * rowHeight)];
	
	CGContextSelectFont(context, "Lucida Grande", 9.0f, kCGEncodingMacRoman); 
	if ([[SPColorProvider sharedInstance] providesDarkColors])
	{
		CGContextSetRGBStrokeColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
		CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
	}
	else
	{
		CGContextSetRGBStrokeColor(context, 0.0f, 0.0f, 0.0f, 1.0f);
		CGContextSetRGBFillColor(context, 0.0f, 0.0f, 0.0f, 1.0f);
	}
	
	CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1.0f, 1.0f));
	CGContextSetTextDrawingMode(context, kCGTextFill);

	if (player == NULL)
	{
		SPInfoContainerView* container = self.enclosingScrollView.documentView;
		player = (PlayerLibSidplay*) [[container ownerWindow] player];
	}
	
	SIDPLAY2_NAMESPACE::SidRegisterFrame registerFrame;
	if (player != NULL)
		registerFrame = player->getCurrentSidRegisters();
	
	registers = registerFrame.mRegisters;
	
	for (int i = 0; i < 3; i++)
		[self drawVoice:i intoContext:context atHorizontalPosition:rect.origin.x + columnWidth * i + 3.0f andVerticalPosition:rect.origin.y + rect.size.height - 10.0f];
		
	float xpos = rect.origin.x + 3.0f;
	float ypos = rect.origin.y + rect.size.height - 5.0f * rowHeight - 10.0f;
	char stringBuffer[256];
	
	unsigned short filterCutoff = (registers[0x15] + (registers[0x16] << 8)) >> 5;
	snprintf(stringBuffer, 255, "Filter Cutoff: $%04x", filterCutoff);
	CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));			
	ypos -= rowHeight;

	int filtervoices = registers[0x17] & 0x07;
	const char* filterString = NULL;
	
	switch (filtervoices)
	{
		case 0x00:
			filterString = "(no voices are filtered)";
			break;
		case 0x01:
			filterString = "(voice 1 is filtered)";
			break;
		case 0x02:
			filterString = "(voice 2 is filtered)";
			break;
		case 0x03:
			filterString = "(voices 1+2 are filtered)";
			break;
		case 0x04:
			filterString = "(voice 3 is filtered)";
			break;
		case 0x05:
			filterString = "(voices 1+3 are filtered)";
			break;
		case 0x06:
			filterString = "(voices 2+3 are filtered)";
			break;
		case 0x07:
			filterString = "(all voices are filtered)";
			break;
	}

	snprintf(stringBuffer, 255, "Resonance/Filter: $%02x %s", registers[0x17], filterString);
	CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));			
	ypos -= rowHeight;

	int filterMode = (registers[0x18] & 0x70) >> 4;
	const char* filterModeString = NULL;

	switch (filterMode)
	{
		case 0x00:
			filterModeString = "(no filter used)";
			break;
		case 0x01:
			filterModeString = "(lowpass)";
			break;
		case 0x02:
			filterModeString = "(bandpass)";
			break;
		case 0x03:
			filterModeString = "(lowpass+bandpass)";
			break;
		case 0x04:
			filterModeString = "(highpass)";
			break;
		case 0x05:
			filterModeString = "(lowpass+highpass)";
			break;
		case 0x06:
			filterModeString = "(bandpass+highpass)";
			break;
		case 0x07:
			filterModeString = "(lowpass+bandpass+highpass)";
			break;
	}

	snprintf(stringBuffer, 255, "Filtermode/Volume: $%02x %s", registers[0x18], filterModeString);
	CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));			
}


// ----------------------------------------------------------------------------
- (void) drawVoice:(int)voice intoContext:(CGContextRef)context atHorizontalPosition:(float)xpos andVerticalPosition:(float)ypos
// ----------------------------------------------------------------------------
{
	const float rowHeight = 13.0f;
	int registerOffset = voice * 7;
	
	const char* voiceString = NULL;

	switch (voice)
	{
		case 0:
			voiceString = "Voice 1";
			break;
		case 1:
			voiceString = "Voice 2";
			break;
		case 2:
			voiceString = "Voice 3";
			break;
	}

	CGContextShowTextAtPoint(context, xpos, ypos, voiceString, strlen(voiceString));			
	ypos -= rowHeight;
	
	char stringBuffer[256];

	unsigned short frequency = registers[registerOffset] + (registers[registerOffset + 1] << 8);
	snprintf(stringBuffer, 255, "Frequency: $%04x", frequency);
	CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));			
	
	const char* noteString = sLookUpNoteStringForFrequency(frequency);
	CGContextShowTextAtPoint(context, xpos + 86.0f, ypos, noteString, strlen(noteString));			
	ypos -= rowHeight;

	unsigned short pulseWidth = (registers[registerOffset + 2] + (registers[registerOffset + 3 ] << 8)) & 0x0FFF;
	snprintf(stringBuffer, 255, "Pulsewidth: $%04x", pulseWidth);
	CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));			
	ypos -= rowHeight;

	snprintf(stringBuffer, 255, "Waveform: $%02x", registers[registerOffset + 4]);
	CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));			
	ypos -= rowHeight;

	unsigned short adsr = registers[registerOffset + 6] + (registers[registerOffset + 5] << 8);
	snprintf(stringBuffer, 255, "ADSR: $%04x", adsr);
	CGContextShowTextAtPoint(context, xpos, ypos, stringBuffer, strlen(stringBuffer));			
	ypos -= rowHeight;
}

@end
