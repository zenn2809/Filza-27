@import Foundation;

#import "WebDAVPathResolver.h"

static NSString *gLastInput;
static NSString *gLastResolvedPath;
static NSString *gLastError;
static NSString * const kFilzaWebDAVResolverErrorDomain = @"FilzaWebDAVPathResolver";

static void Record(NSString *input, NSString *resolved, NSString *error)
{
    @synchronized ([NSNull null]) {
        gLastInput = [input copy];
        gLastResolvedPath = [resolved copy];
        gLastError = [error copy];
    }
}

NSString *FilzaWebDAVLastResolverInput(void) { @synchronized ([NSNull null]) { return gLastInput; } }
NSString *FilzaWebDAVLastResolvedPath(void) { @synchronized ([NSNull null]) { return gLastResolvedPath; } }
NSString *FilzaWebDAVLastResolverError(void) { @synchronized ([NSNull null]) { return gLastError; } }

static NSString *Canonical(NSString *path)
{
    NSString *standard = path.stringByStandardizingPath;
    if ([standard isEqualToString:@"/var"] || [standard hasPrefix:@"/var/"])
        standard = [@"/private" stringByAppendingString:standard];
    return standard.stringByResolvingSymlinksInPath.stringByStandardizingPath;
}

static BOOL IsInside(NSString *path, NSString *root)
{
    return [path isEqualToString:root] || [path hasPrefix:[root stringByAppendingString:@"/"]];
}

static NSString *Fail(NSString *input, NSError **error, NSString *reason)
{
    Record(input, nil, reason);
    if (error) *error = [NSError errorWithDomain:kFilzaWebDAVResolverErrorDomain
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey: reason}];
    return nil;
}

NSString *FilzaWebDAVResolvePath(NSString *requestPath, NSString *uploadDirectory,
                                 FilzaWebDAVPathAuthorization authorization, NSError **error)
{
    if (!requestPath.length || !uploadDirectory.length || !authorization)
        return Fail(requestPath, error, @"missing WebDAV path, root, or authorization callback");

    // GCDWebServer normally exposes an already-decoded request.path.  Decode
    // once as well for Destination and clients that pass the raw URL path.
    NSString *decoded = [requestPath stringByRemovingPercentEncoding];
    if (!decoded) return Fail(requestPath, error, @"invalid percent escape in WebDAV path");
    if ([decoded containsString:@"\\"] || [decoded rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound)
        return Fail(requestPath, error, @"invalid path separator or control character");

    BOOL trailingSlash = decoded.length > 1 && [decoded hasSuffix:@"/"];
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *part in [decoded componentsSeparatedByString:@"/"]) {
        if (!part.length) continue;                 // safely fold repeated slashes
        if ([part isEqualToString:@"."] || [part isEqualToString:@".."])
            return Fail(requestPath, error, @"path traversal is not permitted");
        [parts addObject:part];
    }
    NSString *normalized = [@"/" stringByAppendingString:[parts componentsJoinedByString:@"/"]];
    if (trailingSlash && ![normalized hasSuffix:@"/"]) normalized = [normalized stringByAppendingString:@"/"];

    BOOL absoluteIOS = [normalized isEqualToString:@"/var/mobile"] ||
                       [normalized hasPrefix:@"/var/mobile/"] ||
                       [normalized isEqualToString:@"/private/var/mobile"] ||
                       [normalized hasPrefix:@"/private/var/mobile/"];
    NSString *candidate = nil;
    if ([normalized isEqualToString:@"/var/mobile"] || [normalized hasPrefix:@"/var/mobile/"])
        candidate = [@"/private" stringByAppendingString:normalized];
    else if ([normalized isEqualToString:@"/private/var/mobile"] || [normalized hasPrefix:@"/private/var/mobile/"])
        candidate = normalized; // never make /private/private
    else if (absoluteIOS)
        return Fail(requestPath, error, @"unsupported absolute iOS path");
    else {
        // All other paths retain legacy WebDAV-relative semantics.
        candidate = [uploadDirectory stringByAppendingPathComponent:[normalized substringFromIndex:1]];
    }

    NSString *root = Canonical(uploadDirectory);
    NSString *canonical = Canonical(candidate);
    if (trailingSlash && ![canonical isEqualToString:@"/"] && ![canonical hasSuffix:@"/"])
        canonical = [canonical stringByAppendingString:@"/"];
    NSString *comparisonPath = [canonical hasSuffix:@"/"] && canonical.length > 1 ? [canonical substringToIndex:canonical.length - 1] : canonical;
    if (!absoluteIOS && !IsInside(comparisonPath, root))
        return Fail(requestPath, error, @"relative WebDAV path escapes its configured root");
    if (!authorization(comparisonPath))
        return Fail(requestPath, error, @"MCM/sandbox access is not active for this path");

    Record(requestPath, canonical, nil);
    return canonical;
}
