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

#ifndef WALLETMANAGER_H
#define WALLETMANAGER_H

#include <QVariant>
#include <QObject>
#include <QUrl>
#include <wallet/api/wallet2_api.h>
#include <QMutex>
#include <QPointer>
#include <QWaitCondition>
#include <QMap>
#include <QVariantList>
#include "qt/FutureScheduler.h"
#include "NetworkType.h"
#include "PassphraseHelper.h"

class Wallet;
namespace Monero {
struct WalletManager;
}

class WalletManager : public QObject, public PassprasePrompter
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected)
    Q_PROPERTY(QString proxyAddress READ proxyAddress WRITE setProxyAddress NOTIFY proxyAddressChanged)

public:
    explicit WalletManager(QObject *parent = 0);
    ~WalletManager();

    enum LogLevel {
        LogLevel_Silent = Monero::WalletManagerFactory::LogLevel_Silent,
        LogLevel_0 = Monero::WalletManagerFactory::LogLevel_0,
        LogLevel_1 = Monero::WalletManagerFactory::LogLevel_1,
        LogLevel_2 = Monero::WalletManagerFactory::LogLevel_2,
        LogLevel_3 = Monero::WalletManagerFactory::LogLevel_3,
        LogLevel_4 = Monero::WalletManagerFactory::LogLevel_4,
        LogLevel_Min = Monero::WalletManagerFactory::LogLevel_Min,
        LogLevel_Max = Monero::WalletManagerFactory::LogLevel_Max,
    };

    // wizard: createWallet path;
    Q_INVOKABLE Wallet * createWallet(const QString &path, const QString &password,
                                      const QString &language, NetworkType::Type nettype = NetworkType::MAINNET, quint64 kdfRounds = 1);

    /*!
     * \brief openWallet - opens wallet by given path
     * \param path       - wallet filename
     * \param password   - wallet password. Empty string in wallet isn't password protected
     * \param nettype    - type of network the wallet is running on
     * \return wallet object pointer
     */
    Q_INVOKABLE Wallet * openWallet(const QString &path, const QString &password, NetworkType::Type nettype = NetworkType::MAINNET, quint64 kdfRounds = 1);

    /*!
     * \brief openWalletAsync - asynchronous version of "openWallet". Returns immediately. "walletOpened" signal
     *                          emitted when wallet opened;
     */
    Q_INVOKABLE void openWalletAsync(const QString &path, const QString &password, NetworkType::Type nettype = NetworkType::MAINNET, quint64 kdfRounds = 1);

    Q_INVOKABLE Wallet * recoveryWallet(const QString &path, const QString &password, const QString &seed, const QString &seed_offset,
                                       NetworkType::Type nettype = NetworkType::MAINNET, quint64 restoreHeight = 0, quint64 kdfRounds = 1);

    Q_INVOKABLE Wallet * createWalletFromKeys(const QString &path,
                                              const QString &password,
                                              const QString &language,
                                              NetworkType::Type nettype,
                                              const QString &address,
                                              const QString &viewkey,
                                              const QString &spendkey = "",
                                              quint64 restoreHeight = 0,
                                              quint64 kdfRounds = 1);

    Q_INVOKABLE Wallet * createWalletFromDevice(const QString &path,
                                                const QString &password,
                                                NetworkType::Type nettype,
                                                const QString &deviceName,
                                                quint64 restoreHeight = 0,
                                                const QString &subaddressLookahead = "",
                                                quint64 kdfRounds = 1);

    Q_INVOKABLE void createWalletFromDeviceAsync(const QString &path,
                                                const QString &password,
                                                NetworkType::Type nettype,
                                                const QString &deviceName,
                                                quint64 restoreHeight = 0,
                                                const QString &subaddressLookahead = "",
                                                quint64 kdfRounds = 1);
    /*!
     * \brief closeWallet - closes current open wallet and frees memory
     * \return wallet address
     */
    Q_INVOKABLE QString closeWallet();

    /*!
     * \brief closeWalletAsync - asynchronous version of "closeWallet"
     */
    Q_INVOKABLE void closeWalletAsync(const QJSValue& callback);

    // XMR Wallet+ quick switch: hand the open wallet to a background thread (it saves its cache and
    // waits for a pending refresh there) and return at once. Opening the same wallet again,
    // waitClosingWalletsAsync() (quit) and the destructor wait until it is done
    Q_INVOKABLE void closeWalletInBackground();
    Q_INVOKABLE void waitClosingWalletsAsync(const QJSValue& callback);

    // keep the open wallet loaded and syncing in the background. openWallet() on that path resumes
    // it after checking the password, without reloading or rescanning. Only one hardware wallet is
    // kept (they share the device); if the device asks for a passphrase or pairing while it is in
    // the background, the request is declined and its sync pauses until it is resumed
    Q_INVOKABLE void parkWallet();

    // XMR Wallet+ seed accounts: create (and close) a wallet file from the same seed plus a seed
    // offset passphrase, without touching the open wallet. callback(ok, error, address)
    Q_INVOKABLE void createSeedOffsetWalletAsync(const QString &path, const QString &password, const QString &seed,
                                                 const QString &seedOffset, NetworkType::Type nettype,
                                                 quint64 restoreHeight, quint64 kdfRounds, const QJSValue &callback);
    Q_INVOKABLE void closeParkedHwWallets();
    Q_INVOKABLE void closeParkedWallet(const QString &path);
    Q_INVOKABLE void closeParkedWallets(const QString &keepPath = QString());
    Q_INVOKABLE bool lastOpenResumed() const { return m_lastOpenResumed; }
    // [{ path, height }] of the parked wallets
    Q_INVOKABLE QVariantList parkedWallets() const;

    //! checks is given filename is a wallet;
    Q_INVOKABLE bool walletExists(const QString &path) const;

    //! returns list with wallet's filenames, if found by given path
    Q_INVOKABLE QStringList findWallets(const QString &path);

    //! returns error description in human language
    Q_INVOKABLE QString errorString() const;

    //! since we can't call static method from QML, move it to this class
    Q_INVOKABLE static QString displayAmount(quint64 amount);
    Q_INVOKABLE static quint64 amountFromString(const QString &amount);
    Q_INVOKABLE quint64 amountFromDouble(double amount) const;
    Q_INVOKABLE static QString amountsSumFromStrings(const QVector<QString> &amounts);
    Q_INVOKABLE static quint64 maximumAllowedAmount();

    // QML JS engine doesn't support unsigned integers
    Q_INVOKABLE QString maximumAllowedAmountAsString() const;

    Q_INVOKABLE bool paymentIdValid(const QString &payment_id) const;
    Q_INVOKABLE bool addressValid(const QString &address, NetworkType::Type nettype) const;
    Q_INVOKABLE bool keyValid(const QString &key, const QString &address, bool isViewKey, NetworkType::Type nettype) const;

    Q_INVOKABLE QString paymentIdFromAddress(const QString &address, NetworkType::Type nettype) const;

    Q_INVOKABLE void setDaemonAddressAsync(const QString &address);
    Q_INVOKABLE bool connected() const;
    Q_INVOKABLE quint64 networkDifficulty() const;
    Q_INVOKABLE quint64 blockchainHeight() const;
    Q_INVOKABLE quint64 blockchainTargetHeight() const;
    Q_INVOKABLE double miningHashRate() const;
    Q_INVOKABLE bool localDaemonSynced() const;
    Q_INVOKABLE bool isDaemonLocal(const QString &daemon_address) const;

    Q_INVOKABLE void miningStatusAsync();
    Q_INVOKABLE bool startMining(const QString &address, quint32 threads, bool backgroundMining, bool ignoreBattery);
    Q_INVOKABLE bool stopMining();

    // QML missing such functionality, implementing these helpers here
    Q_INVOKABLE QString urlToLocalPath(const QUrl &url) const;
    Q_INVOKABLE QUrl localPathToUrl(const QString &path) const;

    Q_INVOKABLE void setLogLevel(int logLevel);
    Q_INVOKABLE void setLogCategories(const QString &categories);
    // gives up the wait for a confirmation on the Trezor (the operation fails as cancelled)
    Q_INVOKABLE void cancelDeviceConfirmation();

    Q_INVOKABLE quint64 add(quint64 x, quint64 y) const { return x + y; }
    Q_INVOKABLE quint64 sub(quint64 x, quint64 y) const { return x - y; }
    Q_INVOKABLE qint64 addi(qint64 x, qint64 y) const { return x + y; }
    Q_INVOKABLE qint64 subi(qint64 x, qint64 y) const { return x - y; }

    Q_INVOKABLE double getPasswordStrength(const QString &password) const;

    Q_INVOKABLE QString resolveOpenAlias(const QString &address) const;
    Q_INVOKABLE bool parse_uri(const QString &uri, QString &address, QString &payment_id, uint64_t &amount, QString &tx_description, QString &recipient_name, QVector<QString> &unknown_parameters, QString &error) const;
    Q_INVOKABLE QVariantMap parse_uri_to_object(const QString &uri) const;
    Q_INVOKABLE QString make_uri(const QString &address, const QString &amount = "", const QString &tx_description = "", const QString &recipient_name = "") const;
    Q_INVOKABLE bool saveQrCode(const QString &, const QString &) const;
    Q_INVOKABLE void saveQrCodeToClipboard(const QString &) const;
    Q_INVOKABLE void checkUpdatesAsync(
        const QString &software,
        const QString &subdir,
        const QString &buildTag,
        const QString &version,
        const QString &proxyAddress);
    Q_INVOKABLE QString checkUpdates(const QString &software, const QString &subdir) const;

    // clear/rename wallet cache
    Q_INVOKABLE bool clearWalletCache(const QString &fileName) const;

    Q_INVOKABLE void onPassphraseEntered(const QString &passphrase, bool enter_on_device, bool entry_abort=false);
    virtual void onWalletPassphraseNeeded(bool on_device) override;
    Q_INVOKABLE void onPairingCodeEntered(const QString &code, bool entry_abort=false);
    virtual void onWalletPairingCodeNeeded() override;

    QString proxyAddress() const;
    void setProxyAddress(QString address);

