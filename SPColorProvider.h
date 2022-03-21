#import <Cocoa/Cocoa.h>


@interface SPColorProvider : NSObject
{
	BOOL providesDarkColors;
}

+ (SPColorProvider*) sharedInstance;

- (BOOL) providesDarkColors;
- (void) setProvidesDarkColors:(BOOL)darkColors;

- (NSColor*) backgroundColor;
- (NSArray*) alternatingRowBackgroundColors;
- (NSColor*) highlightColor;
- (NSColor*) gridColor;

- (NSColor*) analyzerVoiceColor:(int)inVoice shade:(int)inShade;

@end
