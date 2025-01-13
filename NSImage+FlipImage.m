//
//  NSImage+FlipImage.m
//  SIDPLAY
//
//  Created by Alexander Coers on 04.12.24.
//

#import "NSImage+FlipImage.h"

@implementation NSImage (FlipImage)

- (NSImage *)flipImageVertical
{
    // flip image, replaces [image setFlipped:]
    NSImage* flippedImage = [[NSImage alloc] initWithSize:[self size]];
    [flippedImage lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

    NSAffineTransform *flipTransform = [NSAffineTransform transform];
    //NSAffineTransformStruct flip = {-1.0, 0.0, 0.0, 1.0, [oldImage size].width, 0.0 }; // horizontal flip
    NSAffineTransformStruct flip = {1.0, 0.0, 0.0, -1.0, 0.0, [self size].height}; // vertical flip
    [flipTransform translateXBy:[self size].width yBy:[self size].height];
    [flipTransform setTransformStruct:flip];
    [flipTransform concat];
    [self drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
    [flippedImage unlockFocus];
    return flippedImage;
}
- (NSImage *)flipImageHorizontal
{
    NSImage* flippedImage = [[NSImage alloc] initWithSize:[self size]];
    [flippedImage lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

    NSAffineTransform *flipTransform = [NSAffineTransform transform];
    NSAffineTransformStruct flip = {-1.0, 0.0, 0.0, 1.0, [self size].width, 0.0 }; // horizontal flip
    //NSAffineTransformStruct flip = {1.0, 0.0, 0.0, -1.0, 0.0, [oldImage size].height}; // vertical flip
    [flipTransform translateXBy:[self size].width yBy:[self size].height];
    [flipTransform setTransformStruct:flip];
    [flipTransform concat];
    [self drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
    [flippedImage unlockFocus];
    return flippedImage;
}

@end
