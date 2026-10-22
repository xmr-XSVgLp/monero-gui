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
#include "NymClient.h"
#include "TorClient.h"
#include "I2pClient.h"
#include <atomic>
#include <memory>
#include <QHash>
#include <QList>
#include <QObject>
#include <QString>
#include <QVariantMap>
#include <vector>
/**
 * @brief The OSHelper class - exports to QML some OS-related functions
 */
class OSHelper : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool installed READ installed CONSTANT);
    Q_PROPERTY(QObject* nymClient READ nymClient CONSTANT)
    Q_PROPERTY(QObject* torClient READ torClient CONSTANT)
    Q_PROPERTY(QObject* i2pClient READ i2pClient CONSTANT)
    Q_PROPERTY(bool geoIpReady READ geoIpReady NOTIFY geoIpReadyChanged)

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
    // macOS menu bar item (no-op elsewhere): title next to the icon, `lines` in its menu ("" = separator)
    Q_INVOKABLE void setMenuBarItem(bool visible, const QString &title, const QStringList &lines, const QString &openLabel);
    // macOS: keep a QML Window on the wallpaper (desktop widget); no-op elsewhere
    Q_INVOKABLE void pinToDesktop(QObject *window);
    QObject *nymClient() { return &m_nymClient; }
    QObject *torClient() { return &m_torClient; }
    QObject *i2pClient() { return &m_i2pClient; }
    // ends the process after `seconds` if the graceful shutdown has not finished by then
    Q_INVOKABLE void armShutdownWatchdog(int seconds) const;
    // connection check: SOCKS5 proxy (empty: direct), web latency and speed through it, Monero P2P ping
    // through it and the local node's state. Runs in its own thread; callback(json) once per finished check, last {"key":"done"}
    Q_INVOKABLE void cancelConnectionTest();
    // nodeSocks: SOCKS5 for a remote node ("" = the local node, reached directly)
    Q_INVOKABLE void nymVpnTest(const QString &socksAddress, const QString &daemonAddress, const QJSValue &callback, const QString &nodeSocks = QString());
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
    // open-wallet page: rename a wallet (all its files, and its folder when it is named like it) or move it to
    // the Trash. path = wallet path without .keys. Result {ok, path (new wallet path), error}
    Q_INVOKABLE QVariantMap renameWallet(const QString &walletPath, const QString &newName) const;
    Q_INVOKABLE QVariantMap trashWallet(const QString &walletPath) const;
    Q_INVOKABLE QVariantList removableVolumes() const;
    // wallets inside the "XMR" folder of removable volumes: [{ path, fileName, volume, modified, networktype, address }]
    Q_INVOKABLE QVariantList removableWallets() const;
    Q_INVOKABLE bool isWritableDirectory(const QString &path) const;
    // images (jpg, jpeg, png) directly inside a folder of the app resources, e.g. "images/trezor-wallpapers",
    // as qrc:/ urls sorted by name; used by the Trezor wallpaper galleries
    Q_INVOKABLE QStringList resourceImages(const QString &folder) const;
    // offline country of an IP (DB-IP Lite CSV packaged in the app or in ~/Monero/xmr-wallet-plus/geoip, no request leaves the app):
    // "ES", or "" while the base loads (in its own thread, geoIpReadyChanged when done) or is missing
    Q_INVOKABLE QString ipCountry(const QString &ip);
    Q_INVOKABLE QString geoIpFile() const;
    // MRL spy-node ban list packaged in the app (Resources/ban_list.txt), "" when missing
    static QString banListPath();
    // {path, entries, title} of that list, for the UI
    Q_INVOKABLE QVariantMap banListInfo() const;
    // P2P handshake with a remote node (port 18080) in its own thread: a node that applies the ban
    // list never hands out banned IPs in its peer list. callback(JSON {ok, peers, banned, selfBanned, height, error})
    Q_INVOKABLE void nodeBanCheck(const QString &address, const QString &socksAddress, int timeoutMs,
                                  const QJSValue &callback);
    // Monero P2P (levin handshake) on host through the SOCKS proxy, trying each port in turn;
    // cb(json): {ok, port, height} or {ok: false, error}. For .onion / .b32.i2p peers of --tx-proxy.
    Q_INVOKABLE void nodeP2pProbe(const QString &host, const QString &socksAddress, const QVariantList &ports,
                                  int timeoutMs, const QJSValue &callback);
    bool geoIpReady() const { return m_geoIpReady; }
    Q_INVOKABLE QString randomPassword(int numBytes = 32) const;
    Q_INVOKABLE bool isCapsLock() const;
    Q_INVOKABLE quint8 getNetworkTypeFromFile(const QString &keysPath, quint8 fallbackNetworkType) const;
    Q_INVOKABLE void openSeedTemplate() const;
    bool installed() const;

    static std::pair<quint8, QString> getNetworkTypeAndAddressFromFile(const QString &wallet);
private:
    // JS callbacks of the background requests. A QJSValue may only be copied or destroyed on the
    // thread of its engine: worker threads carry the id, the value stays here (main thread only).
    quint64 keepCallback(const QJSValue &callback);
    QHash<quint64, QJSValue> m_callbacks;
    quint64 m_callbackSeq = 0;
    quint64 m_connectionTestCallback = 0;
    std::shared_ptr<std::atomic<bool>> m_connectionTestCancellation;
    NymClient m_nymClient;
    TorClient m_torClient;
    I2pClient m_i2pClient;
    // GeoIP ranges sorted by start (IPv6 by its first 64 bits), country as 2 ASCII letters
    struct GeoRanges4 { std::vector<quint32> start, end; std::vector<quint16> cc; };
    struct GeoRanges6 { std::vector<quint64> start, end; std::vector<quint16> cc; };
    void loadGeoIp();
    GeoRanges4 m_geo4;
    GeoRanges6 m_geo6;
    bool m_geoIpReady = false;
    bool m_geoIpLoading = false;
    qint64 m_geoIpLastTry = 0;

signals:
    void menuBarOpenRequested();
    void geoIpReadyChanged();

public slots:
};

#endif // OSHELPER_H
