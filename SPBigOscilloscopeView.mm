//
//  SPBigOscilloscopeView.m
//  SIDPLAY
//
//  Created by Alexander Coers on 12.04.24.
//
#import <Cocoa/Cocoa.h>
#import "SPBigOscilloscopeView.h"

#import "SPPlayerWindow.h"

@implementation SPBigOscilloscopeView
- (void)setPlayerWindow:(SPPlayerWindow*)newPlayerW
{
    @synchronized (playerW) {
        playerW = (SPPlayerWindow*)newPlayerW;
    }
    hSample = 0;
}

-(void)updatePlayerInfo
{
    currentTitle = [playerW currentTitle];
    currentAuthor = [playerW currentAuthor];
    updateNeeded = YES;
}
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
    short* sampleBuffer = NULL;
    BOOL isPlaying = NO;
    /* we use protocols here, simply because I don't want
     * to change the whole LibPlayerClass here
     */
    if ([playerW conformsToProtocol: @protocol (PlayerInfo)]== YES)
    {
        sampleBuffer = [playerW audioDriverSampleBuffer];
     
    }
    if (sampleBuffer == NULL)
        return;
    unsigned int numSamples =  0;

    /* normally we could skip this test, since we tested it aleady above, but...*/
    if ([(id)playerW conformsToProtocol: @protocol (PlayerInfo)]== YES)
    {
        isPlaying = [(id)playerW audioDriverIsPlaying];
        numSamples = [(id)playerW currentNumberOfSamples];
     
    }
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
        float stepW;
        //sample buffer contains signed 16 bit samples
        // -32768 - 32767
        float factorH = height/33000/2;
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
            linePoints[i].y = zeroLineHeight + (sampleBuffer[(int)trunc(indexS)] * factorH);
            if (sampleBuffer[(int)trunc(indexS)] > hSample)
                hSample = sampleBuffer[(int)trunc(indexS)];
            indexS +=stepW;
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
    if (updateNeeded)
    {
        // new text needs to be printed
        NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:currentTitle];
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:@" by "]];
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:currentAuthor]];
        CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)text);
        // Set text position and draw the line into the graphics context
        CGContextSetTextPosition(context, 10.0, 50.0);
        CTLineDraw(line, context);
        CFRelease(line);
    }
    //draw a frame around the view
    [darkColor set];
    NSFrameRect(bounds);
    bounds = NSInsetRect(bounds, 1.0f, 1.0f);
    [brightColor set];
}

@end
