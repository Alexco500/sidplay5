//
//  ASID_MIDI.m
//  SIDPLAY
//
//  Created by Thorsten Klose on 15.10.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "ASID_MIDI.h"
#import <PYMIDI/PYMIDI.h>

@implementation ASID_MIDI


// delay between (the first) SID register write and an update via MIDI
// assumed that the song handler is called each 20000 cycles (50 Hz), MIDI
// data should be sent after this delay in the hope that all SID register
// accesses have been done until then
// *** ONLY CHANGE WHEN YOU KNOW WHAT YOU ARE DOING!!! ***
#define ASID_UPDATE_DELAY 8

// number of registers transfered to SID - note that the three waveform registers exist twice
// *** DONT TOUCH!!! ***
#define ASID_REG_SIZE (25+3)

// debug messages (allowed values: 0, 1, 2)
#define ASID_VERBOSE 0




static int asid_reg[ASID_REG_SIZE];
static int asid_timer_ctr = 0;

int  ASID_MIDI_Open(void);
void ASID_MIDI_Close(void);
void ASID_MIDI_FlushBuffer(int force);
void ASID_MIDI_Write(uint_least8_t addr, uint8_t data);


static NSObject *_self;

static NSRecursiveLock *MIDIOUTSemaphore;

PYMIDIVirtualSource *virtualMIDI_OUT;


//////////////////////////////////////////////////////////////////////////////
// this task is invoked periodically to check for SID register changes
//////////////////////////////////////////////////////////////////////////////
- (void)periodicMIDITask:(id)anObject
{	
	while (YES) {
		if( asid_timer_ctr && !--asid_timer_ctr ) {
			[MIDIOUTSemaphore lock];
			ASID_MIDI_FlushBuffer(0);
			[MIDIOUTSemaphore unlock];
		}
		
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
    }
	
	[NSThread exit];
}


//////////////////////////////////////////////////////////////////////////////
// init local variables
//////////////////////////////////////////////////////////////////////////////
- (id) init
{
	self = [super init];
	if (self != nil)
	{
		_self = self;	
		
		int i;
		for(i=0; i<ASID_REG_SIZE; ++i)
			asid_reg[i] = 0x100;

		asid_timer_ctr = 10;

		MIDIOUTSemaphore = [[NSRecursiveLock alloc] init];

		NSMutableString *portName = [[NSMutableString alloc] init];
		[portName appendFormat:@"ASID OUT"];
		virtualMIDI_OUT = [[PYMIDIVirtualSource alloc] initWithName:portName];
	
		[NSThread detachNewThreadSelector:@selector(periodicMIDITask:) toTarget:self withObject:nil];
	};
	
	return self;
}


/////////////////////////////////////////////////////////////////////////////
// TODO: How to ensure that the MIDI message has been completely sent before this
// object is destroyed?
/////////////////////////////////////////////////////////////////////////////
- (void) dealloc
{
	asid_reg[0x18-3] = (asid_reg[0x18-3] & 0xf0) | 0x100;
	
	[MIDIOUTSemaphore lock];
    ASID_MIDI_FlushBuffer(1);
	[MIDIOUTSemaphore unlock];
}


/////////////////////////////////////////////////////////////////////////////
// Pause on/off
/////////////////////////////////////////////////////////////////////////////
- (void) pause:(BOOL)pause;
{
	if( pause )
		asid_reg[0x18-3] = (asid_reg[0x18-3] & 0xf0) | 0x100;
	else {
		asid_reg[0x18-3] = (asid_reg[0x18-3] | 0x0f) | 0x100;
	}

	if( !asid_timer_ctr )
		asid_timer_ctr = ASID_UPDATE_DELAY;
}


/////////////////////////////////////////////////////////////////////////////
// Send a SysEx stream
/////////////////////////////////////////////////////////////////////////////
static int ASID_MIDI_SendSysEx(unsigned char *buffer, unsigned int len)
{
	MIDIPacketList packetList;
	MIDIPacket *packet = MIDIPacketListInit(&packetList);

	if( len ) {
		packet = MIDIPacketListAdd(&packetList, sizeof(packetList), packet,
								   0, // timestamp
								   len, buffer);
		[virtualMIDI_OUT addSender:_self];
		[virtualMIDI_OUT processMIDIPacketList:&packetList sender:_self];
		[virtualMIDI_OUT removeSender:_self];		
	}
	
	return 0; // no error
}


