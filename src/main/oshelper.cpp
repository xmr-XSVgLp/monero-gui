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

#include "oshelper.h"
#include "qt/ConnectionProbe.h"

#include <algorithm>
#include <unordered_set>
#include <cstdlib>
#include <cstdio>
#include <chrono>
#include <thread>

#include <QCoreApplication>
#include <QGuiApplication>
#include <QFileDialog>
#include <QScreen>
#include <QStandardPaths>
#include <QWindow>
#include <QDir>
#include <QDirIterator>
#include <QStorageInfo>
#include <QDebug>
#include <QDesktopServices>
#include <QProcess>
#include <QRegularExpression>
#include <QTimer>
#include <QFile>
#include <QFileInfo>
#include <QString>
#include <QUrl>
#include <QByteArray>
#include <QRandomGenerator>
#include <QThread>
#include <QDateTime>
#include <QElapsedTimer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkProxy>
#include <QSslSocket>
#include <QTcpSocket>
#ifdef Q_OS_MAC
#include <QEventLoop>
#include <QThread>
#include "qt/macoshelper.h"
#endif
#ifdef Q_OS_WIN
#include <shlobj.h>
#include <windows.h>
#endif
#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
#include "qt/utils.h"
#endif

#include "QR-Code-scanner/Decoder.h"
#include "qt/ScopeGuard.h"
#include "NetworkType.h"

namespace
{

QPixmap screenshot()
{
    std::unordered_set<QWindow *> hidden;
    const QWindowList windows = QGuiApplication::allWindows();
    for (QWindow *window : windows)
    {
        if (window->isVisible())
        {
            hidden.emplace(window);
            window->hide();
        }
    }

#if defined(Q_OS_MAC)
    // Let Qt submit the native hide operations before blocking the GUI thread.
    QGuiApplication::processEvents(QEventLoop::ExcludeUserInputEvents);
    // Give WindowServer time to finish removing the window.
    QThread::msleep(100);
#endif

    const auto unhide = sg::make_scope_guard([&hidden]() {
        for (QWindow *window : hidden)
        {
            window->show();
        }
    });

    return QGuiApplication::primaryScreen()->grabWindow(0);
}

} // namespace

#if defined(Q_OS_WIN)
bool openFolderAndSelectItem(const QString &filePath)
{
    struct scope {
        ~scope() { ::CoTaskMemFree(pidl); }
        PIDLIST_ABSOLUTE pidl = nullptr;
    } scope;

    SFGAOF flags;
    HRESULT result = ::SHParseDisplayName(filePath.toStdWString().c_str(), nullptr, &scope.pidl, 0, &flags);
    if (result != S_OK)
    {
        qWarning() << "SHParseDisplayName failed" << result << "file path" << filePath;
        return false;
    }

    result = ::SHOpenFolderAndSelectItems(scope.pidl, 0, nullptr, 0);
    if (result != S_OK)
    {
        qWarning() << "SHOpenFolderAndSelectItems failed" << result << "file path" << filePath;
        return false;
    }

    return true;
}
#endif

OSHelper::OSHelper(QObject *parent) : QObject(parent)
{

}

void OSHelper::createDesktopEntry() const
{
#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    registerXdgMime();
#endif
}

QString OSHelper::downloadLocation() const
{
    return QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
}

QList<QString> OSHelper::grabQrCodesFromScreen() const
{
    QList<QString> codes;

    try
    {
        const QImage image = screenshot().toImage();
        const std::vector<std::string> decoded = QrDecoder().decode(image);
        std::for_each(decoded.begin(), decoded.end(), [&codes](const std::string &code) {
            codes.push_back(QString::fromStdString(code));
        });
    }
    catch (const std::exception &e)
    {
        qWarning() << "QR screen capture: decoder exception:" << e.what();
    }

    return codes;
}

