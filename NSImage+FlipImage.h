//
//  NSImage+FlipImage.h
//  SIDPLAY
//
//  Created by Alexander Coers on 04.12.24.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (FlipImage)
- (NSImage *)flipImageVertical;
- (NSImage *)flipImageHorizontal;
@end

NS_ASSUME_NONNULL_END
