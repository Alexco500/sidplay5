#import "SPBrowserItem.h"


extern NSString* SPHttpBrowserItemInfoDownloadedNotification;
extern NSString* SPHttpBrowserItemIndexDownloadedNotification;


@interface SPHttpBrowserItem : SPBrowserItem
{
    BOOL isValid;
    NSMutableData* downloadData;
    NSURLConnection* downloadConnection;
    NSMutableData* indexData;
    NSURLConnection* indexDownloadConnection;
}

- (instancetype) initWithURLString:(NSString*)urlString isFolder:(BOOL)folder forParent:(SPBrowserItem*)parentItem NS_DESIGNATED_INITIALIZER;
- (void) cancelDownload;
@property (NS_NONATOMIC_IOSONLY, getter=isValid, readonly) BOOL valid;

+ (void) fillArray:(NSMutableArray*)browserItems withIndexDataItems:(NSArray*)indexItems fromUrl:(NSString*)urlString andParent:(SPBrowserItem*)parentItem;
+ (void) fillArray:(NSMutableArray*)browserItems withSharedPlaylist:(SPPlaylist*)playlist fromUrl:(NSString*)urlString;

@end
