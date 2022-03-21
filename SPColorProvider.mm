#import "SPColorProvider.h"


@implementation SPColorProvider

static SPColorProvider* sharedInstance = nil;

static NSColor* sDarkBackgroundColor = nil;
static NSColor* sLightBackgroundColor = nil;

static NSArray* sDarkAltColors = nil;
static NSArray* sLightAltColors = nil;

static NSColor* sDarkHighlightCellColor = nil;
static NSColor* sLightHighlightCellColor = nil;

static NSColor* sDarkGridColor = nil;
static NSColor* sLightGridColor = nil;

static NSColor* sAnalyzerVoiceColors[3][3] = { { nil, nil, nil }, { nil, nil, nil }, { nil, nil, nil } };


// ----------------------------------------------------------------------------
+ (SPColorProvider*) sharedInstance
// ----------------------------------------------------------------------------
{
	if (sharedInstance == nil)
		sharedInstance = [[SPColorProvider alloc] init];
		
	return sharedInstance;
}


// ----------------------------------------------------------------------------
- (id) init
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		providesDarkColors = YES;

		sDarkBackgroundColor = [NSColor colorWithCalibratedWhite:0.137f alpha:0.95f];
		sLightBackgroundColor = [NSColor colorWithCalibratedWhite:0.749f alpha:1.0f];

		sDarkAltColors = [NSArray arrayWithObjects:[NSColor colorWithCalibratedWhite:0.16f alpha:0.92f], 
												   [NSColor colorWithCalibratedWhite:0.15f alpha:0.88f], nil];
		sLightAltColors = [NSArray arrayWithObjects:[NSColor colorWithCalibratedWhite:0.891f alpha:1.0f], 
													[NSColor colorWithCalibratedWhite:0.856f alpha:1.0f], nil];

		sDarkHighlightCellColor = [NSColor colorWithCalibratedWhite:0.5f alpha:0.8f];
		sLightHighlightCellColor = [NSColor colorWithCalibratedWhite:0.5f alpha:1.0f];

		sDarkGridColor = [NSColor colorWithCalibratedWhite:0.16f alpha:0.8f];
		sLightGridColor = [NSColor colorWithCalibratedWhite:0.7f alpha:1.0f];
		
		sAnalyzerVoiceColors[0][0] = [NSColor colorWithCalibratedRed:0.82f green:0.56f blue:0.99f alpha:1.0f];
		sAnalyzerVoiceColors[0][1] = [NSColor colorWithCalibratedRed:0.61f green:0.99f blue:0.62f alpha:1.0f];
		sAnalyzerVoiceColors[0][2] = [NSColor colorWithCalibratedRed:0.61f green:0.85f blue:0.99f alpha:1.0f];

		sAnalyzerVoiceColors[1][0] = [NSColor colorWithCalibratedRed:0.82f * 0.7f green:0.56f * 0.7f blue:0.99f * 0.7f alpha:1.0f];
		sAnalyzerVoiceColors[1][1] = [NSColor colorWithCalibratedRed:0.61f * 0.7f green:0.99f * 0.7f blue:0.62f * 0.7f alpha:1.0f];
		sAnalyzerVoiceColors[1][2] = [NSColor colorWithCalibratedRed:0.61f * 0.7f green:0.85f * 0.7f blue:0.99f * 0.7f alpha:1.0f];

		sAnalyzerVoiceColors[2][0] = [NSColor colorWithCalibratedRed:0.82f * 0.5f green:0.56f * 0.5f blue:0.99f * 0.5f alpha:1.0f];
		sAnalyzerVoiceColors[2][1] = [NSColor colorWithCalibratedRed:0.61f * 0.5f green:0.99f * 0.5f blue:0.62f * 0.5f alpha:1.0f];
		sAnalyzerVoiceColors[2][2] = [NSColor colorWithCalibratedRed:0.61f * 0.5f green:0.85f * 0.5f blue:0.99f * 0.5f alpha:1.0f];
	}
	return self;
}


// ----------------------------------------------------------------------------
- (BOOL) providesDarkColors
// ----------------------------------------------------------------------------
{
	return providesDarkColors;
}


// ----------------------------------------------------------------------------
- (void) setProvidesDarkColors:(BOOL)darkColors
// ----------------------------------------------------------------------------
{
	providesDarkColors = darkColors;
}


// ----------------------------------------------------------------------------
- (NSColor*) backgroundColor
// ----------------------------------------------------------------------------
{
	if (providesDarkColors)
		return sDarkBackgroundColor;
	else
		return sLightBackgroundColor;
}


// ----------------------------------------------------------------------------
- (NSArray*) alternatingRowBackgroundColors
// ----------------------------------------------------------------------------
{
	if (providesDarkColors)
		return sDarkAltColors;
	else
		return sLightAltColors;
}


// ----------------------------------------------------------------------------
- (NSColor*) highlightColor
// ----------------------------------------------------------------------------
{
	if (providesDarkColors)
		return sDarkHighlightCellColor;
	else
		return sLightHighlightCellColor;
}


// ----------------------------------------------------------------------------
- (NSColor*) gridColor
// ----------------------------------------------------------------------------
{
	if (providesDarkColors)
		return sDarkGridColor;
	else
		return sLightGridColor;
}


// ----------------------------------------------------------------------------
- (NSColor*) analyzerVoiceColor:(int)inVoice shade:(int)inShade
// ----------------------------------------------------------------------------
{
	return sAnalyzerVoiceColors[inShade][inVoice];
}


@end