/////////////////////////////////////////////////////////////////////////////
// Flush last SID register changes
/////////////////////////////////////////////////////////////////////////////
void ASID_MIDI_FlushBuffer(int force)
{
	int i;
	
	unsigned char stream[256];
	int stream_size = 0;
	
	// don't flush if no register has been updated
	int update_required = 0;
	for(i=0; i<ASID_REG_SIZE; ++i) {
		if( asid_reg[i] & 0x100 ) {
			update_required = 1;
		}
	}
	
	if( !update_required )
		return;
	
	
	// SysEx header
	stream[stream_size++] = 0xf0;
	stream[stream_size++] = 0x2d;
	stream[stream_size++] = 0x4e;
	
	// mask flags - each asid value has a "dirty" flag (bit #8) which is
	// set when then SID register has been written, and accordingly will
	// be transfered via SysEx
	int mask_byte;
	for(mask_byte=0; mask_byte<4; ++mask_byte) {
		int reg = 0x00;
		int reg_offset;
		for(reg_offset=0; reg_offset<7; ++reg_offset) {
			if( asid_reg[mask_byte*7 + reg_offset] & 0x100 ) {
				reg |= (1 << reg_offset);
			}
		}
		stream[stream_size++] = reg;
	}
	
	// MSBs - only 7bit values can be transfered via SysEx, but the SID
	// has 8bit registers --- therefore the MSBs have to be sent seperately
	int msb_byte;
	for(msb_byte=0; msb_byte<4; ++msb_byte) {
		int reg = 0x00;
		int reg_offset;
		for(reg_offset=0; reg_offset<7; ++reg_offset) {
			if( asid_reg[msb_byte*7 + reg_offset] & 0x80 ) {
				reg |= (1 << reg_offset);
			}
		}
		stream[stream_size++] = reg;
	}
	
	// now send the 7bit values of registers which have the dirty flag set
	for(i=0; i<ASID_REG_SIZE; ++i) {
		if( asid_reg[i] & 0x100 ) {
			stream[stream_size++] = asid_reg[i] & 0x7f;
		}
	}
	
	// SysEx footer
	stream[stream_size++] = 0xf7;
	
	// send via MIDI
	ASID_MIDI_SendSysEx(stream, stream_size);
	
#if ASID_VERBOSE >= 1
	printf("[%09d] ", 0);
	for(i=0; i<stream_size; ++i) {
		printf("%02x ", stream[i]);
	}
	printf("\n");
#endif
	
	// clear dirty flags
	for(i=0; i<ASID_REG_SIZE; ++i) {
		asid_reg[i] &= 0xff;
	}
}

/////////////////////////////////////////////////////////////////////////////
// Should be called on SID Register Writes
/////////////////////////////////////////////////////////////////////////////
void ASID_MIDI_Write(uint_least8_t addr, uint8_t data)
{
	if( addr >= ASID_REG_SIZE )
		return;
	
	// SID address -> position within ASID protocol
	uint_least8_t map[ASID_REG_SIZE] = { 
		0x00, 0x01, 0x02, 0x03, 0x16, 0x04, 0x05, 
		0x06, 0x07, 0x08, 0x09, 0x17, 0x0a, 0x0b, 
		0x0c, 0x0d, 0x0e, 0x0f, 0x18, 0x10, 0x11, 
		0x12, 0x13, 0x14, 0x15, 0x19, 0x1a, 0x1b };
	uint_least8_t mapped_addr = map[addr];
	
	// TK: this probably doesn't match with the way how the original ASID software handles the second 
	// waveform register set - but I find it useful this way
	// strategy: whenever the two sets are allocated, shift the 2nd one to the first entry...
	// this ensures, that the two last waveform changes take place
	
	// write to waveform register? check if first set is already allocated
	if( mapped_addr >= 0x16 && mapped_addr <= 0x18 && asid_reg[mapped_addr] & 0x100 ) {
		// switch to second waveform register set
		mapped_addr += 3;
		
		// if this one is allocated as well, copy the old one to the first set
		if( asid_reg[mapped_addr] & 0x100 )
			asid_reg[mapped_addr-3] = asid_reg[mapped_addr];
	}
	
	if( asid_reg[mapped_addr] & 0x100 ) {
#if ASID_VERBOSE >= 2
		printf("[%09d] WARNING: %02x (%02x) already allocated!\n", 0, mapped_addr, addr);
#endif
		if( mapped_addr >= 0x16 ) {
			[MIDIOUTSemaphore lock];
			ASID_MIDI_FlushBuffer(0);
			[MIDIOUTSemaphore unlock];
		}
	}
	
	asid_reg[mapped_addr] = 0x100 | (int)data;
	
    // first register access after update? start timer if it isn't running yet
    if( !asid_timer_ctr ) {
		asid_timer_ctr = ASID_UPDATE_DELAY;
#if ASID_VERBOSE >= 2
		printf("[%09d] TIMER started\n", 0);
#endif
    }
	
}

@end
