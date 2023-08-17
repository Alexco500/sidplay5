//
//  NewMD5SongLengthDatabase.m
//  SIDPLAY
//
//  Created by Alexander Coers on 01.04.22.
//

#import "NewMD5SongLengthDatabase.h"

static NSString* MD5IdentificationString = @"[Database]";


@implementation NewMD5SongLengthDatabase
@synthesize validDatabase;

- (instancetype)init
{
    self = [super init];
    self->validDatabase = NO;
    self->databasePath = nil;
    return self;
}
- (instancetype)initWithPath:(NSString*)pathToDB
{
    self = [self init];
    self->databasePath = pathToDB;
    // NSLog(@"NewMD5SongLengthDatabase: initWithPath: %@\n", pathToDB);
    NSData *data = [NSData dataWithContentsOfFile:self->databasePath];
    [self createDBfromData:data];
    return self;
}
- (instancetype)initWithData:(NSData*)data
{
    self = [self init];
    [self createDBfromData:data];
    return self;
}


- (void)createDBfromData:(NSData*)data
{
    if (!data)
        return;
    NSMutableDictionary *myDict = [[NSMutableDictionary alloc] init];
    NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *lineBuffer = [myString componentsSeparatedByLineSeparators];
    if (!lineBuffer)
        return;
    if ([(NSString*)[lineBuffer firstObject] caseInsensitiveCompare:MD5IdentificationString] != NSOrderedSame)
        // first line must always be MD5IdentificationString
        return;
    NSEnumerator *enumerator = [lineBuffer objectEnumerator];
    NSString* anObject;
    NSArray *splitItems;
    while (anObject = [enumerator nextObject])
    {
        if ([anObject length] == 0)
            continue;
        if ([anObject characterAtIndex:0] == ';' || [anObject characterAtIndex:0] == '[' )
            // filter out ini tags and comments
            continue;
         splitItems = [anObject componentsSeparatedByString:@"="];
         if ([splitItems count] != 2)
             //something went wrong here
             continue;
        NSArray *timeArray = [self getTimeValuesOfString:(NSString*)[splitItems objectAtIndex:1]];
        if (timeArray)
        {
            [myDict setObject:timeArray forKey:(NSString*)[splitItems objectAtIndex:0]];
        }
    }
    self->validDatabase = YES;
    self->songEntries = myDict;
    return;
}
- (int)getSongLengthByPath:(NSString*)path andSubtune:(int)subtune
{
    NSData *song;
    song = [NSData dataWithContentsOfFile:path];
    if (song) {
        return [[self getSongLengthFromNSData:song andSubtune:subtune] intValue];
    }
    return 0;
}

- (int)getSongLengthFromBuffer:(void*)buffer withBufferLength:(int)length andSubtune:(int)subtune
{
    NSData *song;
    if (!validDatabase)
        return 0;
    song = [NSData dataWithBytes:buffer length:length];
    if (song) {
        return [[self getSongLengthFromNSData:song andSubtune:subtune] intValue];
    }
    return 0;
}
#pragma mark Helper functions
- (NSNumber *)getSongLengthFromNSData:(NSData *)song andSubtune:(int)subtune
{
    NSArray *timeArray;
    NSString *songMD5;
    NSNumber *timeEntry;
    songMD5 = [song md5];
    timeArray = [songEntries objectForKey:songMD5];
    if (!timeArray)
        return 0;
    timeEntry = [timeArray objectAtIndex:subtune-1l];
    return timeEntry;
}
- (NSArray *)getTimeValuesOfString:(NSString*)myString
{
    NSArray *elements, *timeElements;
    NSNumberFormatter *numberFormatter;
    NSEnumerator *enumerator;
    NSString *anString;
    NSMutableArray *timeArray;
    elements = [myString componentsSeparatedByString:@" "];
    if ([elements count] < 1)
        return nil;
    numberFormatter = [[NSNumberFormatter alloc]init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehaviorDefault];
    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [numberFormatter setLocalizesFormat:NO];
    [numberFormatter setAllowsFloats:YES];
    enumerator = [elements objectEnumerator];
    timeArray = [[NSMutableArray alloc] init];
    while (anString = [enumerator nextObject])
    {
        timeElements = [anString componentsSeparatedByString:@":"];
        if ([timeElements count] < 2)
            return nil;
        NSNumber *min = [numberFormatter numberFromString:[timeElements objectAtIndex:0]];
        NSNumber *sec = [numberFormatter numberFromString:[timeElements objectAtIndex:1]];
        if (min != nil && sec != nil)
        {
            //calculate a float value "time in secs" from min and secs
            //currenty only integer is used by player, but some songs have their time
            //also in millisecs, so you may never know...
            float number = [min intValue]*60 + round([sec floatValue]);
            // if rounding down results in 0s, use 1s instead
            if (number == 0) {
                //NSLog(@" Bloerp!");
                //NSLog(@"Minutes: %@, Seconds: %@, rounded to %f\n",min, sec, number);
                number = 1;
            }
            [timeArray addObject:[NSNumber numberWithFloat:number]];
            //[timeArray addObject:sec];
        }
   //     NSLog(@"Minutes: %@, Seconds: %@\n",min, sec);
        min = nil;
        sec = nil;
    }
    return timeArray;
}
@end

#pragma mark NSString/NSData MD5 interface
@implementation NSString (MyAdditions)
- (NSString *)md5
{
    const char *cStr = [self UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (int)strlen(cStr), result ); // This is the md5 call
    return [NSString stringWithFormat:
        @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
        result[0], result[1], result[2], result[3],
        result[4], result[5], result[6], result[7],
        result[8], result[9], result[10], result[11],
        result[12], result[13], result[14], result[15]
        ];
}
@end

@implementation NSData (MyAdditions)
- (NSString*)md5
{
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5( self.bytes, (int)self.length, result ); // This is the md5 call
    return [NSString stringWithFormat:
        @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
        result[0], result[1], result[2], result[3],
        result[4], result[5], result[6], result[7],
        result[8], result[9], result[10], result[11],
        result[12], result[13], result[14], result[15]
        ];
}
@end
