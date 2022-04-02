//
//  StringAddons.h
//  AmigaGuideViewer
//
//  Created by Alexander Coers on 27.07.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
//#import <Foundation/NSString.h>


@interface NSString ( StringAddons ) 
- (NSArray *) componentsSeparatedByLineSeparators;
//- (NSArray*) parseDictLine;
//- (NSString*) dictLineComponent: (int)index;

@end
