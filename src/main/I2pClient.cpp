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

#include "I2pClient.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QNetworkProxy>
#include <QTcpSocket>
#include <QThread>

#include <signal.h>

namespace {
const quint16 kConsolePort = 17971;
const quint16 kSocksPort = 17960;
}

I2pClient::I2pClient(QObject *parent) : QObject(parent)
{
    // a fresh router needs a reseed, then has to learn routers and build tunnels: a few minutes
    m_startTimer.setSingleShot(true);
    m_startTimer.setInterval(600000);
    m_stopTimer.setSingleShot(true);
    m_stopTimer.setInterval(5000);
    m_pollTimer.setInterval(2000);
    connect(&m_startTimer, &QTimer::timeout, this, [this] {
        m_wanted = false;
        fail(tr("I2P did not finish connecting in time. %1").arg(m_lastWarning));
        m_process.terminate();
    });
    connect(&m_stopTimer, &QTimer::timeout, this, [this] { m_process.kill(); });
    connect(&m_pollTimer, &QTimer::timeout, this, &I2pClient::poll);
    m_process.setProcessChannelMode(QProcess::MergedChannels);
    connect(&m_process, &QProcess::readyReadStandardOutput, this, &I2pClient::readOutput);
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            fail(tr("Could not start I2P: %1").arg(m_process.errorString()));
    });
    connect(&m_process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
            [this](int, QProcess::ExitStatus) {
        readOutput();
        m_startTimer.stop();
        m_stopTimer.stop();
        m_pollTimer.stop();
        if (m_wanted && m_retries < 2 && m_state == "starting") {
            // the i2pd of a previous run may still hold the ports for a moment
            m_retries++;
            m_message = tr("I2P could not start yet, retrying…");
            emit changed();
            QTimer::singleShot(4000, this, [this] { if (m_wanted && m_process.state() == QProcess::NotRunning) launch(); });
        } else if (m_wanted) {
            m_wanted = false;
            fail(tr("I2P stopped. %1").arg(m_lastWarning));
        } else if (m_state != "error") {
            m_state = "off";
            m_progress = 0;
            emit changed();
        }
    });
    connect(qApp, &QCoreApplication::aboutToQuit, this, &I2pClient::stop);
}

I2pClient::~I2pClient()
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

// the i2pd inside the app first, Homebrew's otherwise
QString I2pClient::program() const
{
    const QString dir = QCoreApplication::applicationDirPath();
    const QStringList candidates = {
        dir + "/i2pd/i2pd",
        dir + "/../Resources/i2pd/i2pd",
        "/opt/homebrew/bin/i2pd",
        "/usr/local/bin/i2pd",
    };
    for (const QString &path : candidates)
        if (QFileInfo(path).isExecutable())
            return QFileInfo(path).canonicalFilePath();
    return QString();
}

// reseed and family certificates (i2pd refuses unsigned reseed files)
QString I2pClient::certificates() const
{
    const QString bin = QFileInfo(program()).absolutePath();
    const QStringList candidates = {
        bin + "/certificates",
        bin + "/../share/i2pd/certificates",
        bin + "/../share/certificates",
        "/opt/homebrew/share/i2pd/certificates",
        "/usr/local/share/i2pd/certificates",
    };
    for (const QString &path : candidates)
        if (QFileInfo(path + "/reseed").isDir())
            return QFileInfo(path).canonicalFilePath();
    return QString();
}

bool I2pClient::bundled() const
{
    const QString p = program();
    return !p.isEmpty() && p.contains(".app/Contents/");
}

QString I2pClient::dataDirectory() const
{
    return QDir::homePath() + "/Monero/xmr-wallet-plus/i2pd";
}

// reseedProxy: "socks://127.0.0.1:17950" to fetch the first routers through Tor
void I2pClient::start(const QString &reseedProxy)
{
    if (m_wanted && m_state != "error") return;
    m_wanted = true;
    m_retries = 0;
    m_reseedProxy = reseedProxy;
    if (m_process.state() == QProcess::NotRunning)
        launch();
}

void I2pClient::stop()
{
    m_wanted = false;
    m_startTimer.stop();
    m_pollTimer.stop();
    m_state = "off";
    m_progress = 0;
    m_message.clear();
    m_clientTunnels = 0;
    // SIGTERM: i2pd exits right away (SIGINT would wait for transit tunnels, up to 10 minutes)
    if (m_process.state() != QProcess::NotRunning) {
        m_process.terminate();
        m_stopTimer.start();
    }
    emit changed();
}

