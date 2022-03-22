
#import <Cocoa/Cocoa.h>


@interface SPAnalyzerScaleSideView : NSView
{
	NSArray* stepValues;
	const char* formatString;
}

@property (NS_NONATOMIC_IOSONLY, copy) NSArray *stepValues;

@property (NS_NONATOMIC_IOSONLY) const char *formatString;

@end
