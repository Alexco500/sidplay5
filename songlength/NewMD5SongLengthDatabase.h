//
//  NewMD5SongLengthDatabase.h
//  SIDPLAY
//
//  Created by Alexander Coers on 01.04.22.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h> // Need to import for CC_MD5 access
#import "StringAddons.h"


@interface NewMD5SongLengthDatabase : NSObject
{
    NSString *databasePath; // path to the database file
    bool validDatabase;
    NSDictionary *songEntries;
}
@property (readonly) bool validDatabase;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithPath:(NSString*)pathToDB;
- (instancetype)initWithData:(NSData*)data;
- (int) getSongLengthByPath:(NSString*)path andSubtune:(int)subtune;
- (int) getSongLengthFromBuffer:(void*)buffer withBufferLength:(int)length andSubtune:(int)subtune;

- (NSNumber *)getSongLengthFromNSData:(NSData *)song andSubtune:(int)subtune;
- (NSArray *)getTimeValuesOfString:(NSString*)myString;
@end

#pragma mark NSString/NSData MD5 interface
@interface NSString (MyAdditions)
- (NSString *)md5;
@end

@interface NSData (MyAdditions)
- (NSString*)md5;
@end