bool OSHelper::openFile(const QString &filePath) const
{
    QString canonicalFilePath = QFileInfo(filePath).canonicalFilePath();
    QUrl url = QUrl::fromLocalFile(canonicalFilePath);
    if (!url.isValid())
    {
        qWarning() << "Malformed file path" << canonicalFilePath << url.errorString();
        return false;
    }
    return QDesktopServices::openUrl(url);
}

bool OSHelper::openContainingFolder(const QString &filePath) const
{
    QString canonicalFilePath = QFileInfo(filePath).canonicalFilePath();
#if defined(Q_OS_WIN)
    if (openFolderAndSelectItem(QDir::toNativeSeparators(canonicalFilePath)))
    {
        return true;
    }
#elif defined(Q_OS_MAC)
    if (MacOSHelper::openFolderAndSelectItem(QUrl::fromLocalFile(canonicalFilePath)))
    {
        return true;
    }
#endif

    QUrl url = QUrl::fromLocalFile(QFileInfo(filePath).canonicalPath());
    if (!url.isValid())
    {
        qWarning() << "Malformed file path" << canonicalFilePath << url.errorString();
        return false;
    }
    return QDesktopServices::openUrl(url);
}

QString OSHelper::openSaveFileDialog(const QString &title, const QString &folder, const QString &filename) const
{
    const QString hint = (folder.isEmpty() ? "" : folder + QDir::separator()) + filename;
    return QFileDialog::getSaveFileName(nullptr, title, hint);
}

bool OSHelper::isCapsLock() const
{
#if defined(Q_OS_WIN)
    return (GetKeyState(VK_CAPITAL) & 0x0001) != 0;
#elif defined(Q_OS_MAC)
    return MacOSHelper::isCapsLock();
#else
    return false;
#endif
}

// Price history of the Swaps page: ~/Monero/xmr-wallet-plus/precios-swaps.csv
QString OSHelper::swapsLogPath() const
{
    return QDir::homePath() + "/Monero/xmr-wallet-plus/precios-swaps.csv";
}

// Appends lines to a CSV file, creating its folder and writing the header first when the file is new.
bool OSHelper::appendCsv(const QString &path, const QString &header, const QString &lines) const
{
    QFileInfo info(path);
    if (!QDir().mkpath(info.absolutePath()))
    {
        qWarning() << "appendCsv: cannot create" << info.absolutePath();
        return false;
    }
    const bool isNew = !info.exists() || info.size() == 0;
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text))
    {
        qWarning() << "appendCsv: cannot open" << path;
        return false;
    }
    if (isNew)
        file.write(header.toUtf8() + "\n");
    file.write(lines.toUtf8());
    return true;
}

// Whole text file, or "" when it does not exist (Trading data price series).
QString OSHelper::readTextFile(const QString &path) const
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    return QString::fromUtf8(file.readAll());
}

// Replaces a text file (written to a temporary file first, so a crash never leaves half a file).
bool OSHelper::writeTextFile(const QString &path, const QString &text) const
{
    QFileInfo info(path);
    if (!QDir().mkpath(info.absolutePath()))
    {
        qWarning() << "writeTextFile: cannot create" << info.absolutePath();
        return false;
    }
    const QString tmp = path + ".tmp";
    QFile file(tmp);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
    {
        qWarning() << "writeTextFile: cannot open" << tmp;
        return false;
    }
    file.write(text.toUtf8());
    file.close();
    QFile::remove(path);
    return QFile::rename(tmp, path);
}

// System notification (price alerts). macOS only: native (app icon), osascript as fallback; elsewhere it is a no-op.
void OSHelper::notify(const QString &title, const QString &message) const
{
#ifdef Q_OS_MACOS
    if (MacOSHelper::notify(title, message))
        return;
    auto quote = [](QString s) { return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""; };
    QProcess::startDetached("/usr/bin/osascript",
        {"-e", "display notification " + quote(message) + " with title " + quote(title) + " sound name \"Glass\""});
#else
    Q_UNUSED(title);
    Q_UNUSED(message);
#endif
}

