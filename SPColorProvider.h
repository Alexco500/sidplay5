#import <Cocoa/Cocoa.h>


@interface SPColorProvider : NSObject
{
    BOOL providesDarkColors;
}

+ (SPColorProvider*) sharedInstance;

@property (NS_NONATOMIC_IOSONLY) BOOL providesDarkColors;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSColor *backgroundColor;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *alternatingRowBackgroundColors;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSColor *highlightColor;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSColor *gridColor;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSColor *rgbFillColor;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSColor *rgbStrokeColor;

- (NSColor*) analyzerVoiceColor:(int)inVoice shade:(int)inShade;

@end
