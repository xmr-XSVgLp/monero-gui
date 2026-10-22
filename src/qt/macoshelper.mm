// Copyright (c) 2014-2024, The Monero Project
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are
// permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of
//    conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice, this list
//    of conditions and the following disclaimer in the documentation and/or other
//    materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors may be
//    used to endorse or promote products derived from this software without specific
//    prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
// THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include <unordered_set>

#include <QtCore>
#include <QtGui>
#include <QWindow>
#include "macoshelper.h"

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <UserNotifications/UserNotifications.h>
#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>
#include <Availability.h>

#include "ScopeGuard.h"

// Shows our notifications even while the app is in front (macOS hides them by default).
@interface WalletNotificationDelegate : NSObject <UNUserNotificationCenterDelegate>
@end

@implementation WalletNotificationDelegate
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
      willPresentNotification:(UNNotification *)notification
        withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
    Q_UNUSED(center);
    Q_UNUSED(notification);
    completionHandler(UNNotificationPresentationOptionBanner |
                      UNNotificationPresentationOptionList |
                      UNNotificationPresentationOptionSound);
}
@end

void MacOSHelper::disableWindowTabbing()
{
#ifdef __MAC_10_12
    if ([NSWindow respondsToSelector:@selector(allowsAutomaticWindowTabbing)])
        [NSWindow setAllowsAutomaticWindowTabbing: NO];
#endif
}

bool MacOSHelper::isCapsLock()
{
#ifdef __MAC_10_12
    NSUInteger flags = [NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
    return (flags == NSEventModifierFlagCapsLock);
#else
    NSUInteger flags = [NSEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
    return (flags & NSAlphaShiftKeyMask);
#endif
}

bool MacOSHelper::openFolderAndSelectItem(const QUrl &path)
{
    NSURL *nspath = path.toNSURL();
    NSArray *fileURLs = [NSArray arrayWithObjects:nspath, nil];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
    return true;
}

QString MacOSHelper::bundlePath()
{
    NSBundle *main = [NSBundle mainBundle];
    if (!main)
    {
        return {};
    }
    NSString *bundlePathString = [main bundlePath];
    if (!bundlePathString)
    {
        return {};
    }
    return QString::fromNSString(bundlePathString);
}

// Native notification, posted by the app itself so macOS shows the app icon
// (osascript notifications carry the Script Editor icon). Returns false when the
// app runs outside a bundle, where macOS refuses to post them.
bool MacOSHelper::notify(const QString &title, const QString &message)
{
    if (![[NSBundle mainBundle] bundleIdentifier])
        return false;
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    static WalletNotificationDelegate *delegate = [[WalletNotificationDelegate alloc] init];
    center.delegate = delegate;
    UNMutableNotificationContent *note = [[UNMutableNotificationContent alloc] init];
    note.title = title.toNSString();
    note.body = message.toNSString();
    note.sound = [UNNotificationSound defaultSound];
    UNNotificationRequest *request = [UNNotificationRequest
        requestWithIdentifier:[[NSUUID UUID] UUIDString] content:note trigger:nil];
    [note release];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                         completionHandler:^(BOOL granted, NSError *error) {
        if (granted && !error) {
            [center addNotificationRequest:request withCompletionHandler:^(NSError *deliveryError) {
                if (deliveryError)
                    qWarning() << "Could not schedule macOS notification:" << deliveryError.code;
            }];
        }
    }];
    return true; // Queued; macOS delivers only if the user permits notifications.
}

// ---- menu bar item ----
static NSStatusItem *g_statusItem = nil;
static std::function<void()> g_statusOpen;

@interface WalletStatusTarget : NSObject
- (void)openApp:(id)sender;
@end

@implementation WalletStatusTarget
- (void)openApp:(id)sender
{
    Q_UNUSED(sender);
    [NSApp activateIgnoringOtherApps:YES];
    if (g_statusOpen)
        g_statusOpen();
}
@end

void MacOSHelper::setStatusItem(bool visible, const QString &title, const QStringList &lines,
                                const QString &openLabel, const QImage &icon, std::function<void()> onOpen)
{
    static WalletStatusTarget *target = [[WalletStatusTarget alloc] init];
    if (!visible)
    {
        if (g_statusItem)
        {
            [[NSStatusBar systemStatusBar] removeStatusItem:g_statusItem];
            [g_statusItem release];
            g_statusItem = nil;
        }
        return;
    }
    g_statusOpen = std::move(onOpen);
    if (!g_statusItem)
    {
        g_statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
        if (!icon.isNull())
        {
            CGImageRef cg = icon.toCGImage();
            NSImage *image = [[NSImage alloc] initWithCGImage:cg size:NSMakeSize(18, 18)];
            CGImageRelease(cg);
            [image setTemplate:YES];   // black/white following the menu bar
            g_statusItem.button.image = image;
            [image release];
        }
        g_statusItem.button.imagePosition = NSImageLeft;
        g_statusItem.button.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
    }
    g_statusItem.button.title = title.isEmpty() ? @"" : [@" " stringByAppendingString:title.toNSString()];

    NSMenu *menu = [[NSMenu alloc] init];
    [menu setAutoenablesItems:NO];
    for (const QString &line : lines)
    {
        if (line.isEmpty())
        {
            [menu addItem:[NSMenuItem separatorItem]];
            continue;
        }
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:line.toNSString() action:nil keyEquivalent:@""];
        [item setEnabled:YES];
        [menu addItem:item];
        [item release];
    }
    if (!lines.isEmpty())
        [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *open = [[NSMenuItem alloc] initWithTitle:openLabel.toNSString() action:@selector(openApp:) keyEquivalent:@""];
    open.target = target;
    [open setEnabled:YES];
    [menu addItem:open];
    [open release];
    g_statusItem.menu = menu;
    [menu release];
}

void MacOSHelper::pinToDesktop(QWindow *window)
{
    if (!window)
        return;
    NSView *view = reinterpret_cast<NSView *>(window->winId());
    NSWindow *w = [view window];
    if (!w)
        return;
    [w setLevel:CGWindowLevelForKey(kCGDesktopIconWindowLevelKey) + 1];
    [w setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces
                             | NSWindowCollectionBehaviorStationary
                             | NSWindowCollectionBehaviorIgnoresCycle];
    [w setHidesOnDeactivate:NO];
    [w setHasShadow:NO];
}
