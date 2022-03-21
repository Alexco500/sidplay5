
#import "SPAnalyzerSampleSideView.h"


@implementation SPAnalyzerSampleSideView


// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	const int steps = 5;
	int values[steps] = { -100, 50, 0, 50, 100 };
	
	NSMutableArray* valueArray = [NSMutableArray arrayWithCapacity:steps];
	for (int i = 0; i < steps; i++)
		[valueArray addObject:[NSNumber numberWithInteger:values[i]]];
	
	[super setStepValues:valueArray];
	[super setFormatString:"%d"];
}


@end
