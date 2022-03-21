#import <Cocoa/Cocoa.h>

@class AsyncSocket;
@class SPSourceListDataSource;


@interface HTTPServer : NSObject <NSNetServiceDelegate>
{
	// Underlying asynchronous TCP/IP socket
	AsyncSocket *asyncSocket;
	
	// Standard delegate
	id delegate;
	
	// HTTP server configuration
	NSURL *documentRoot;
	Class connectionClass;
	
	// NSNetService and related variables
	NSNetService *netService;
    NSString *domain;
	NSString *type;
    NSString *name;
	UInt16 port;
	NSDictionary *txtRecordDictionary;
	
	SPSourceListDataSource* sourceListDataSource;

	NSMutableArray *connections;
}

- (id)delegate;
- (void)setDelegate:(id)newDelegate;

- (NSURL *)documentRoot;
- (void)setDocumentRoot:(NSURL *)value;

- (Class)connectionClass;
- (void)setConnectionClass:(Class)value;

- (NSString *)domain;
- (void)setDomain:(NSString *)value;

- (NSString *)type;
- (void)setType:(NSString *)value;

- (NSString *)name;
- (void)setName:(NSString *)value;

- (UInt16)port;
- (void)setPort:(UInt16)value;

- (NSNetService*) netService;

- (SPSourceListDataSource*) sourceListDataSource;
- (void)setSourceListDataSource:(SPSourceListDataSource*)dataSource;

- (NSDictionary *)TXTRecordDictionary;
- (void)setTXTRecordDictionary:(NSDictionary *)dict;

- (BOOL)start:(NSError **)error;
- (BOOL)stop;

- (int)numberOfHTTPConnections;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface HTTPConnection : NSObject
{
	AsyncSocket *asyncSocket;
	HTTPServer *server;
	
	CFHTTPMessageRef request;
	
	NSString *nonce;
	int lastNC;
}

- (id)initWithAsyncSocket:(AsyncSocket *)newSocket forServer:(HTTPServer *)myServer;

- (BOOL)isSecureServer;

- (NSArray *)sslIdentityAndCertificates;

- (BOOL)isPasswordProtected:(NSString *)path;

- (NSString *)realm;
- (NSString *)passwordForUser:(NSString *)username;

- (NSData *)dataForURI:(NSString *)path;

@end
