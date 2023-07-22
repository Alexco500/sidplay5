//
//  SIDBlaster.m
//  SIDBlaster Tool
//
//  Created by Alexander Coers on 30.06.23.
//

#import <Foundation/Foundation.h>

#import "SIDBlaster.h"

// macros for abs<=>time converting
#define TimeInNanosToCpuAbs(nanos) ((nanos * (info.denom)) / (info.numer))
#define CpuAbsToTimeInNanos(abs)   ((abs * (info.numer)) / (info.denom))

// kernel time, for last USB Write access (read is done with first write, then read)
// we need to keep the last write time for delay calc.
uint64_t timeOfFirstSidAccess;
uint64_t sumOfDelayCyclesInCpuAbs;
uint64_t thresholdToWaitInAbs; //THRESHOLD_WAIT_IN_NANOS in CpuAbs units
static mach_timebase_info_data_t info;

inline static void delayCommandWithCycles(long cycles);

@implementation SIDBlaster

- (id)init
{
    self = [super init];
    if (mach_timebase_info(&info) != KERN_SUCCESS) {
        NSLog(@"Failed to obtain kernel time info! Panic!!\n");
        return nil;
    }
    NSLog(@"Timebase numer: %u, denom %u",info.numer, info.denom);
    usbSendQueue = [[NSMutableArray alloc]init];
    usbRecvQueue = [[NSMutableArray alloc]init];
    thresholdToWaitInAbs = TimeInNanosToCpuAbs(THRESHOLD_WAIT_IN_NANOS);
    NSLog(@"Threshold ms: %llu, abs: %llu", THRESHOLD_WAIT_IN_NANOS, thresholdToWaitInAbs);
    commandCounter = 0;
    oldCounter = 0;
    return self;
}
- (void)dealloc
{
    [self flush];
    [self closeDevice];
}
- (void)addSIDCommandToQueue:(int)type
                       delay:(long)delayInCycles
                 SIDRegister:(int)reg
                       value:(int)value
{

    //FIXME: do we need atimestamp?
    while ([usbSendQueue count] > 50) {}
        //usleep(500);
    @synchronized (usbSendQueue) {
        NSArray *newCmd = @[[NSNumber numberWithInt:type], [NSNumber numberWithLong:delayInCycles], [NSNumber numberWithInt:reg], [NSNumber numberWithInt:value], [NSNumber numberWithUnsignedInt:commandCounter]];
        [usbSendQueue addObject:newCmd];
        commandCounter++;
    }
}
- (void)commandQueueRunner:(id)object
{
    // this will run in a different task and check for commands in queue
    while (1) {
        /*
        if ([usbSendQueue count] == 0) {
            // wait until queue has some amount of content
            usleep(500);
        }
        else {
            */
        
            while ([usbSendQueue count] != 0)
            {
                // work through every entry until zero...
                NSArray *nextCommand;
                @synchronized (usbSendQueue) {
                    nextCommand = [usbSendQueue firstObject];
                    [usbSendQueue removeObject:nextCommand];
                    unsigned int ccounter = [nextCommand[SID_CMD_NUMBER] intValue];
                    if (ccounter-oldCounter > 1)
                        NSLog(@"**** Packet loss, new: %u, old: %u", ccounter, oldCounter);
                    oldCounter = ccounter;
                    //NSLog(@"Number of cmd in queue %lu, count %d", (unsigned long)[usbSendQueue count],[nextCommand[SID_CMD_NUMBER] intValue]);
                }
                unsigned int bytesWritten = 0;
                DWORD BytesReceived;
                char RxBuffer[256];
                
                int cmdType = [nextCommand[SID_CMD_TYPE] intValue];
                long delayC = [nextCommand[SID_CMD_DELAY] longValue];
                int cmdRegister = [nextCommand[SID_CMD_REGISTER] intValue];
                int cmdValue = [nextCommand[SID_CMD_VALUE] intValue];
                
                switch (cmdType) {
                    case SID_DELAY:
                        delayCommandWithCycles(delayC);
                        break;
                    case SID_WRITE:
                        // is register value in write-only area?
                        if (cmdRegister < 25) {
                            //store value in register mirror
                            sidRegisterArray[cmdRegister] = cmdValue;
                            uint8_t buffer[2];
                            buffer[0] = cmdRegister |= 0xe0;  // needed for SIDBlaster USB, indicates write
                            buffer[1] = cmdValue;
                            delayCommandWithCycles(delayC);
                            //USB_WRITE value to Register
                            if (!FT_SUCCESS(ft_status = FT_Write(ft_handle, (void *)buffer, 2, &bytesWritten))) {
                                NSLog(@"Write error to SIDBlasterUSB!\n");
                            }
                            
                        } else {
                            NSLog(@"write to read-only reg!!");
                        }
                        break;
                    case SID_READ:
                        if (cmdRegister >= 25) {
                            // read value from USB device
                            //USB_WRITE Register
                            uint8_t buffer[2];
                            buffer[0] = cmdRegister |= 0xa0;  // needed for SIDBlaster USB, indicates read
                            buffer[1] = 0;
                            delayCommandWithCycles(delayC);
                            //USB_WRITE value to Register
                            if (!FT_SUCCESS(ft_status = FT_Write(ft_handle, (void *)buffer, 2, &bytesWritten))) {
                                NSLog(@"Read error to SIDBlasterUSB (register write)!\n");
                            }
                            //USB_READ from Register
                            ft_status = FT_Read(ft_handle,RxBuffer,1,&BytesReceived);
                            if (ft_status == FT_OK) {
                                // FT_Read OK
                                NSNumber *byte = [NSNumber numberWithInt:RxBuffer[0]];
                                [usbRecvQueue addObject:byte];
                                if (BytesReceived > 1)
                                    NSLog(@"Warning: USB read results in too many bytes\n");
                            }
                            else {
                                // FT_Read Failed
                                NSLog(@"Read error to SIDBlasterUSB (empty buffer)!\n");
                                NSNumber *byte = [NSNumber numberWithInt:0];
                                [usbRecvQueue addObject:byte];
                            }
                        } else {
                            //return value from register mirror
                            // I don't know why the reSID engine sometimes asks for write-only regs...
                            delayCommandWithCycles(delayC);
                            NSNumber *byte = [NSNumber numberWithInt:sidRegisterArray[cmdRegister]];
                            [usbRecvQueue addObject:byte];
                        }

                    default:
                        break;
                }

            }
        }
   // }
}
- (void)flush
{
    @synchronized (usbSendQueue) {
        [usbSendQueue removeAllObjects];
    }
    @synchronized (usbRecvQueue) {
        [usbRecvQueue removeAllObjects];
    }
}
- (void)resetWithVolume:(uint8_t)volume
{
    [self flush];
    [self writeToSidRegister:0x01 value:0];
    [self writeToSidRegister:0x00 value:0];
    [self writeToSidRegister:0x08 value:0];
    [self writeToSidRegister:0x07 value:0];
    [self writeToSidRegister:0x0f value:0];
    [self writeToSidRegister:0x0e value:0];
    [self writeToSidRegister:0x04 value:0];
    [self writeToSidRegister:0x05 value:0];
    [self writeToSidRegister:0x06 value:0];
    [self writeToSidRegister:0x0b value:0];
    [self writeToSidRegister:0x0c value:0];
    [self writeToSidRegister:0x0d value:0];
    [self writeToSidRegister:0x12 value:0];
    [self writeToSidRegister:0x13 value:0];
    [self writeToSidRegister:0x14 value:0];

    [self writeToSidRegister:0x18 value:(volume&0x0f)];
    sumOfDelayCyclesInCpuAbs = 0;
    timeOfFirstSidAccess = 0;
    commandCounter = 0;
    oldCounter = 0;
}
- (void)writeToSidRegister:(uint8_t)reg value:(uint8_t)value
{
    unsigned int bytesWritten = 0;
    if (reg < 25) {
        //store value in register mirror
        sidRegisterArray[reg] = value;
        uint8_t buffer[2];
        buffer[0] = reg |= 0xe0;  // needed for SIDBlaster USB, indicates write
        buffer[1] = value;
        //USB_WRITE value to Register
        if (!FT_SUCCESS(ft_status = FT_Write(ft_handle, (void *)buffer, 2, &bytesWritten))) {
            NSLog(@"Write error to SIDBlasterUSB!\n");
        }
    }
}
- (uint8_t)lastRcvedByte
{
    while([usbRecvQueue count] == 0) {
        usleep(1000); // sleep for 1000us
    }
    NSNumber *number;
    @synchronized (usbRecvQueue) {
        number = [usbRecvQueue firstObject];
        [usbRecvQueue removeObjectAtIndex:0];
    }
    uint8_t retVal = [number intValue];
    return retVal;
}
- (void)setDeviceInfo:(FT_DEVICE_LIST_INFO_NODE *)devInfo
{
    if (devInfo == NULL)
        return;
    memcpy(&ft_info, devInfo, sizeof(FT_DEVICE_LIST_INFO_NODE));
}
- (BOOL)sameAsDeviceWithSerial:(char *)serialToCheck
{
    if (serialToCheck == NULL)
        return NO;
    if (memcmp(&ft_info.SerialNumber, serialToCheck, sizeof(char[16])) != 0)
        return NO;
    return YES;
}
- (void)copySerialNumberInBuffer:(char *)output withLen:(unsigned int)len
{
    if (len >sizeof(char[16]))
        len = sizeof(char[16]);
    memcpy(output, &ft_info.SerialNumber, len);
}
- (int)getSIDType
{
    if (strlen(ft_info.Description) == 19) {
        if (strcmp(ft_info.Description + 15, "6581") == 0)
            return SID_TYPE_6581;
        if (strcmp(ft_info.Description + 15, "8580") == 0)
            return SID_TYPE_8580;
    }
    // always return NONE if unknowns
        return SID_TYPE_NONE;
}
- (BOOL)initUSBSettingsForDevice
{
    BOOL returnValue = NO;
    if ([self openDevice]) {
        returnValue = (FT_SUCCESS(ft_status = FT_SetBaudRate(ft_handle, FT_BAUD_RATE)));
        returnValue &= (FT_SUCCESS(ft_status = FT_SetDataCharacteristics(ft_handle, FT_WORD_LENGTH, FT_STOP_BITS_1, FT_PARITY_NONE)));
        returnValue &= (FT_SUCCESS(ft_status = FT_SetFlowControl(ft_handle, FT_FLOW_NONE, 0, 0)));
        returnValue &= (FT_SUCCESS(ft_status = FT_SetTimeouts(ft_handle, FT_DEVICE_TIMEOUT_MS, FT_DEVICE_TIMEOUT_MS)));
        returnValue &= (FT_SUCCESS(ft_status = FT_SetLatencyTimer(ft_handle, FT_LATENCY_MS)));
        returnValue &= (FT_SUCCESS(ft_status = FT_SetBreakOff(ft_handle)));
    }
    if (returnValue)
        [self resetWithVolume:0x0f]; // reset the sid after USB params are set
    return returnValue;
}
- (void)closeDevice
{
  if (ft_handle) {
    if (FT_SUCCESS(ft_status = FT_Close(ft_handle)))
      ft_info.Flags &= ~FT_FLAGS_OPENED;
    ft_handle = NULL;
    ft_status = FT_DEVICE_NOT_OPENED;
  }
}
- (BOOL)openDevice
{
    [self closeDevice];
    BOOL retValue = NO;
    ft_status = FT_OpenEx(ft_info.SerialNumber, FT_OPEN_BY_SERIAL_NUMBER, &ft_handle);
    if (FT_SUCCESS(ft_status)){
        retValue = YES;
        ft_info.Flags |= FT_FLAGS_OPENED;
    }
    return retValue;
}
@end
#pragma mark time & delay
inline static void delayCommandWithCycles(long cycles)
{
    uint64_t now;
    float delayInNanos = cycles / ONE_MHZ_CYCLES_PER_MICRO * NANOS_PER_USEC;
    uint64_t delayInCpuAbs = TimeInNanosToCpuAbs(delayInNanos);
    sumOfDelayCyclesInCpuAbs += delayInCpuAbs;
    if (timeOfFirstSidAccess == 0)
        timeOfFirstSidAccess = mach_absolute_time();

    uint64_t targetTimeInCpuAbs = timeOfFirstSidAccess + sumOfDelayCyclesInCpuAbs;
    now = mach_absolute_time();
    
    
    if (now < targetTimeInCpuAbs-thresholdToWaitInAbs) {
        mach_wait_until(targetTimeInCpuAbs - thresholdToWaitInAbs);
    }
    while (mach_absolute_time() < (targetTimeInCpuAbs)) {}
    //NSLog (@"now: %llu, target: %llu diff %lld",now,targetTimeInCpuAbs,targetTimeInCpuAbs-now);
    //NSLog (@"cylcles: %ld, nanos %f, cpuTime %lld",cycles,delayInNanos,  delayInCpuAbs);
}

