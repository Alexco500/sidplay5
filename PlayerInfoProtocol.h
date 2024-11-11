//
//  PlayerInfoProtocol.h
//  SIDPLAY
//
//  Created by Alexander Coers on 15.04.24.
//

#ifndef PlayerInfoProtocol_h
#define PlayerInfoProtocol_h
// protocol for player info topics
@protocol PlayerInfo
- (short*) audioDriverSampleBuffer;
- (BOOL) audioDriverIsPlaying;
- (unsigned int) currentNumberOfSamples;
- (NSString *)currentTitle;
- (NSString *)currentAuthor;
@end


#endif /* PlayerInfoProtocol_h */
