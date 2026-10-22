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

// Bundled Tor: runs its own tor (Contents/MacOS/tor/tor from the Tor Expert Bundle, or Homebrew's)
// as a client only, SOCKS5 on 127.0.0.1:17950, data in ~/Monero/xmr-wallet-plus/tor. tor exits by
// itself if the app dies (__OwningControllerProcess). New identity = SIGNAL NEWNYM on the control port.
class TorClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString state READ state NOTIFY changed)       // off | starting | connected | error
    Q_PROPERTY(int progress READ progress NOTIFY changed)     // bootstrap %
    Q_PROPERTY(QString message READ message NOTIFY changed)
    Q_PROPERTY(QString version READ version NOTIFY changed)
    Q_PROPERTY(QString address READ address CONSTANT)
public:
    explicit TorClient(QObject *parent = nullptr);
    ~TorClient() override;
    QString state() const { return m_state; }
    int progress() const { return m_progress; }
    QString message() const { return m_message; }
    QString version() const { return m_version; }
    QString address() const { return QStringLiteral("127.0.0.1:17950"); }
    Q_INVOKABLE bool available() const { return !program().isEmpty(); }
    Q_INVOKABLE bool bundled() const;
    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void restart();
    Q_INVOKABLE void newIdentity();
signals:
    void changed();
    void newIdentityDone(bool ok, const QString &error);
private:
    QString program() const;
    QString dataDirectory() const;
    void launch();
    void fail(const QString &message);
    void readOutput();
    QProcess m_process;
    QTimer m_startTimer, m_stopTimer;
    QByteArray m_buffer;
    QString m_state = "off", m_message, m_version, m_lastWarning;
    QString m_firstWarning;
    int m_retries = 0;
    bool stopStale();
    int m_progress = 0;
    bool m_wanted = false, m_restart = false;
};
