/*
    This software is distributed under the terms of Pete's Public License version 1.0, a
    copy of which is included with this software in the file "License.html".  A copy can
    also be obtained from http://pete.yandell.com/software/license/ppl-1_0.html
    
    If you did not receive a copy of the license with this software, please notify the
    author by sending e-mail to pete@yandell.com
    
    The current version of this software can be found at http://pete.yandell.com/software
     
    Copyright (c) 2002-2004 Peter Yandell.  All Rights Reserved.
    
    $Id: PYMIDIEndpoint.m 137 2008-11-30 14:28:22Z tk $
*/


#import "PYMIDI/PYMIDIEndpoint.h"

#import <PYMIDI/PYMIDIUtils.h>
#import <PYMIDI/PYMIDIManager.h>
#import <PYMIDI/PYMIDIEndpointDescriptor.h>


@interface PYMIDIEndpoint (private)

- (void)setUniqueIDFromMIDIEndpoint;
- (void)setNameFromMIDIEndpoint;
- (void)setDisplayNameFromMIDIEndpoint;

- (void)startOrStopIO;

@end


@implementation PYMIDIEndpoint



#pragma mark INITIALISATION


- (id)init
{
    receivers       = [[NSMutableSet alloc] init];
    senders         = [[NSMutableSet alloc] init];
    // midiControllers = [[NSMutableSet alloc] init];
    
    return self;
}


- (id)initWithName:(NSString*)newName uniqueID:(SInt32)newUniqueID
{
    self = [self init];
    
    name = newName;
    uniqueID = newUniqueID;
    
    return self;
}


- (id)initWithMIDIEndpointRef:(MIDIEndpointRef)newMIDIEndpointRef;
{
    self = [self init];
    
    midiEndpointRef = newMIDIEndpointRef;
    [self setPropertiesFromMIDIEndpoint];
    
    return self;
}


- (void)dealloc
{}



#pragma mark ARCHIVING


- (id)initWithCoder:(NSCoder*)coder
{
    return self;
}


- (void)encodeWithCoder:(NSCoder*)coder
{
    [coder encodeObject:name forKey:@"name"];
    [coder encodeInt32:uniqueID forKey:@"uniqueID"];
    [coder encodeObject:displayName forKey:@"displayName"];
}


- (PYMIDIEndpointDescriptor*)descriptor
{
    return [PYMIDIEndpointDescriptor descriptorWithName:name uniqueID:uniqueID];
}



#pragma mark PROPERTIES


- (void)setPropertiesFromMIDIEndpoint
{
    if (midiEndpointRef == NULL) return;
    
    [self setUniqueIDFromMIDIEndpoint];
    [self setNameFromMIDIEndpoint];
    [self setDisplayNameFromMIDIEndpoint];
}


- (void)setUniqueIDFromMIDIEndpoint
{
    MIDIObjectGetIntegerProperty (midiEndpointRef, kMIDIPropertyUniqueID, &uniqueID);
}


- (void)setNameFromMIDIEndpoint
{
    name = PYMIDIGetEndpointName (midiEndpointRef);
}


- (void)setDisplayNameFromMIDIEndpoint
{
    CFDataRef externalIDs;
    OSStatus result;

    NSMutableArray* names = [NSMutableArray arrayWithCapacity:0];
        
    // Pull in a list of external devices connected to our endpoint
    result = MIDIObjectGetDataProperty (
        midiEndpointRef, kMIDIPropertyConnectionUniqueID, &externalIDs
    );

    // If we do have external devices, grab all their names and glue them together
    if (result == noErr) {
        int i;
        for (i = 0; i < CFDataGetLength (externalIDs); i += 4) {
            SInt32 externalID;
            CFDataGetBytes (externalIDs, CFRangeMake (i, 4), (UInt8*)&externalID);
			externalID = ntohl(externalID);
            
            if (externalID != 0) {
                MIDIObjectRef externalDevice;
                MIDIObjectType deviceType;
                
                result = MIDIObjectFindByUniqueID (externalID, &externalDevice, &deviceType);
                
                switch (deviceType) {
                case kMIDIObjectType_ExternalSource:
                case kMIDIObjectType_ExternalDestination:
                    // On 10.3 and later we should get here
                    [names addObject:PYMIDIGetEndpointName (externalDevice)];
                    break;
                    
                case kMIDIObjectType_ExternalDevice:
                    // On 10.2 we should get here
                    {
                        CFStringRef externalName;
                        result = MIDIObjectGetStringProperty (externalDevice, kMIDIPropertyName, &externalName);
                        if (result == noErr) {
                            [names addObject:[NSString stringWithString:(__bridge NSString*)externalName]];
                            CFRelease (externalName);
                        }
                    }
                    break;
                    
                default:
                    // In theory we shouldn't ever get here!
                    break;
                }
            }
        }

        CFRelease (externalIDs);
    }
    
    
    // Generate the display name from the info we've gathered
    if ([names count] > 0)
        displayName = [names componentsJoinedByString:@", "];
    else {
        if (name != nil)
            displayName = name;
        else
            displayName = @"UNKNOWN DEVICE";
    }
}


