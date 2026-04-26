
/* watches for USB devices attach/detach events */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, USBDeviceEvent) {
    USBDeviceEventAttached,
    USBDeviceEventDetached
};

typedef void (^USBDeviceEventHandler)(USBDeviceEvent event,
                                      uint16_t vendorId,
                                      uint16_t productId);

@interface USBDeviceWatcher : NSObject

- (instancetype)initWithDevices:(NSArray<NSDictionary *> *)devices
                        handler:(USBDeviceEventHandler)handler;

@end

NS_ASSUME_NONNULL_END

