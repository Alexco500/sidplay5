/* watches for USB devices attach/detach events */

#import "USBDeviceWatcher.h"

#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>

@interface USBDeviceWatcher ()

@property IONotificationPortRef notifyPort;
@property NSMutableArray<NSNumber *> *iterators;
@property NSArray<NSDictionary *> *devices;
@property USBDeviceEventHandler handler;

@end

@implementation USBDeviceWatcher

static void USBWatcherHandleIterator(USBDeviceWatcher *watcher,
                                     io_iterator_t iterator,
                                     USBDeviceEvent event)
{
    io_service_t service;

    while ((service = IOIteratorNext(iterator))) {
        NSNumber *vidNum = CFBridgingRelease(IORegistryEntryCreateCFProperty(
            service,
            CFSTR(kUSBVendorID),
            kCFAllocatorDefault,
            0
        ));

        NSNumber *pidNum = CFBridgingRelease(IORegistryEntryCreateCFProperty(
            service,
            CFSTR(kUSBProductID),
            kCFAllocatorDefault,
            0
        ));

        if (watcher.handler && vidNum && pidNum) {
            watcher.handler(event,
                            vidNum.unsignedShortValue,
                            pidNum.unsignedShortValue);
        }

        IOObjectRelease(service);
    }
}

static void USBDeviceAttached(void *refCon, io_iterator_t iterator)
{
    USBDeviceWatcher *watcher = (__bridge USBDeviceWatcher *)refCon;
    USBWatcherHandleIterator(watcher, iterator, USBDeviceEventAttached);
}

static void USBDeviceDetached(void *refCon, io_iterator_t iterator)
{
    USBDeviceWatcher *watcher = (__bridge USBDeviceWatcher *)refCon;
    USBWatcherHandleIterator(watcher, iterator, USBDeviceEventDetached);
}

- (instancetype)initWithDevices:(NSArray<NSDictionary *> *)devices
                        handler:(USBDeviceEventHandler)handler
{
    self = [super init];
    if (!self) {
        return nil;
    }

    _devices = devices;
    _handler = [handler copy];
    _iterators = [NSMutableArray array];

    _notifyPort = IONotificationPortCreate(kIOMainPortDefault);
    if (!_notifyPort) {
        return self;
    }

    CFRunLoopSourceRef source = IONotificationPortGetRunLoopSource(_notifyPort);

    CFRunLoopAddSource(CFRunLoopGetMain(),
                       source,
                       kCFRunLoopDefaultMode);

    for (NSDictionary *device in devices) {
        NSNumber *vidObject = device[@"vid"];
        NSNumber *pidObject = device[@"pid"];

        if (!vidObject || !pidObject) {
            continue;
        }

        uint16_t vid = vidObject.unsignedShortValue;
        uint16_t pid = pidObject.unsignedShortValue;

        [self addNotificationForVendorId:vid
                                productId:pid
                         notificationType:kIOMatchedNotification
                                  callback:USBDeviceAttached];

        [self addNotificationForVendorId:vid
                                productId:pid
                         notificationType:kIOTerminatedNotification
                                  callback:USBDeviceDetached];
    }

    return self;
}

- (void)addNotificationForVendorId:(uint16_t)vendorId
                         productId:(uint16_t)productId
                  notificationType:(const io_name_t)notificationType
                           callback:(IOServiceMatchingCallback)callback
{
    CFMutableDictionaryRef matchingDict =
        IOServiceMatching(kIOUSBDeviceClassName);

    if (!matchingDict) {
        return;
    }

    CFNumberRef vidNumber = CFNumberCreate(kCFAllocatorDefault,
                                           kCFNumberSInt16Type,
                                           &vendorId);

    CFNumberRef pidNumber = CFNumberCreate(kCFAllocatorDefault,
                                           kCFNumberSInt16Type,
                                           &productId);

    if (!vidNumber || !pidNumber) {
        if (vidNumber) CFRelease(vidNumber);
        if (pidNumber) CFRelease(pidNumber);
        CFRelease(matchingDict);
        return;
    }

    CFDictionarySetValue(matchingDict,
                         CFSTR(kUSBVendorID),
                         vidNumber);

    CFDictionarySetValue(matchingDict,
                         CFSTR(kUSBProductID),
                         pidNumber);

    CFRelease(vidNumber);
    CFRelease(pidNumber);

    io_iterator_t iterator = 0;

    kern_return_t kr = IOServiceAddMatchingNotification(
        self.notifyPort,
        notificationType,
        matchingDict,
        callback,
        (__bridge void *)self,
        &iterator
    );

    if (kr != KERN_SUCCESS) {
        return;
    }

    /*
     Wichtig:
     Der Iterator muss einmal geleert werden, damit spätere Notifications
     ausgelöst werden. Bei kIOMatchedNotification kommen dadurch auch bereits
     angeschlossene Geräte sofort als "attached".
     */
    callback((__bridge void *)self, iterator);

    [self.iterators addObject:@(iterator)];
}

- (void)dealloc
{
    for (NSNumber *iteratorNumber in self.iterators) {
        IOObjectRelease((io_iterator_t)iteratorNumber.unsignedIntValue);
    }

    if (_notifyPort) {
        CFRunLoopSourceRef source =
            IONotificationPortGetRunLoopSource(_notifyPort);

        if (source) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                                  source,
                                  kCFRunLoopDefaultMode);
        }

        IONotificationPortDestroy(_notifyPort);
        _notifyPort = NULL;
    }
}

@end