void I2pClient::launch()
{
    const QString i2pd = program();
    if (i2pd.isEmpty()) {
        m_wanted = false;
        fail(tr("I2P (i2pd) is not in this build of the app."));
        return;
    }
    const QString certs = certificates();
    if (certs.isEmpty()) {
        m_wanted = false;
        fail(tr("The i2pd reseed certificates were not found next to %1.").arg(i2pd));
        return;
    }
    const QString data = dataDirectory();
    QDir().mkpath(data);
    QFile::setPermissions(data, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
    stopStale();

    QStringList args = {
        "--datadir=" + data,
        "--certsdir=" + certs,
        "--pidfile=" + data + "/i2pd.pid",
        "--log=stdout",
        "--loglevel=warn",
        "--http.enabled=true",
        "--http.address=127.0.0.1",
        QString("--http.port=%1").arg(kConsolePort),
        "--httpproxy.enabled=false",
        "--socksproxy.enabled=true",
        "--socksproxy.address=127.0.0.1",
        QString("--socksproxy.port=%1").arg(kSocksPort),
        "--socksproxy.outproxy.enabled=false",
        "--sam.enabled=false",
        "--bob.enabled=false",
        "--i2cp.enabled=false",
        "--i2pcontrol.enabled=false",
        "--upnp.enabled=false",
        "--bandwidth=L",
    };
    if (!m_reseedProxy.isEmpty())
        args << "--reseed.proxy=" + m_reseedProxy;

    m_buffer.clear();
    m_lastWarning.clear();
    m_state = "starting";
    m_progress = 2;
    m_routers = 0;
    m_clientTunnels = 0;
    m_successRate = 0;
    m_networkStatus.clear();
    m_message = tr("Starting I2P…");
    emit changed();
    m_process.setWorkingDirectory(data);
    m_process.start(i2pd, args);
    m_startTimer.start();
    m_pollTimer.start();
}

// an i2pd left over from a previous run of the app (crash, forced quit) with our data directory
bool I2pClient::stopStale()
{
    QFile f(dataDirectory() + "/i2pd.pid");
    if (!f.open(QIODevice::ReadOnly)) return false;
    const qint64 pid = QString::fromUtf8(f.readAll()).trimmed().toLongLong();
    f.close();
    if (pid <= 1 || pid == m_process.processId() || ::kill(pid, 0) != 0) return false;
    QProcess ps;
    ps.start("/bin/ps", {"-p", QString::number(pid), "-o", "comm="});
    ps.waitForFinished(2000);
    if (!QString::fromUtf8(ps.readAllStandardOutput()).trimmed().endsWith("i2pd")) return false;
    ::kill(pid, SIGTERM);
    for (int i = 0; i < 30 && ::kill(pid, 0) == 0; ++i)
        QThread::msleep(100);
    if (::kill(pid, 0) == 0) ::kill(pid, SIGKILL);
    return true;
}

void I2pClient::fail(const QString &message)
{
    m_startTimer.stop();
    m_pollTimer.stop();
    m_state = "error";
    m_progress = 0;
    m_message = message.trimmed();
    emit changed();
}

void I2pClient::readOutput()
{
    m_buffer += m_process.readAllStandardOutput();
    int nl;
    while ((nl = m_buffer.indexOf('\n')) >= 0) {
        const QString line = QString::fromUtf8(m_buffer.left(nl)).trimmed();
        m_buffer.remove(0, nl + 1);
        // "hh:mm:ss@tid/error - message"
        const int dash = line.indexOf(" - ");
        if (line.contains("/error") || line.contains("/critical") || line.contains("/warn"))
            m_lastWarning = dash >= 0 ? line.mid(dash + 3) : line;
        else if (!line.isEmpty() && !line.contains('@'))
            m_lastWarning = line;   // option errors are printed before the log starts
    }
}

// the web console's main page (plain HTTP on localhost, never through a proxy)
void I2pClient::poll()
{
    if (m_polling || m_process.state() != QProcess::Running) return;
    m_polling = true;
    auto *socket = new QTcpSocket(this);
    auto *reply = new QByteArray;
    auto finish = [this, socket, reply] {
        if (socket->property("done").toBool()) return;
        socket->setProperty("done", true);
        m_polling = false;
        const int body = reply->indexOf("\r\n\r\n");
        if (body > 0) parseConsole(QString::fromUtf8(reply->mid(body + 4)));
        delete reply;
        socket->deleteLater();
    };
    socket->setProxy(QNetworkProxy::NoProxy);
    connect(socket, &QTcpSocket::connected, socket, [socket] {
        socket->write("GET / HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n");
    });
    connect(socket, &QTcpSocket::readyRead, socket, [socket, reply] { reply->append(socket->readAll()); });
    connect(socket, &QTcpSocket::disconnected, this, finish);
    connect(socket, &QTcpSocket::errorOccurred, this, [finish](QAbstractSocket::SocketError) { finish(); });
    QTimer::singleShot(4000, socket, [socket] { socket->abort(); });
    socket->connectToHost("127.0.0.1", kConsolePort);
}

void I2pClient::parseConsole(const QString &html)
{
    auto field = [&html](const char *name) {
        const QRegularExpression re(QString("<b>%1:</b>\\s*([^<&]*)").arg(name));
        return re.match(html).captured(1).trimmed();
    };
    if (m_version.isEmpty()) m_version = field("Version");
    m_routers = field("Routers").toInt();
    m_clientTunnels = field("Client Tunnels").toInt();
    m_successRate = field("Tunnel creation success rate").remove('%').toInt();
    m_networkStatus = field("Network status");
    if (!m_wanted) return;

    // usable when the router knows enough of the network and has built client tunnels: the count
    // includes the 3+3 exploratory ones, so more than 6 means the SOCKS proxy's own tunnels exist
    const bool ready = m_routers >= 50 && m_clientTunnels >= 8;
    if (ready) {
        m_startTimer.stop();
        m_state = "connected";
        m_progress = 100;
        m_message.clear();
    } else if (m_state != "connected") {
        m_state = "starting";
        if (m_routers < 50) {
            m_progress = qMax(m_progress, qMin(60, 5 + m_routers));
            m_message = m_routers == 0 ? tr("Getting the first routers (reseed)…")
                                       : tr("Learning the network: %1 routers").arg(m_routers);
        } else {
            m_progress = qMax(m_progress, qMin(95, 60 + m_clientTunnels * 4));
            m_message = tr("Building tunnels: %1").arg(m_clientTunnels);
        }
    } else if (m_clientTunnels == 0) {
        // all tunnels lost (sleep, network change): connecting again
        m_state = "starting";
        m_progress = 60;
        m_message = tr("Building tunnels: %1").arg(m_clientTunnels);
    }
    emit changed();
}
