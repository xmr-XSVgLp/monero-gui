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

#ifndef OSHELPER_H
#define OSHELPER_H

#include <QJSValue>
#include <QList>
#include <QObject>
#include <QString>
#include <QVariantMap>
/**
 * @brief The OSHelper class - exports to QML some OS-related functions
 */
class OSHelper : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool installed READ installed CONSTANT);

public:
    explicit OSHelper(QObject *parent = 0);

    Q_INVOKABLE void createDesktopEntry() const;
    Q_INVOKABLE QString downloadLocation() const;
    Q_INVOKABLE QList<QString> grabQrCodesFromScreen() const;
    Q_INVOKABLE bool openFile(const QString &filePath) const;
    Q_INVOKABLE bool openContainingFolder(const QString &filePath) const;
    Q_INVOKABLE QString openSaveFileDialog(const QString &title, const QString &folder, const QString &filename) const;
    Q_INVOKABLE QString temporaryPath() const;
    Q_INVOKABLE QString swapsLogPath() const;
    Q_INVOKABLE bool appendCsv(const QString &path, const QString &header, const QString &lines) const;
    Q_INVOKABLE bool openFolder(const QString &dirPath) const;
    Q_INVOKABLE QString readTextFile(const QString &path) const;
    Q_INVOKABLE bool writeTextFile(const QString &path, const QString &text) const;
    Q_INVOKABLE void notify(const QString &title, const QString &message) const;
    // NymVPN command line client (nym-vpnc): path, and an async run with callback(exitCode, output)
    Q_INVOKABLE QString nymVpncPath() const;
    Q_INVOKABLE void runNymVpnc(const QStringList &args, const QJSValue &callback);
    // restarts the NymVPN daemon: with sudo -n (no prompt, needs a sudoers rule) or, with askPassword,
    // through the macOS administrator password dialog; callback(exitCode, output)
    Q_INVOKABLE void restartNymVpnDaemon(bool askPassword, const QJSValue &callback);
    // on quit: disable the SOCKS5 proxy and restart the daemon in a process that outlives the app
    Q_INVOKABLE void stopNymVpnDetached() const;
    // ends the process after `seconds` if the graceful shutdown has not finished by then
    Q_INVOKABLE void armShutdownWatchdog(int seconds) const;
    // end of the NymVPN daemon log (it names the entry gateway and the exit Network Requester); "" if unreadable
    Q_INVOKABLE QString nymVpnLogTail() const;
    // connection check: SOCKS5 proxy (empty: direct), web latency and speed through it, Monero P2P ping
    // through it and the local node's state. Runs in its own thread; callback(json) once per finished check, last {"key":"done"}
    Q_INVOKABLE void nymVpnTest(const QString &socksAddress, const QString &daemonAddress, const QJSValue &callback);
    // Security page: one HTTP(S) request to a node's RPC (path, JSON body) through a SOCKS5 proxy ("" = direct),
    // in its own thread; callback(ok, ms, body, error). "https://" or port 443 use TLS.
    Q_INVOKABLE void nodeRpc(const QString &address, const QString &socksAddress, const QString &path,
                             const QString &body, int timeoutMs, const QJSValue &callback);
    // file permissions without reading the file: {exists, isDir, mode ("600"), groupOrOthers, size, modified}
    Q_INVOKABLE QVariantMap filePermissions(const QString &path) const;
    // owner only: 600 for files, 700 for folders
    Q_INVOKABLE bool restrictPermissions(const QString &path) const;
    // copies a file into a folder as <name>-<yyyyMMdd-HHmm><ext>; returns the new path or ""
    Q_INVOKABLE QString backupFile(const QString &path, const QString &folder) const;
    // copies the wallet files (keys, cache, _notes) into <folder>/xmr_<wallet name>, 600/700
    Q_INVOKABLE QVariantMap backupWallet(const QString &walletPath, const QString &folder) const;
    // removable volumes (USB, SD...): [{ root, name, free, total }]
    Q_INVOKABLE QVariantList removableVolumes() const;
    // wallets inside the "XMR" folder of removable volumes: [{ path, fileName, volume, modified, networktype, address }]
    Q_INVOKABLE QVariantList removableWallets() const;
    Q_INVOKABLE bool isWritableDirectory(const QString &path) const;
    Q_INVOKABLE QString randomPassword(int numBytes = 32) const;
    Q_INVOKABLE bool isCapsLock() const;
    Q_INVOKABLE quint8 getNetworkTypeFromFile(const QString &keysPath, quint8 fallbackNetworkType) const;
    Q_INVOKABLE void openSeedTemplate() const;
    bool installed() const;

    static std::pair<quint8, QString> getNetworkTypeAndAddressFromFile(const QString &wallet);
private:
    void runProcess(const QString &program, const QStringList &args, const QJSValue &callback, int timeoutMs);

signals:

public slots:
};

#endif // OSHELPER_H