// Opens a folder itself in Finder / Explorer (creating it if needed).
bool OSHelper::openFolder(const QString &dirPath) const
{
    QDir().mkpath(dirPath);
    QUrl url = QUrl::fromLocalFile(QDir(dirPath).absolutePath());
    if (!url.isValid())
    {
        qWarning() << "Malformed folder path" << dirPath;
        return false;
    }
    return QDesktopServices::openUrl(url);
}

void OSHelper::armShutdownWatchdog(int seconds) const
{
    // closing waits for requests in flight (wallet refresh, prices, Nym lookups), which through
    // the mixnet can take long; after this many seconds the process ends anyway
    std::thread([seconds]() {
        std::this_thread::sleep_for(std::chrono::seconds(seconds));
        qWarning() << "Shutdown took longer than" << seconds << "s, exiting now";
        std::fflush(nullptr);
        std::_Exit(0);
    }).detach();
}



QString OSHelper::temporaryPath() const
{
    return QDir::tempPath();
}

namespace {

// "host:port" -> (host, port)
std::pair<QString, quint16> splitHostPort(const QString &address, quint16 fallbackPort)
{
    const int colon = address.lastIndexOf(':');
    if (colon <= 0)
        return {address, fallbackPort};
    bool ok = false;
    const quint16 port = address.mid(colon + 1).toUShort(&ok);
    return {address.left(colon), ok ? port : fallbackPort};
}

using connection_probe::HttpResult;
using connection_probe::httpRequest;

// Monero P2P ping (the same COMMAND_PING monerod sends to check a peer) through the proxy
QJsonObject moneroPing(const QNetworkProxy &proxy, const QString &host, quint16 port, int timeoutMs)
{
    QJsonObject o{{"host", host}, {"ok", false}};
    QElapsedTimer timer;
    timer.start();
    QTcpSocket socket;
    socket.setProxy(proxy);
    socket.connectToHost(host, port);
    if (!socket.waitForConnected(timeoutMs))
    {
        o["error"] = socket.errorString();
        return o;
    }
    o["connectMs"] = timer.elapsed();
    // levin header (33 bytes, little endian) + empty portable-storage section
    const QByteArray body = QByteArray::fromHex("01110101010102010100");
    QByteArray packet;
    const auto put = [&packet](quint64 v, int bytes) { for (int i = 0; i < bytes; ++i) packet.append(char((v >> (8 * i)) & 0xff)); };
    put(0x0101010101012101ULL, 8); // signature
    put(body.size(), 8);          // body size
    put(1, 1);                    // expects an answer
    put(1003, 4);                 // COMMAND_PING
    put(0, 4);                    // return code
    put(1, 4);                    // request
    put(1, 4);                    // protocol version
    packet += body;
    const qint64 sent = timer.elapsed();
    socket.write(packet);
    QByteArray answer;
    while (timer.elapsed() < timeoutMs && answer.size() < 33 + 8)
    {
        if (!socket.waitForReadyRead(std::max<qint64>(1, timeoutMs - timer.elapsed())))
            break;
        answer += socket.readAll();
    }
    if (answer.size() >= 33 && answer.startsWith(packet.left(8)))
    {
        o["ok"] = true;
        o["pingMs"] = timer.elapsed() - sent;
    }
    else
        o["error"] = answer.isEmpty() ? (socket.state() == QAbstractSocket::ConnectedState ? QString("no answer") : socket.errorString())
                                      : QString("unexpected answer");
    return o;
}

} // namespace

void OSHelper::cancelConnectionTest()
{
    if (m_connectionTestCancellation) m_connectionTestCancellation->store(true);
}

