
#import <Cocoa/Cocoa.h>


@interface SPAnalyzerScaleSideView : NSView
{
	NSArray* stepValues;
	const char* formatString;
}

- (NSArray*) stepValues;
- (void) setStepValues:(NSArray*)inStepValues;

- (const char*) formatString;
- (void) setFormatString:(const char*)inFormatString;

@end