signals:

    void walletOpened(Wallet * wallet);
    void walletCreated(Wallet * wallet);
    void walletPassphraseNeeded(bool onDevice);
    void walletPairingCodeNeeded();
    void deviceButtonRequest(quint64 buttonCode);
    void deviceButtonPressed();
    void checkUpdatesComplete(
        const QString &version,
        const QString &downloadUrl,
        const QString &hash,
        const QString &firstSigner,
        const QString &secondSigner) const;
    void miningStatus(bool isMining) const;
    void proxyAddressChanged() const;

public slots:
private:
    friend class WalletPassphraseListenerImpl;

    bool isMining() const;

    static WalletManager * m_instance;
    Monero::WalletManager * m_pimpl;
    mutable QMutex m_mutex;
    QPointer<Wallet> m_currentWallet;
    void waitForClosingWallets(const QString &path);   // empty path: every wallet
    QMutex m_closingMutex;
    QWaitCondition m_closingCond;
    QStringList m_closingPaths;
    void closeInBackground(Wallet *wallet);
    QMap<QString, Wallet *> m_parked;      // key: closingKey(path)
    QMap<Wallet *, QList<QMetaObject::Connection>> m_parkedHooks;
    bool m_lastOpenResumed = false;
    PassphraseReceiver * m_passphraseReceiver;
    QMutex m_mutex_passphraseReceiver;
    QString m_proxyAddress;
    mutable QMutex m_proxyMutex;
    FutureScheduler m_scheduler;
};

#endif // WALLETMANAGER_H