void OSHelper::nymVpnTest(const QString &socksAddress, const QString &daemonAddress, const QJSValue &callback)
{
    cancelConnectionTest();
    auto cancellation = std::make_shared<std::atomic<bool>>(false);
    m_connectionTestCancellation = cancellation;
    QThread *thread = QThread::create([this, socksAddress, daemonAddress, callback, cancellation]() {
        const auto cancelled = [cancellation] { return cancellation->load(); };
        const auto report = [this, callback, cancellation](const QJsonObject &o) {
            if (cancellation->load()) return;
            const QString json = QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
            QMetaObject::invokeMethod(this, [callback, json, cancellation]() {
                if (cancellation->load()) return;
                QJSValue cb(callback);
                if (cb.isCallable())
                    cb.call(QJSValueList({json}));
            }, Qt::QueuedConnection);
        };
        const auto socks = splitHostPort(socksAddress, 1080);
        const QNetworkProxy proxy = socksAddress.isEmpty() ? QNetworkProxy(QNetworkProxy::NoProxy)
                                                           : QNetworkProxy(QNetworkProxy::Socks5Proxy, socks.first, socks.second);

        // 1. the local SOCKS5 proxy answers (none: direct connection)
        if (socksAddress.isEmpty())
            report({{"key", "socks"}, {"ok", true}, {"direct", true}});
        else
        {
            QElapsedTimer t;
            t.start();
            QTcpSocket s;
            s.setProxy(QNetworkProxy::NoProxy);
            s.connectToHost(socks.first, socks.second);
            const bool ok = s.waitForConnected(3000);
            report({{"key", "socks"}, {"ok", ok}, {"ms", t.elapsed()}, {"error", ok ? QString() : s.errorString()}});
            if (!ok)
            {
                report({{"key", "done"}});
                return;
            }
        }

        if (cancelled()) return;
        // 2. public IP seen from outside (through the proxy)
        if (QSslSocket::supportsSsl())
        {
            QJsonObject ip{{"key", "ip"}, {"ok", false}};
            const HttpResult who = httpRequest(proxy, true, "ipwho.is", 443, "GET", "/", QByteArray(), 30000, true, cancelled);
            const QJsonObject j = QJsonDocument::fromJson(who.body).object();
            if (who.ok && !j["ip"].toString().isEmpty())
            {
                ip["ok"] = true;
                ip["ip"] = j["ip"];
                ip["place"] = QStringList({j["city"].toString(), j["country"].toString()}).filter(QRegularExpression(".")).join(", ");
            }
            else
            {
                const HttpResult info = httpRequest(proxy, true, "ipinfo.io", 443, "GET", "/json", QByteArray(), 30000, true, cancelled);
                const QJsonObject k = QJsonDocument::fromJson(info.body).object();
                if (info.ok && !k["ip"].toString().isEmpty())
                {
                    ip["ok"] = true;
                    ip["ip"] = k["ip"];
                    ip["place"] = QStringList({k["city"].toString(), k["country"].toString()}).filter(QRegularExpression(".")).join(", ");
                }
                else
                    ip["error"] = info.error.isEmpty() ? QString("unexpected answer") : info.error;
            }
            report(ip);
        }
        else
            report({{"key", "ip"}, {"ok", false}, {"error", QString("TLS not available")}});

        if (cancelled()) return;
        // 3. web latency: three small HTTPS requests through the mixnet (connect + TLS + answer each)
        if (!QSslSocket::supportsSsl())
        {
            report({{"key", "latency"}, {"ok", false}, {"error", QString("TLS not available")}});
            report({{"key", "speed"}, {"ok", false}, {"error", QString("TLS not available")}});
        }
        else
        {
            QJsonArray times;
            int failed = 0;
            QString error;
            for (int i = 0; i < 3; ++i)
            {
                if (cancelled()) return;
                const HttpResult r = httpRequest(proxy, true, "speed.cloudflare.com", 443, "GET", "/__down?bytes=0", QByteArray(), 30000, false, cancelled);
                if (r.ok)
                    times.append(r.totalMs);
                else
                {
                    ++failed;
                    error = r.error;
                }
            }
            report({{"key", "latency"}, {"ok", !times.isEmpty()}, {"times", times}, {"failed", failed}, {"error", error}});
        }

        if (cancelled()) return;
        // 4. Bounded sample, measured end-to-end (including connection setup).
        if (QSslSocket::supportsSsl())
        {
            const qint64 requestedBytes = 64000;
            const HttpResult r = httpRequest(proxy, true, "speed.cloudflare.com", 443, "GET", "/__down?bytes=64000", QByteArray(), 90000, false, cancelled);
            const bool validResponse = r.status >= 200 && r.status < 300;
            const qint64 bytes = validResponse ? r.bodyBytes : 0;
            const bool complete = r.ok && bytes == requestedBytes;
            report({{"key", "speed"}, {"ok", complete}, {"bytes", bytes}, {"requestedBytes", requestedBytes},
                    {"partial", !complete && bytes > 0}, {"httpStatus", r.status}, {"ms", r.totalMs},
                    {"kBps", double(bytes) / 1000.0 * 1000.0 / double(std::max<qint64>(1, r.totalMs))},
                    {"error", r.error.isEmpty() && !complete ? QString("unexpected download size") : r.error}});
        }

        if (cancelled()) return;
        // 5. Monero P2P through the mixnet: ping two seed nodes on port 18080 sequentially
        {
            // Official Monero seed peers. The former two test endpoints no longer
            // answered COMMAND_PING even without a proxy (October 2026).
            const QStringList seeds({"192.99.8.110", "37.187.74.171"});
            QList<QJsonObject> results;
            for (const QString &seed : seeds) {
                if (cancelled()) return;
                results.append(moneroPing(proxy, seed, 18080, 45000));
            }
            QJsonArray peers;
            int ok = 0;
            for (const QJsonObject &o : results)
            {
                peers.append(o);
                if (o["ok"].toBool())
                    ++ok;
            }
            report({{"key", "p2p"}, {"ok", ok > 0}, {"reached", ok}, {"total", int(seeds.size())}, {"peers", peers}});
        }

        if (cancelled()) return;
        // 6. the local node (directly, no proxy): height, target and peers
        {
            const auto daemon = splitHostPort(daemonAddress, 18081);
            const QString host = daemon.first == "localhost" ? QString("127.0.0.1") : daemon.first;
            const HttpResult info = httpRequest(QNetworkProxy(QNetworkProxy::NoProxy), false, host, daemon.second,
                                                "POST", "/get_info", "{}", 5000, true, cancelled);
            QJsonObject o{{"key", "node"}, {"ok", info.ok}};
            if (!info.ok)
                o["error"] = info.error;
            else
            {
                const QJsonObject j = QJsonDocument::fromJson(info.body).object();
                for (const char *k : {"height", "target_height", "outgoing_connections_count", "incoming_connections_count", "synchronized", "busy_syncing"})
                    o[k] = j[k];
                const HttpResult conns = httpRequest(QNetworkProxy(QNetworkProxy::NoProxy), false, host, daemon.second, "POST", "/json_rpc",
                                                     "{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"get_connections\"}", 5000, true, cancelled);
                if (conns.ok)
                {
                    QJsonObject states;
                    double downloadKBps = 0;
                    for (const QJsonValue &c : QJsonDocument::fromJson(conns.body).object()["result"].toObject()["connections"].toArray())
                    {
                        downloadKBps += c.toObject()["current_download"].toDouble();
                        const QString state = c.toObject()["state"].toString();
                        states[state] = states[state].toInt() + 1;
                    }
                    o["states"] = states;
                    o["downloadKBps"] = downloadKBps;
                }
            }
            report(o);
        }
        report({{"key", "done"}});
    });
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}

