@import Foundation;

#import "WebDAVPathResolver.h"

static void Require(BOOL condition, NSString *message)
{
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSString *Resolve(NSString *path, BOOL *accepted)
{
    NSError *error = nil;
    NSString *result = FilzaWebDAVResolvePath(path, @"/private/var/mobile/Containers/Data/Application/ROOT/Documents",
        ^BOOL(NSString *candidate) { return YES; }, &error);
    if (accepted) *accepted = result != nil;
    return result;
}

int main(void)
{
    @autoreleasepool {
        BOOL accepted = NO;
        Require([[Resolve(@"/var/mobile/Containers/Data/Application/ABC/Documents/test.txt", &accepted)
                  isEqualToString:@"/private/var/mobile/Containers/Data/Application/ABC/Documents/test.txt"] && accepted,
                @"maps /var/mobile to canonical /private/var/mobile");
        Require([[Resolve(@"/private/var/mobile/Containers/Data/Application/ABC/Documents/test.txt", &accepted)
                  isEqualToString:@"/private/var/mobile/Containers/Data/Application/ABC/Documents/test.txt"] && accepted,
                @"does not duplicate /private");
        Require([[Resolve(@"/var/mobile/Containers/Data/Application/ABC/Documents/folder/", &accepted)
                  isEqualToString:@"/private/var/mobile/Containers/Data/Application/ABC/Documents/folder/"] && accepted,
                @"preserves trailing slash");
        Require([[Resolve(@"/var/mobile/Containers/Data/Application/ABC/Documents/My%20File.txt", &accepted)
                  lastPathComponent] isEqualToString:@"My File.txt"] && accepted,
                @"decodes spaces");
        Require([[Resolve(@"//var//mobile/Containers//Data/Application/ABC/Documents/naïve file.txt", &accepted)
                  lastPathComponent] isEqualToString:@"naïve file.txt"] && accepted,
                @"normalizes repeated slashes and preserves Unicode");
        for (NSString *attack in @[
            @"/var/mobile/Containers/Data/Application/ABC/Documents/../../../../etc/passwd",
            @"/private/var/mobile/../../etc/passwd",
            @"/var/mobile/Documents/%2e%2e/%2e%2e/etc/passwd",
            @"/var/mobile/Documents/%2E%2E%2Fetc/passwd",
            @"/var/mobile/Documents/..%2Fetc/passwd",
            @"/var/mobile/Documents\\..\\etc/passwd"
        ]) {
            (void)Resolve(attack, &accepted);
            Require(!accepted, [NSString stringWithFormat:@"rejects traversal %@", attack]);
        }
        NSError *accessError = nil;
        NSString *denied = FilzaWebDAVResolvePath(@"/var/mobile/Containers/Data/Application/ABC/Documents/nope.txt",
            @"/private/var/mobile/Containers/Data/Application/ROOT/Documents", ^BOOL(__unused NSString *path) { return NO; }, &accessError);
        Require(!denied && accessError != nil, @"rejects a canonical path without MCM/sandbox authority");
        NSLog(@"WebDAV path resolver tests passed");
    }
    return 0;
}
