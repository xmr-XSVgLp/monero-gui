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

// System notification (price alerts). macOS only, through osascript; elsewhere it is a no-op.
void OSHelper::notify(const QString &title, const QString &message) const
{
#ifdef Q_OS_MACOS
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

QString OSHelper::nymVpncPath() const
{
    QString path = QStandardPaths::findExecutable("nym-vpnc");
    if (path.isEmpty())
    {
        // the macOS installers put it here; apps started from Finder don't get the shell PATH
        path = QStandardPaths::findExecutable("nym-vpnc", {
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/Applications/NymVPN.app/Contents/MacOS",
            "/Applications/NymVPN.app/Contents/Resources"});
    }
    return path;
}

// Runs nym-vpnc with the given arguments and calls callback(exitCode, output) when it ends.
// exitCode is -1 when it could not be started or took longer than 60 s.
void OSHelper::runNymVpnc(const QStringList &args, const QJSValue &callback)
{
    const QString program = nymVpncPath();
    if (program.isEmpty())
    {
        QJSValue cb(callback);
        if (cb.isCallable())
            cb.call(QJSValueList({-1, QString("nym-vpnc not found")}));
        return;
    }
    runProcess(program, args, callback, 60000);
}

void OSHelper::restartNymVpnDaemon(bool askPassword, const QJSValue &callback)
{
#ifdef Q_OS_MACOS
    // nym-vpnd leaks its internal SOCKS5 server on socks5 disable, so a new route can't bind and
    // traffic keeps leaving through the first exit; restarting the daemon (needs root) frees it.
    // Without askPassword it only works if sudoers allows this exact command with NOPASSWD.
    const QString command = "/bin/launchctl kickstart -k system/net.nymtech.vpn.daemon";
    if (!askPassword)
    {
        runProcess("/usr/bin/sudo", QStringList({"-n", "/bin/launchctl", "kickstart", "-k", "system/net.nymtech.vpn.daemon"}), callback, 30000);
        return;
    }
    // with the same password, also allow this one command without a password from now on
    // (sudoers rule, checked with visudo before it is installed)
    QString shell = command;
    const QString user = qEnvironmentVariable("USER");
    if (QRegularExpression("^[A-Za-z_][A-Za-z0-9_.-]*$").match(user).hasMatch())
    {
        const QString rule = user + " ALL=(root) NOPASSWD: " + command;
        shell = "f=$(/usr/bin/mktemp /tmp/xmrwp.XXXXXX) && echo '" + rule + "' > $f"
                " && /usr/sbin/visudo -cf $f >/dev/null && /usr/sbin/chown root:wheel $f && /bin/chmod 440 $f"
                " && /bin/mkdir -p /etc/sudoers.d && /bin/mv $f /etc/sudoers.d/xmr-wallet-plus-nym; /bin/rm -f $f; "
                + command;
    }
    const QString script = "do shell script \"" + shell + "\" with administrator privileges";
    runProcess("/usr/bin/osascript", QStringList({"-e", script}), callback, 180000);
#else
    Q_UNUSED(askPassword);
    QJSValue cb(callback);
    if (cb.isCallable())
        cb.call(QJSValueList({-1, QString("only supported on macOS")}));
#endif
}

void OSHelper::stopNymVpnDetached() const
{
#ifdef Q_OS_MACOS
    // runs on after the app quits: drop the SOCKS5 proxy and restart the daemon (only if allowed
    // without a password) so the old internal SOCKS5 server and its exit don't stay alive
    const QString program = nymVpncPath();
    if (program.isEmpty())
        return;
    QString quoted = program;
    quoted.replace("'", "'\\''");
    const QString shell = "'" + quoted + "' socks5 disable; /usr/bin/sudo -n /bin/launchctl kickstart -k system/net.nymtech.vpn.daemon";
    QProcess::startDetached("/bin/sh", QStringList({"-c", shell}));
#endif
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

void OSHelper::runProcess(const QString &program, const QStringList &args, const QJSValue &callback, int timeoutMs)
{
    QProcess *process = new QProcess(this);
    process->setProcessChannelMode(QProcess::MergedChannels);
    auto finish = [process, callback](int exitCode, const QString &extra) {
        if (process->property("done").toBool())
            return;
        process->setProperty("done", true);
        const QString output = QString::fromUtf8(process->readAll()).trimmed() + extra;
        QJSValue cb(callback);
        if (cb.isCallable())
            cb.call(QJSValueList({exitCode, output}));
        process->deleteLater();
    };
    connect(process, &QProcess::finished, this, [process, finish](int exitCode, QProcess::ExitStatus status) {
        finish(status == QProcess::NormalExit ? exitCode : -1, QString());
    });
    connect(process, &QProcess::errorOccurred, this, [process, finish](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            finish(-1, process->errorString());
    });
    QTimer::singleShot(timeoutMs, process, [process, finish]() {
        if (process->state() != QProcess::NotRunning)
        {
            process->kill();
            finish(-1, "timeout");
        }
    });
    process->start(program, args);
}

QString OSHelper::nymVpnLogTail() const
{
    QFile file("/var/log/nym-vpnd/nym-vpnd.log");
    if (!file.open(QIODevice::ReadOnly))
        return QString();
    const qint64 maxBytes = 512 * 1024;
    if (file.size() > maxBytes)
        file.seek(file.size() - maxBytes);
    return QString::fromUtf8(file.readAll());
}

QString OSHelper::temporaryPath() const
{
    return QDir::tempPath();
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

quint8 OSHelper::getNetworkTypeFromFile(const QString &keysPath) const
{
    QString walletPath = keysPath;
    if(keysPath.endsWith(".keys")){
        walletPath = keysPath.mid(0,keysPath.length()-5);
    }
    return getNetworkTypeAndAddressFromFile(walletPath).first;
}

void OSHelper::openSeedTemplate() const
{
    QFile::copy(":/wizard/template.pdf", QDir::tempPath() + "/seed_template.pdf");
    openFile(QDir::tempPath() + "/seed_template.pdf");
}