void OSHelper::nodeRpc(const QString &address, const QString &socksAddress, const QString &path,
                       const QString &body, int timeoutMs, const QJSValue &callback)
{
    QThread *thread = QThread::create([this, address, socksAddress, path, body, timeoutMs, callback]() {
        QString target = address.trimmed();
        bool tls = false;
        if (target.startsWith("https://"))
        {
            tls = true;
            target = target.mid(8);
        }
        else if (target.startsWith("http://"))
            target = target.mid(7);
        target = target.section('/', 0, 0);
        const auto hostPort = splitHostPort(target, 18081);
        if (hostPort.second == 443)
            tls = true;
        const auto socks = splitHostPort(socksAddress, 1080);
        const QNetworkProxy proxy = socksAddress.isEmpty() ? QNetworkProxy(QNetworkProxy::NoProxy)
                                                           : QNetworkProxy(QNetworkProxy::Socks5Proxy, socks.first, socks.second);
        const QString host = hostPort.first == "localhost" ? QString("127.0.0.1") : hostPort.first;
        HttpResult r;
        if (tls && !QSslSocket::supportsSsl())
            r.error = "TLS not available";
        else
            r = httpRequest(proxy, tls, host, hostPort.second, body.isEmpty() ? "GET" : "POST", path.toUtf8(), body.toUtf8(), timeoutMs, true);
        const bool ok = r.ok;
        const qint64 ms = r.totalMs;
        const QString answer = QString::fromUtf8(r.body);
        const QString error = r.error;
        QMetaObject::invokeMethod(this, [callback, ok, ms, answer, error]() {
            QJSValue cb(callback);
            if (cb.isCallable())
                cb.call(QJSValueList({ok, double(ms), answer, error}));
        }, Qt::QueuedConnection);
    });
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}

