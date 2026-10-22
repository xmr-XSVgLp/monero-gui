#import <LocalAuthentication/LocalAuthentication.h>
#include <Security/Security.h>

namespace NymAccountStore {
// Only for detecting legacy accounts; never request authentication during a status check.
void disableAuthenticationUI(CFMutableDictionaryRef query)
{
    LAContext *context = [[LAContext alloc] init];
    context.interactionNotAllowed = YES;
    CFDictionarySetValue(query, kSecUseAuthenticationContext, context);
    [context release];
}
}
