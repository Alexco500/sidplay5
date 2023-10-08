//
//  PlayerWrapper.h
//  SIDPLAY
//
//  Created by Alexander Coers on 29.09.23.
//

#ifndef PlayerWrapper_h
#define PlayerWrapper_h


@interface PlayerWrapper : NSObject {
    BOOL tuneLoaded;
    BOOL isPlaying;
}
+ (id)sharedPlayer;
- (id)init;
- (BOOL)loadTuneFrom:(NSData *)data asInstance:(unsigned int*)instance;
- (void)stopAllPlayerInstances;
- (void)stopPlayerWithInstance:(unsigned int)instance;
- (short *)currentAudioBuffer;
- (unsigned int)currentNumberOfSamples;
- (BOOL)isPlaying;
- (NSString *)currentTitle;
- (NSString *)currentAuthor;
- (NSString *)currentReleaseInfo;
- (unsigned int)subtuneCount;
- (unsigned int)defaultSubtune;
- (unsigned int)sidChips;
- (unsigned int)currentLoadAddress;
- (unsigned int)currentInitAddress;
- (unsigned int)currentPlayAddress;
- (NSString *)currentFormat;
- (unsigned int)currentFileSize;
- (NSString *)currentChipModel;

@end
#endif /* PlayerWrapper_h */