QVariantMap OSHelper::filePermissions(const QString &path) const
{
    QVariantMap m;
    const QFileInfo info(path);
    m["exists"] = info.exists();
    if (!info.exists())
        return m;
    const QFileDevice::Permissions p = info.permissions();
    const int mode = ((p & QFileDevice::ReadOwner) ? 0400 : 0) | ((p & QFileDevice::WriteOwner) ? 0200 : 0) | ((p & QFileDevice::ExeOwner) ? 0100 : 0)
                   | ((p & QFileDevice::ReadGroup) ? 040 : 0) | ((p & QFileDevice::WriteGroup) ? 020 : 0) | ((p & QFileDevice::ExeGroup) ? 010 : 0)
                   | ((p & QFileDevice::ReadOther) ? 04 : 0) | ((p & QFileDevice::WriteOther) ? 02 : 0) | ((p & QFileDevice::ExeOther) ? 01 : 0);
    m["isDir"] = info.isDir();
    m["mode"] = QString::number(mode, 8);
    m["groupOrOthers"] = (mode & 077) != 0;
    m["size"] = double(info.size());
    m["modified"] = info.lastModified();
    return m;
}

bool OSHelper::restrictPermissions(const QString &path) const
{
    const QFileInfo info(path);
    if (!info.exists())
        return false;
    QFileDevice::Permissions p = QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadUser | QFileDevice::WriteUser;
    if (info.isDir())
        p |= QFileDevice::ExeOwner | QFileDevice::ExeUser;
    return QFile::setPermissions(path, p);
}

QString OSHelper::backupFile(const QString &path, const QString &folder) const
{
    const QFileInfo info(path);
    if (!info.isFile() || folder.isEmpty())
        return QString();
    QString dir = folder;
    if (dir.startsWith("file://"))
        dir = QUrl(dir).toLocalFile();
    const QString name = info.fileName();
    const int dot = name.lastIndexOf('.');
    const QString base = dot > 0 ? name.left(dot) : name;
    const QString ext = dot > 0 ? name.mid(dot) : QString();
    const QString target = QDir(dir).filePath(base + "-" + QDateTime::currentDateTime().toString("yyyyMMdd-HHmm") + ext);
    if (QFile::exists(target) || !QFile::copy(path, target))
        return QString();
    QFile::setPermissions(target, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadUser | QFileDevice::WriteUser);
    return target;
}

