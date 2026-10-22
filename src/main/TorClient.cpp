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

#include "TorClient.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QTcpSocket>
#include <QThread>

#include <signal.h>

namespace {
const char *kControlPort = "17951";
}

TorClient::TorClient(QObject *parent) : QObject(parent)
{
    m_startTimer.setSingleShot(true);
    m_startTimer.setInterval(180000);
    m_stopTimer.setSingleShot(true);
    m_stopTimer.setInterval(5000);
    connect(&m_startTimer, &QTimer::timeout, this, [this] {
        m_wanted = false;
        fail(tr("Tor did not finish connecting in time. %1").arg(m_lastWarning));
        m_process.terminate();
    });
    connect(&m_stopTimer, &QTimer::timeout, this, [this] { m_process.kill(); });
    m_process.setProcessChannelMode(QProcess::MergedChannels);
    connect(&m_process, &QProcess::readyReadStandardOutput, this, &TorClient::readOutput);
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            fail(tr("Could not start Tor: %1").arg(m_process.errorString()));
    });
    connect(&m_process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
            [this](int, QProcess::ExitStatus) {
        readOutput();
        m_startTimer.stop();
        m_stopTimer.stop();
        if (m_restart && m_wanted) {
            m_restart = false;
            launch();
        } else if (m_wanted && m_retries < 2 && m_state == "starting") {
            // usually at app start: the tor of the previous run still holds the ports or the data
            // directory lock for a moment ("Reading config failed"). Try again shortly.
            m_retries++;
            m_message = tr("Tor could not start yet, retrying…");
            emit changed();
            QTimer::singleShot(4000, this, [this] { if (m_wanted && m_process.state() == QProcess::NotRunning) launch(); });
        } else if (m_wanted) {
            m_wanted = false;
            const QString why = m_firstWarning.isEmpty() || m_firstWarning == m_lastWarning
                                ? m_lastWarning : m_firstWarning + " " + m_lastWarning;
            fail(tr("Tor stopped. %1").arg(why));
        } else if (m_state != "error") {
            m_state = "off";
            m_progress = 0;
            emit changed();
        }
    });
    connect(qApp, &QCoreApplication::aboutToQuit, this, &TorClient::stop);
}

TorClient::~TorClient()
{
    disconnect(&m_process, nullptr, this, nullptr);
    if (m_process.state() != QProcess::NotRunning) {
        m_process.terminate();
        if (!m_process.waitForFinished(1500)) {
            m_process.kill();
            m_process.waitForFinished(1000);
        }
    }
}

// the Tor Expert Bundle inside the app first, Homebrew's tor otherwise
QString TorClient::program() const
{
    const QString dir = QCoreApplication::applicationDirPath();
    const QStringList candidates = {
        dir + "/tor/tor",
        dir + "/../Resources/tor/tor",
        "/opt/homebrew/bin/tor",
        "/usr/local/bin/tor",
    };
    for (const QString &path : candidates)
        if (QFileInfo(path).isExecutable())
            return QFileInfo(path).canonicalFilePath();
    return QString();
}

bool TorClient::bundled() const
{
    const QString p = program();
    return !p.isEmpty() && p.contains(".app/Contents/");
}

QString TorClient::dataDirectory() const
{
    return QDir::homePath() + "/Monero/xmr-wallet-plus/tor";
}

void TorClient::start()
{
    if (m_wanted && m_state != "error") return;
    m_wanted = true;
    m_retries = 0;
    if (m_process.state() != QProcess::NotRunning) {
        restart();
        return;
    }
    launch();
}

void TorClient::restart()
{
    m_wanted = true;
    m_state = "starting";
    m_progress = 0;
    m_message.clear();
    emit changed();
    if (m_process.state() == QProcess::NotRunning) {
        launch();
        return;
    }
    m_restart = true;
    m_startTimer.stop();
    m_process.terminate();
    m_stopTimer.start();
}

void TorClient::stop()
{
    m_wanted = false;
    m_restart = false;
    m_startTimer.stop();
    m_state = "off";
    m_progress = 0;
    m_message.clear();
    if (m_process.state() != QProcess::NotRunning) {
        m_process.terminate();
        m_stopTimer.start();
    }
    emit changed();
}

