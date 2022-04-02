//
//  StringAddons.m
//  Created by Alexander Coers on 27.07.07.
/*
    Split a string into an array of lines; unicode-aware
    Original Source: <http://cocoa.karelia.com/Foundation_Categories/NSString/Split_Into_LInes.m>
    (See copyright notice at <http://cocoa.karelia.com>)
 COPYRIGHT AND PERMISSION NOTICE

 Copyright © 2003 Karelia Software, LLC. All rights reserved.

 Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF THIRD PARTY RIGHTS. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 Except as contained in this notice, the name of a copyright holder shall not be used in advertising or otherwise to promote the sale, use or other dealings in this Software without prior written authorization of the copyright holder.
 
 */

#import "StringAddons.h"


@implementation NSString (StringAddons)



/*"	Split a string into lines separated by any of the various newline characters.  Equivalent to componentsSeparatedByString:@"\n" but it works with the different line separators: \r, \n, \r\n, 0x2028, 0x2029 "*/

- (NSArray *) componentsSeparatedByLineSeparators
{
	NSMutableArray *result	= [NSMutableArray array];
	NSRange range = NSMakeRange(0,0);
    unsigned long start=0;
    unsigned long end=0;
	unsigned long contentsEnd = 0;
	
	while (contentsEnd < [self length])
	{
		[self getLineStart:&start end:&end contentsEnd:&contentsEnd forRange:range];
		[result addObject:[self substringWithRange:NSMakeRange(start,contentsEnd-start)]];
		range.location = end;
		range.length = 0;
	}
	return result;
}
/**
* Splits a Dict-protocol-style string into its components and returns
 * an array with those components. A string like this consists of one
 * or more strings that are separated by a whitespace. A string that
 * contains whitespaces itself can be put into quotation marks.
 *
 * Example:
 * The string
 *     '151 "Awful" gcide "The Collaborative International Dict..."'
 *
 * would decode to:
 *     ['151', 'Awful', 'gcide', 'The Collaborative Internation...']
 */
/*
-(NSArray*) parseDictLine
{
	NSScanner* scanner = [NSScanner scannerWithString: self];
	
	NSCharacterSet* space = [NSCharacterSet characterSetWithCharactersInString: @" "];
	NSCharacterSet* nothing = [NSCharacterSet characterSetWithCharactersInString:[NSString string]];
	NSCharacterSet* original = [scanner charactersToBeSkipped];
	
	NSCharacterSet* quotationMarks = [NSCharacterSet characterSetWithCharactersInString: @"\""];
	
	NSMutableArray* result = [NSMutableArray arrayWithCapacity: 8];
	
	while ([scanner isAtEnd] == NO) {
		// Location: At the beginning of a word, possible quotation
		//           marks not yet eaten.
		
		BOOL isQuoted = [scanner scanCharactersFromSet: quotationMarks intoString: (NSString**) nil];
		
		if (isQuoted) {
			// Location: At the beginning of a word, right after the quotation
			//           mark. (FIXME: This is assuming there is no empty string!)
			
			NSString* word=nil;
			
			// If inside a quoted part, skip no characters!!
			[scanner setCharactersToBeSkipped:nothing];
			
			[scanner scanUpToCharactersFromSet: quotationMarks intoString: &word];

			if (nil != word) 
			{
				[result addObject: word];
			}
			
			// Location: At the end of a word, with the pointer pointing to
			//           the closing quotation marks
			
			// eat closing quotation marks
			[scanner scanCharactersFromSet: quotationMarks intoString: (NSString**) nil];
			
			// replace original set for further scanning
			[scanner setCharactersToBeSkipped:original];
			
			// Location: At the end of a word, after the quotation mark
		} else {
			// Case 2: The word is not quoted, parse to the next whitespace!
			
			// Location: At the beginning of a word without quotation marks
			NSString* word=nil;
			
			[scanner scanUpToCharactersFromSet: space intoString: &word];
			
			if (nil != word)
			{
				[result addObject: word];
			}
			// Location: At the end of a non-quoted word.
		}
		
		// Location: At the end of a word, we still need to eat some white
		//           spaces to reach the next word.
		[scanner scanCharactersFromSet: space intoString: (NSString**) nil];
		
	} //end of while loop
	
	return result;
}

-(NSString*) dictLineComponent: (int)index
{
	NSArray* array = [self parseDictLine];
	
	if (array == nil)
		return nil;
	if (index >= [array count])
	{
		return nil;
	}
	NSString* component = (NSString*) [array objectAtIndex: index];
	
	return component; // implicitely: returns nil if component was nil
}
 */
@end
