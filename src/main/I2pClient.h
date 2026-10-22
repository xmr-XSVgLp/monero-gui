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

#pragma once

#include <QObject>
#include <QProcess>
#include <QTimer>

// Bundled I2P router: runs its own i2pd (Contents/MacOS/i2pd/i2pd, or Homebrew's) with only a SOCKS5
// proxy on 127.0.0.1:17960 (no outproxy: only .i2p addresses), web console on 127.0.0.1:17971 (read
// here for the status), data in ~/Monero/xmr-wallet-plus/i2pd. I2P has no exits to the normal
// internet: it is used for .b32.i2p remote nodes and monerod --tx-proxy i2p.
class I2pClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString state READ state NOTIFY changed)       // off | starting | connected | error
    Q_PROPERTY(int progress READ progress NOTIFY changed)     // estimated from routers and tunnels
    Q_PROPERTY(QString message READ message NOTIFY changed)
    Q_PROPERTY(QString version READ version NOTIFY changed)
    Q_PROPERTY(QString networkStatus READ networkStatus NOTIFY changed)
    Q_PROPERTY(int routers READ routers NOTIFY changed)
    Q_PROPERTY(int clientTunnels READ clientTunnels NOTIFY changed)
    Q_PROPERTY(int successRate READ successRate NOTIFY changed)
    Q_PROPERTY(QString address READ address CONSTANT)
public:
    explicit I2pClient(QObject *parent = nullptr);
    ~I2pClient() override;
    QString state() const { return m_state; }
    int progress() const { return m_progress; }
    QString message() const { return m_message; }
    QString version() const { return m_version; }
    QString networkStatus() const { return m_networkStatus; }
    int routers() const { return m_routers; }
    int clientTunnels() const { return m_clientTunnels; }
    int successRate() const { return m_successRate; }
    QString address() const { return QStringLiteral("127.0.0.1:17960"); }
    Q_INVOKABLE bool available() const { return !program().isEmpty(); }
    Q_INVOKABLE bool bundled() const;
    Q_INVOKABLE void start(const QString &reseedProxy = QString());
    Q_INVOKABLE void stop();
signals:
    void changed();
private:
    QString program() const;
    QString certificates() const;
    QString dataDirectory() const;
    void launch();
    void fail(const QString &message);
    void readOutput();
    void poll();
    void parseConsole(const QString &html);
    bool stopStale();
    QProcess m_process;
    QTimer m_startTimer, m_stopTimer, m_pollTimer;
    QByteArray m_buffer;
    QString m_state = "off", m_message, m_version, m_networkStatus, m_lastWarning, m_reseedProxy;
    int m_progress = 0, m_routers = 0, m_clientTunnels = 0, m_successRate = 0, m_retries = 0;
    bool m_wanted = false, m_polling = false;
};