QVariantMap OSHelper::backupWallet(const QString &walletPath, const QString &folder) const
{
    QVariantMap result;
    result["ok"] = false;
    const QFileInfo keys(walletPath + ".keys");
    if (!keys.isFile() || folder.isEmpty())
        return result;
    QString dir = folder;
    if (dir.startsWith("file://"))
        dir = QUrl(dir).toLocalFile();
    const QString name = QFileInfo(walletPath).fileName();
    const QString target = QDir(dir).filePath("xmr_" + name);
    if (!QDir().mkpath(target))
        return result;
    QFile::setPermissions(target, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner
                                  | QFileDevice::ReadUser | QFileDevice::WriteUser | QFileDevice::ExeUser);

    // same names as the originals, so the wallet opens straight from the backup folder (no .address.txt: plain text)
    QStringList copied;
    for (const QString &suffix : {QString(".keys"), QString(), QString("_notes")}) {
        const QString source = walletPath + suffix;
        if (!QFileInfo(source).isFile())
            continue;
        const QString dest = QDir(target).filePath(name + suffix);
        // the wallet is already open from this folder: never delete it to copy it onto itself
        if (QFileInfo(source).canonicalFilePath() == QFileInfo(dest).canonicalFilePath()) {
            result["error"] = "same";
            return result;
        }
        if (QFile::exists(dest))
            QFile::remove(dest);
        if (!QFile::copy(source, dest))
            return result;
        QFile::setPermissions(dest, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadUser | QFileDevice::WriteUser);
        copied.append(name + suffix);
    }
    result["ok"] = true;
    result["dir"] = target;
    result["files"] = copied;
    return result;
}

QVariantList OSHelper::removableVolumes() const
{
    QVariantList list;
    const QString home = QDir::homePath();
    for (const QStorageInfo &volume : QStorageInfo::mountedVolumes()) {
        if (!volume.isValid() || !volume.isReady() || volume.isRoot() || volume.isReadOnly())
            continue;
        const QString root = volume.rootPath();
        if (home.startsWith(root + "/"))
            continue;
#if defined(Q_OS_MAC)
        if (!root.startsWith("/Volumes/"))
            continue;
#elif defined(Q_OS_WIN)
        if (QDir(root) == QDir(QDir::rootPath()))
            continue;
#else
        if (!root.startsWith("/media/") && !root.startsWith("/run/media/") && !root.startsWith("/mnt/"))
            continue;
#endif
        QVariantMap v;
        v["root"] = root;
        v["name"] = volume.displayName().isEmpty() ? QFileInfo(root).fileName() : volume.displayName();
        v["free"] = double(volume.bytesAvailable());
        v["total"] = double(volume.bytesTotal());
        list.append(v);
    }
    return list;
}

