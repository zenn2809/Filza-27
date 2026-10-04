#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^FilzaWebDAVPathAuthorization)(NSString *canonicalPath);

// Resolves a WebDAV URL path without conflating URL syntax with filesystem
// authority.  The authorization callback receives the canonical filesystem
// path only after traversal and symlink-escape checks have succeeded.
FOUNDATION_EXPORT NSString *_Nullable FilzaWebDAVResolvePath(
    NSString *requestPath,
    NSString *uploadDirectory,
    FilzaWebDAVPathAuthorization authorization,
    NSError *_Nullable *_Nullable error);

FOUNDATION_EXPORT NSString *_Nullable FilzaWebDAVLastResolverInput(void);
FOUNDATION_EXPORT NSString *_Nullable FilzaWebDAVLastResolvedPath(void);
FOUNDATION_EXPORT NSString *_Nullable FilzaWebDAVLastResolverError(void);

NS_ASSUME_NONNULL_END