void TorClient::launch()
{
    const QString tor = program();
    if (tor.isEmpty()) {
        m_wanted = false;
        fail(tr("Tor is not in this build of the app."));
        return;
    }
    const QString data = dataDirectory();
    QDir().mkpath(data);
    QFile::setPermissions(data, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
    stopStale();

    QStringList args = {
        "--defaults-torrc", "/dev/null", "-f", "/dev/null", "--ignore-missing-torrc",
        "--SocksPort", address() + " IsolateSOCKSAuth",
        "--ControlPort", QString("127.0.0.1:") + kControlPort,
        "--CookieAuthentication", "1",
        "--DataDirectory", data,
        "--PidFile", data + "/tor.pid",
        "--ClientOnly", "1",
        "--AvoidDiskWrites", "1",
        "--Log", "notice stdout",
        "--__OwningControllerProcess", QString::number(QCoreApplication::applicationPid()),
    };
    // GeoIP files of the bundle (country of the relays); tor works without them
    const QString geo = QFileInfo(tor).absolutePath() + "/data";
    if (QFileInfo::exists(geo + "/geoip")) args << "--GeoIPFile" << geo + "/geoip";
    if (QFileInfo::exists(geo + "/geoip6")) args << "--GeoIPv6File" << geo + "/geoip6";

    m_buffer.clear();
    m_lastWarning.clear();
    m_firstWarning.clear();
    m_state = "starting";
    m_progress = 0;
    m_message = tr("Starting Tor…");
    emit changed();
    m_process.setWorkingDirectory(QFileInfo(tor).absolutePath());
    m_process.start(tor, args);
    m_startTimer.start();
}

// a tor left over from a previous run of the app (crash, forced quit) with our data directory:
// stop it, otherwise the new one cannot take the ports and the data directory lock
bool TorClient::stopStale()
{
    QFile f(dataDirectory() + "/tor.pid");
    if (!f.open(QIODevice::ReadOnly)) return false;
    const qint64 pid = QString::fromUtf8(f.readAll()).trimmed().toLongLong();
    f.close();
    if (pid <= 1 || pid == m_process.processId() || ::kill(pid, 0) != 0) return false;
    QProcess ps;
    ps.start("/bin/ps", {"-p", QString::number(pid), "-o", "comm="});
    ps.waitForFinished(2000);
    if (!QString::fromUtf8(ps.readAllStandardOutput()).trimmed().endsWith("tor")) return false;
    ::kill(pid, SIGTERM);
    for (int i = 0; i < 30 && ::kill(pid, 0) == 0; ++i)
        QThread::msleep(100);
    if (::kill(pid, 0) == 0) ::kill(pid, SIGKILL);
    return true;
}

void TorClient::fail(const QString &message)
{
    m_startTimer.stop();
    m_state = "error";
    m_progress = 0;
    m_message = message.trimmed();
    emit changed();
}

void TorClient::readOutput()
{
    m_buffer += m_process.readAllStandardOutput();
    int nl;
    static const QRegularExpression boot("Bootstrapped (\\d+)%[^:]*: (.*)$");
    static const QRegularExpression ver("\\bTor (\\d+\\.\\d+\\.\\d+(?:\\.\\d+)?)");
    while ((nl = m_buffer.indexOf('\n')) >= 0) {
        const QString line = QString::fromUtf8(m_buffer.left(nl)).trimmed();
        m_buffer.remove(0, nl + 1);
        if (m_version.isEmpty()) {
            const auto v = ver.match(line);
            if (v.hasMatch()) { m_version = v.captured(1); emit changed(); }
        }
        if (line.contains("[warn]") || line.contains("[err]")) {
            m_lastWarning = line.mid(line.indexOf(']') + 1).trimmed();
            if (m_firstWarning.isEmpty()) m_firstWarning = m_lastWarning;
            if (line.contains("Could not bind") || line.contains("[err]")) {
                if (m_state == "starting") { m_message = m_lastWarning; emit changed(); }
            }
            continue;
        }
        const auto b = boot.match(line);
        if (!b.hasMatch() || !m_wanted) continue;
        m_progress = b.captured(1).toInt();
        if (m_progress >= 100) {
            m_startTimer.stop();
            m_state = "connected";
            m_message.clear();
        } else {
            m_state = "starting";
            m_message = b.captured(2).trimmed();
        }
        emit changed();
    }
}

// new circuits for new connections: AUTHENTICATE with the cookie, then SIGNAL NEWNYM
void TorClient::newIdentity()
{
    QFile cookie(dataDirectory() + "/control_auth_cookie");
    if (m_state != "connected" || !cookie.open(QIODevice::ReadOnly)) {
        emit newIdentityDone(false, tr("Tor is not connected."));
        return;
    }
    const QByteArray hex = cookie.readAll().toHex();
    auto *socket = new QTcpSocket(this);
    auto *reply = new QByteArray;
    auto done = [this, socket, reply](bool ok, const QString &error) {
        if (socket->property("done").toBool()) return;
        socket->setProperty("done", true);
        emit newIdentityDone(ok, error);
        socket->abort();
        socket->deleteLater();
        delete reply;
    };
    connect(socket, &QTcpSocket::connected, this, [socket, hex] {
        socket->write("AUTHENTICATE " + hex + "\r\nSIGNAL NEWNYM\r\nQUIT\r\n");
    });
    connect(socket, &QTcpSocket::readyRead, this, [socket, reply] { *reply += socket->readAll(); });
    connect(socket, &QTcpSocket::disconnected, this, [reply, done] {
        const bool ok = reply->count("250 ") >= 3 && !reply->contains("\n5") && !reply->startsWith("5");
        done(ok, ok ? QString() : QString::fromUtf8(*reply).trimmed());
    });
    connect(socket, &QTcpSocket::errorOccurred, this, [socket, done](QAbstractSocket::SocketError) {
        if (socket->error() != QAbstractSocket::RemoteHostClosedError)
            done(false, socket->errorString());
    });
    QTimer::singleShot(5000, socket, [done] { done(false, QStringLiteral("timeout")); });
    socket->connectToHost("127.0.0.1", QByteArray(kControlPort).toUShort());
}