QVariantList OSHelper::removableWallets() const
{
    QVariantList list;
    for (const QVariant &v : removableVolumes()) {
        const QVariantMap volume = v.toMap();
        const QString xmr = QDir(volume["root"].toString()).filePath("XMR");
        if (!QFileInfo(xmr).isDir())
            continue;
        // XMR/*.keys and XMR/<folder>/*.keys (the backups are XMR/xmr_<name>/<name>.keys)
        QStringList keysFiles;
        QDirIterator top(xmr, QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
        while (top.hasNext()) {
            const QFileInfo info(top.next());
            if (info.isFile() && info.suffix() == "keys")
                keysFiles << info.filePath();
            else if (info.isDir() && !info.fileName().startsWith('.')) {
                QDirIterator sub(info.filePath(), {"*.keys"}, QDir::Files);
                while (sub.hasNext())
                    keysFiles << sub.next();
            }
        }
        for (const QString &keys : keysFiles) {
            const QFileInfo info(keys);
            if (info.fileName().startsWith("._"))    // macOS metadata files on FAT/exFAT drives
                continue;
            const QString wallet = info.path() + "/" + info.completeBaseName();
            const auto networkTypeAndAddress = getNetworkTypeAndAddressFromFile(wallet);
            QVariantMap w;
            w["path"] = QDir::toNativeSeparators(wallet);
            w["fileName"] = info.completeBaseName();
            w["volume"] = volume["name"];
            w["modified"] = double(info.lastModified().toSecsSinceEpoch());
            w["networktype"] = int(networkTypeAndAddress.first);
            w["address"] = networkTypeAndAddress.second;
            list.append(w);
        }
    }
    return list;
}

QStringList OSHelper::resourceImages(const QString &folder) const
{
    QStringList urls;
    const QDir dir(QStringLiteral(":/") + folder);
    const QStringList files = dir.entryList({"*.jpg", "*.jpeg", "*.png", "*.JPG", "*.JPEG", "*.PNG"},
                                            QDir::Files, QDir::Name | QDir::IgnoreCase);
    for (const QString &file : files)
        urls << QStringLiteral("qrc:/") + folder + QStringLiteral("/") + file;
    return urls;
}

bool OSHelper::isWritableDirectory(const QString &path) const
{
    const QFileInfo info(path);
    return info.exists() && info.isDir() && info.isWritable();
}

QString OSHelper::randomPassword(int numBytes) const
{
    numBytes = qBound(16, numBytes, 128);

    QByteArray buf(numBytes, Qt::Uninitialized);
    auto *rng = QRandomGenerator::system();
    for (int i = 0; i < numBytes; ++i)
        buf[i] = char(rng->generate() & 0xFF);

    return QString::fromLatin1(buf.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}

bool OSHelper::installed() const
{
#ifdef Q_OS_WIN
    static constexpr const wchar_t installKey[] =
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Monero GUI Wallet_is1";
    static constexpr const wchar_t installValue[] = L"InstallLocation";

    DWORD size;
    LSTATUS status =
        ::RegGetValueW(HKEY_LOCAL_MACHINE, installKey, installValue, RRF_RT_REG_SZ, nullptr, nullptr, &size);
    if (status == ERROR_FILE_NOT_FOUND)
    {
        return false;
    }
    if (status != ERROR_SUCCESS)
    {
        qCritical() << "RegGetValueW failed (get size)" << status;
        return false;
    }

    std::wstring installLocation;
    installLocation.resize(size / sizeof(std::wstring::value_type));
    size = installLocation.size() * sizeof(std::wstring::value_type);
    status = ::RegGetValueW(
        HKEY_LOCAL_MACHINE,
        installKey,
        installValue,
        RRF_RT_REG_SZ,
        nullptr,
        &installLocation[0],
        &size);
    if (status != ERROR_SUCCESS)
    {
        qCritical() << "RegGetValueW Failed (read)" << status;
        return false;
    }

    const QDir installDir(QString(reinterpret_cast<const QChar *>(&installLocation[0])));
    return installDir == QDir(QCoreApplication::applicationDirPath());
#else
    return false;
#endif
}

std::pair<quint8, QString> OSHelper::getNetworkTypeAndAddressFromFile(const QString &wallet)
{
    quint8 networkType = NetworkType::MAINNET;
    QString address = QString("");
    // attempt to retreive wallet address
    if(QFile::exists(wallet + ".address.txt")){
        QFile file(wallet + ".address.txt");
        file.open(QFile::ReadOnly | QFile::Text);
        QString _address = QString(file.readAll());
        if(!_address.isEmpty()){
            address = _address;
            if(address.startsWith("5") || address.startsWith("7")){
                networkType = NetworkType::STAGENET;
            } else if(address.startsWith("9") || address.startsWith("A")){
                networkType = NetworkType::TESTNET;
            }
        }

        file.close();
    }
    return std::make_pair(networkType, address);
}

quint8 OSHelper::getNetworkTypeFromFile(const QString &keysPath, quint8 fallbackNetworkType) const
{
    QString walletPath = keysPath;
    if(keysPath.endsWith(".keys")){
        walletPath = keysPath.mid(0,keysPath.length()-5);
    }
    const auto networkTypeAndAddress = getNetworkTypeAndAddressFromFile(walletPath);
    return networkTypeAndAddress.second.isEmpty() ? fallbackNetworkType : networkTypeAndAddress.first;
}

void OSHelper::openSeedTemplate() const
{
    QFile::copy(":/wizard/template.pdf", QDir::tempPath() + "/seed_template.pdf");
    openFile(QDir::tempPath() + "/seed_template.pdf");
}
