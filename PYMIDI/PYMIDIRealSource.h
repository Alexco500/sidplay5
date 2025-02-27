/*
    This software is distributed under the terms of Pete's Public License version 1.0, a
    copy of which is included with this software in the file "License.html".  A copy can
    also be obtained from http://pete.yandell.com/software/license/ppl-1_0.html
    
    If you did not receive a copy of the license with this software, please notify the
    author by sending e-mail to pete@yandell.com
    
    The current version of this software can be found at http://pete.yandell.com/software
     
    Copyright (c) 2002-2004 Peter Yandell.  All Rights Reserved.
    
    $Id: PYMIDIRealSource.h 137 2008-11-30 14:28:22Z tk $
*/


#import <PYMIDI/PYMIDIEndpoint.h>
#import <PYMIDI/PYMIDIRealEndpoint.h>


@interface PYMIDIRealSource : PYMIDIRealEndpoint {
}

- (id)initWithCoder:(NSCoder*)coder;

- (void)syncWithMIDIEndpoint;

- (void)startIO;
- (void)stopIO;
- (void)processMIDIPacketList:(const MIDIPacketList*)packetList sender:(id)sender;

@end
