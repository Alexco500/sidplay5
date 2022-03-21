
#import "SPAnalyzerPulseWidthSideView.h"


@implementation SPAnalyzerPulseWidthSideView


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	const int steps = 5;
	int values[steps] = { 0, 0x400, 0x800, 0xc00, 0xfff };
	
	NSMutableArray* valueArray = [NSMutableArray arrayWithCapacity:steps];
	for (int i = 0; i < steps; i++)
		[valueArray addObject:[NSNumber numberWithInteger:values[i]]];

	[super setStepValues:valueArray];
	[super setFormatString:"$%03x"];
}


@end
