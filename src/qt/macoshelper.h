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

#ifndef MACOSHELPER_H
#define MACOSHELPER_H

#include <QPixmap>
#include <QImage>
#include <QStringList>
#include <functional>

class QWindow;

class MacOSHelper
{
    MacOSHelper() {}

public:
    static bool isCapsLock();
    static bool openFolderAndSelectItem(const QUrl &path);
    static QString bundlePath();
    static void disableWindowTabbing();
    static bool notify(const QString &title, const QString &message);
    // menu bar (status bar) item: icon + title; its menu lists `lines` ("" = separator) and an
    // item that brings the app to the front. visible = false removes it
    static void setStatusItem(bool visible, const QString &title, const QStringList &lines,
                              const QString &openLabel, const QImage &icon, std::function<void()> onOpen);
    // put a window on the wallpaper: above the desktop icons, below every other window, on all Spaces
    static void pinToDesktop(QWindow *window);
};

#endif //MACOSHELPER_H
