//
//  PVScopeView.m
//  SIDTuneViewer
//
//  Created by Alexander Coers on 02.10.23.
//

#import "PVScopeView.h"

@implementation PVScopeView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    // Drawing code here.
    NSColor* darkColor = nil;
    NSColor* brightColor = nil;
    darkColor = [NSColor colorWithDeviceRed:0.117f green:0.117f blue:0.117f alpha:1.0f];
    brightColor = [NSColor colorWithDeviceRed:0.321f green:0.321f blue:0.321f alpha:1.0f];

    //NSFrameRect(bounds);
    NSRect bounds = self.bounds;

    CGRect contextRect;
    contextRect.origin.x = dirtyRect.origin.x;
    contextRect.origin.y = dirtyRect.origin.y;
    contextRect.size.width = dirtyRect.size.width;
    contextRect.size.height = dirtyRect.size.height;

    CGContextRef context = (CGContextRef) [NSGraphicsContext currentContext].graphicsPort;
    CGContextSetRGBFillColor(context, 0.0f, 0.0f, 0.0f, 0.6f);
    CGContextFillRect(context, contextRect);

    //AudioDriver* audioDriver = (AudioDriver*) [[container ownerWindow] audioDriver];
    if (playerW == nil)
        return;
    
    short* sampleBuffer = [playerW currentAudioBuffer];
    BOOL isPlaying = [playerW isPlaying];
    
    float zeroLineHeight = contextRect.size.height * 0.5f + 0.5f;
    float width = contextRect.size.width;
    float height = contextRect.size.height;
    
    if (isPlaying)
        CGContextSetRGBStrokeColor(context, 0.2f, 1.0f, 1.0f, 1.0f);
    else
    {
        float error = 0.1f * (random() & 0xffff) / 65535.0f;
        float brightness = error + 0.9f;
        
        CGContextSetRGBStrokeColor(context, 0.2f, brightness, brightness, 1.0f);
    }

    CGContextBeginPath(context);
    CGContextSetLineWidth(context, 1.2f);
    
    if (isPlaying && sampleBuffer != nil)
    {
        static CGPoint linePoints[2048];
        unsigned int numSamples = [playerW currentNumberOfSamples];
        float stepW;
        float factorH = height/32767/2;
        // clamp width to array size
        // FIXME: find a better solution that to use a fixed max. width
        if (width > 2048)
            width = 2048;
        
        // create a ratio for the width, since the audio buffer can differ in size
        // and maybe less than width pixels
        if ((width == 0) || (numSamples == 0))
            stepW = 0;
         else
             stepW = (float)numSamples/(float)width;
        float indexS = 0;
        for (int i = 0; i < width; i++)
        {
            linePoints[i].x = i + 0.5f;
            //sample buffer contains signed 16 bit samples
            // –32768 to 32767
            linePoints[i].y = zeroLineHeight + (sampleBuffer[(int)trunc(indexS)] * factorH);
            indexS +=stepW;
            if (highestVal < sampleBuffer[(int)trunc(indexS)])
                highestVal = sampleBuffer[(int)trunc(indexS)];
        }

        CGContextAddLines(context, linePoints, width);
        CGContextDrawPath(context, kCGPathStroke);
        
    }
    else
    {
        static CGPoint linePoints[2];
        linePoints[0].x = contextRect.origin.x;
        linePoints[0].y = zeroLineHeight;
        linePoints[1].x = width;
        linePoints[1].y = zeroLineHeight;

        CGContextAddLines(context, linePoints, 2);
        CGContextDrawPath(context, kCGPathFillStroke);
    }
    //draw a frame around the view
    [darkColor set];
    NSFrameRect(bounds);
    bounds = NSInsetRect(bounds, 1.0f, 1.0f);
    [brightColor set];

}
-(void)setPlayer:(PlayerWrapper *)player withInstance:(unsigned int)instance
{
    playerW = player;
    myInstance = instance;
    highestVal = 0;
}
@end