- (NSString*)name
{
    return name;
}


- (BOOL)setName:(NSString*)newName
{	
    PYMIDIManager* manager = [PYMIDIManager sharedInstance];
    OSStatus result;
    
    [manager disableNotifications];
    
    result = MIDIObjectSetStringProperty (midiEndpointRef, kMIDIPropertyName, (__bridge CFStringRef)newName);

    [manager enableNotifications];
    
    if (result == noErr) {
        name = newName;
        displayName = newName;
        return YES;
    }
    else
        return NO;
}


- (NSString*)displayName
{
    if ([self isOffline])
        return [NSString stringWithFormat:@"%@ (offline)", displayName];
    else
        return displayName;
}


- (NSComparisonResult)compareByDisplayName:(PYMIDIEndpoint*)endpoint
{
    return [[self displayName] caseInsensitiveCompare:[endpoint displayName]];
}


- (SInt32)uniqueID
{
    return uniqueID;
}


- (BOOL)setUniqueID:(SInt32)newUniqueID
{
    PYMIDIManager* manager = [PYMIDIManager sharedInstance];
    OSStatus result;
    
    [manager disableNotifications];
    
    result = MIDIObjectSetIntegerProperty (midiEndpointRef, kMIDIPropertyUniqueID, newUniqueID);
    
    [manager enableNotifications];
    
    if (result == noErr) {
        uniqueID = newUniqueID;
        return YES;
    }
    else
        return NO;
}


- (MIDIEndpointRef)midiEndpointRef
{
    return midiEndpointRef;
}


- (BOOL)isIACBus
{
    // Get the driver name
    CFStringRef driverName = nil;

    MIDIEntityRef entityRef;
    OSStatus result = MIDIEndpointGetEntity (midiEndpointRef, &entityRef);
    if (result == noErr) {    
        MIDIDeviceRef deviceRef;
        result = MIDIEntityGetDevice (entityRef, &deviceRef);
        
        if (result == noErr) {
            result = MIDIObjectGetStringProperty (deviceRef, kMIDIPropertyDriverOwner, &driverName);
        }
    }

    BOOL isIACBus = 
        driverName != nil &&
        [@"com.apple.AppleMIDIIACDriver" isEqualToString:(__bridge NSString*)driverName];
        
    if (driverName != nil) CFRelease (driverName);
    
    return isIACBus;
}


- (BOOL)isOnline
{
    return ![self isOffline];
}


- (BOOL)isOffline
{
    SInt32 isOffline;
    OSStatus result;

    if (midiEndpointRef == nil) return YES;
    
    result = MIDIObjectGetIntegerProperty (midiEndpointRef, kMIDIPropertyOffline, &isOffline);
    return result == noErr && isOffline;
}


- (BOOL)isInUse
{
    return [senders count] > 0 || [receivers count] > 0;
    //|| [midiControllers count] > 0;
}


- (BOOL)isOnlineOrInUse
{
    return [self isOnline] || [self isInUse];
}



#pragma mark SENDING & RECEIVING


- (void)addReceiver:(id)receiver
{
    [receivers addObject:[NSValue valueWithNonretainedObject:receiver]];
    [self startOrStopIO];
}


- (void)removeReceiver:(id)receiver
{
    [receivers removeObject:[NSValue valueWithNonretainedObject:receiver]];
    [self startOrStopIO];
}


- (void)addSender:(id)sender
{
    [senders addObject:[NSValue valueWithNonretainedObject:sender]];
    [self startOrStopIO];
}


- (void)removeSender:(id)sender
{
    [senders removeObject:[NSValue valueWithNonretainedObject:sender]];
    [self startOrStopIO];
}


/*
- (void)connectToMIDIController:(AUMIDIControllerRef)controller
{
    [midiControllers addObject:[NSValue value:&controller withObjCType:@encode(AUMIDIControllerRef)]];
    if (midiEndpointRef != nil)
        AUMIDIControllerConnectSource (controller, midiEndpointRef);
}


- (void)disconnectFromMIDIController:(AUMIDIControllerRef)controller
{
    [midiControllers removeObject:[NSValue value:&controller withObjCType:@encode(AUMIDIControllerRef)]];
    if (midiEndpointRef != nil)
        AUMIDIControllerDisconnectSource (controller, midiEndpointRef);
}
*/


- (void)processMIDIPacketList:(const MIDIPacketList*)packetList sender:(id)sender
{
}



#pragma mark IO


- (void)startOrStopIO
{
    if ([senders count] > 0 || [receivers count] > 0)
        [self startIO];
    else
        [self stopIO];
}


- (BOOL)ioIsRunning
{
    return NO;
}


- (void)startIO
{
}


- (void)stopIO
{
}


@end
