#import "IONAssetHandler.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "CDVWKWebViewEngine.h"

@implementation IONAssetHandler

-(void)setAssetPath:(NSString *)assetPath {
    self.basePath = assetPath;
}

- (instancetype)initWithBasePath:(NSString *)basePath andScheme:(NSString *)scheme {
    self = [super init];
    if (self) {
        _basePath = basePath;
        _scheme = scheme;
    }
    return self;
}

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
    Boolean loadFile = true;
    NSString * startPath = @"";
    NSURL * url = urlSchemeTask.request.URL;
    NSDictionary * header = urlSchemeTask.request.allHTTPHeaderFields;
    NSMutableString * stringToLoad = [NSMutableString string];
    [stringToLoad appendString:url.path];
    if(url.query) {
        [stringToLoad appendString:@"?"];
        [stringToLoad appendString:url.query];
    }
    NSString * scheme = url.scheme;
    NSString * method = urlSchemeTask.request.HTTPMethod;
    NSData * body = urlSchemeTask.request.HTTPBody;
    NSData * data;
    NSInteger statusCode;

    if ([scheme isEqualToString:self.scheme]) {
        if ([stringToLoad hasPrefix:@"/_app_file_"]) {
            startPath = [stringToLoad stringByReplacingOccurrencesOfString:@"/_app_file_" withString:@""];
        } else if ([stringToLoad hasPrefix:@"/_http_proxy_"]||[stringToLoad hasPrefix:@"/_https_proxy_"]) {
            loadFile = false;
            startPath = [stringToLoad stringByReplacingOccurrencesOfString:@"/_http_proxy_" withString:@"http://"];
            //startPath = [stringToLoad stringByReplacingOccurrencesOfString:@"/_https_proxy_" withString:@"https://"];
            NSLog(@"Proxy %@", startPath);
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
            [request setHTTPMethod:method];
            [request setURL:[NSURL URLWithString:startPath]];
            if (body) {
                [request setHTTPBody:body];
            }
            [request setAllHTTPHeaderFields:header];
            //[request setAllHTTPHeaderFields:[NSHTTPCookie requestHeaderFieldsWithCookies:[NSHTTPCookieStorage sharedHTTPCookieStorage].cookies]];
            [request setHTTPShouldHandleCookies:YES];
            
            [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if(error) {
                    NSLog(@"Proxy error: %@", error);
                }
                
                [urlSchemeTask didReceiveResponse:response];
                [urlSchemeTask didReceiveData:data];
                [urlSchemeTask didFinish];
            }] resume];
        } else {
            startPath = self.basePath;
            if ([stringToLoad isEqualToString:@""] || [url.pathExtension isEqualToString:@""]) {
                startPath = [startPath stringByAppendingString:@"/index.html"];
            } else {
                startPath = [startPath stringByAppendingString:stringToLoad];
            }
        }
    }

    if(loadFile) {
        data = [[NSData alloc] initWithContentsOfFile:startPath];
        statusCode = 200;
        if (!data) {
            statusCode = 404;
        }
        NSURL * localUrl = [NSURL URLWithString:url.absoluteString];
        NSString * mimeType = [self getMimeType:url.pathExtension];
        id response = nil;
        if (data && [self isMediaExtension:url.pathExtension]) {
            response = [[NSURLResponse alloc] initWithURL:localUrl MIMEType:mimeType expectedContentLength:data.length textEncodingName:nil];
        } else {
            NSDictionary * headers = @{ @"Content-Type" : mimeType, @"Cache-Control": @"no-cache"};
            response = [[NSHTTPURLResponse alloc] initWithURL:localUrl statusCode:statusCode HTTPVersion:nil headerFields:headers];
        }
        
        [urlSchemeTask didReceiveResponse:response];
        [urlSchemeTask didReceiveData:data];
        [urlSchemeTask didFinish];
    }
}

- (void)webView:(nonnull WKWebView *)webView stopURLSchemeTask:(nonnull id<WKURLSchemeTask>)urlSchemeTask
{
    NSLog(@"stop");
}

-(NSString *) getMimeType:(NSString *)fileExtension {
    if (fileExtension && ![fileExtension isEqualToString:@""]) {
        NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtension, NULL);
        NSString *contentType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);
        return contentType ? contentType : @"application/octet-stream";
    } else {
        return @"text/html";
    }
}

-(BOOL) isMediaExtension:(NSString *) pathExtension {
    NSArray * mediaExtensions = @[@"m4v", @"mov", @"mp4",
                           @"aac", @"ac3", @"aiff", @"au", @"flac", @"m4a", @"mp3", @"wav"];
    if ([mediaExtensions containsObject:pathExtension.lowercaseString]) {
        return YES;
    }
    return NO;
}


@end
