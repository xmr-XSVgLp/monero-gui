#include "../../src/main/NymClient.h"
#include "../../src/main/NymAccountStore.h"
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QFile>
#include <QDir>
#include <QTcpServer>
#include <QThread>
#include <QStandardPaths>
#include <iostream>
#include <functional>
#include <stdexcept>

void require(bool condition, const char *message) {
    if (!condition) throw std::runtime_error(message);
}
void waitFor(const std::function<bool()> &condition) {
    QElapsedTimer timer; timer.start();
    while (!condition() && timer.elapsed() < 4000) {
        QCoreApplication::processEvents(); QThread::msleep(5);
    }
    require(condition(), "timed out");
}
void mode(const char *value) {
    QFile file(QCoreApplication::applicationDirPath() + "/mode");
    require(file.open(QIODevice::WriteOnly), "mode file"); file.write(value);
}
QByteArray events() {
    QFile file(QCoreApplication::applicationDirPath() + "/events");
    if (!file.open(QIODevice::ReadOnly)) return {};
    return file.readAll();
}
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    QStandardPaths::setTestModeEnabled(true);
    app.setApplicationName("nym-auth-manager-test");
    try {
        QString storageError;
        require(NymAccountStore::remove(storageError), "clean isolated test account");
        QFile::remove(app.applicationDirPath() + "/events");
        NymClient client;
        client.start();
        require(client.state() == "error" && events().isEmpty(), "missing account must not launch helper");
        mode("normal");
        QTcpServer occupied;
        require(occupied.listen(QHostAddress::LocalHost, client.address().section(':', -1).toUShort()), "test port is already occupied");
        client.start("test account");
        require(client.state() == "error", "must reject occupied port, never adopt it");
        occupied.close();
        client.start("test account");
        waitFor([&] { return client.state() == "connected"; });
        require(client.message().isEmpty(), "credential preparation message clears after connection");
        const auto first = client.exit();
        client.reconnect();
        require(client.state() == "working", "reconnect must block immediately");
        waitFor([&] { return client.state() == "connected"; });
        require(client.exit() != first, "must start a different process");
        auto history = events().trimmed().split('\n');
        require(history.size() == 3 && history[1].startsWith("stop ") && history[2].startsWith("start "), "old helper must stop before replacement starts");
        client.stop();
        waitFor([&] { return events().count("stop ") == 2; });
        require(client.accountSaved(), "authenticated account is automatically remembered");
        mode("error");
        client.start();
        waitFor([&] { return client.state() == "error"; });
        require(client.message() == "test failure", "preserve helper error");
        mode("delay");
        client.start("test account");
        waitFor([&] { return events().count("start ") == 3 && client.message().contains("credenciales"); });
        require(client.state() == "working", "credential readiness must not mark client connected");
        client.stop();
        waitFor([&] { return events().count("stop ") == 3; });
        require(client.state() == "off", "late ready must not resurrect stopped session");
        mode("normal");
        client.start("test account");
        waitFor([&] { return client.state() == "connected"; });
        client.reconnect();
        client.stop();
        waitFor([&] { return events().count("stop ") == 4; });
        require(events().count("start ") == 4, "stop must cancel pending reconnect");
        QDir().mkpath(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + "/nym-account-v1");
        require(client.accountDataPresent(), "local credential directory detected");
        const QString markerPath = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + "/nym-account-v1/device-marker";
        QFile marker(markerPath);
        require(marker.open(QIODevice::WriteOnly), "create device marker"); marker.close();
        client.stop();
        require(QFile::exists(markerPath) && NymAccountStore::exists(), "logout retains account and device keys");
        client.start("test account");
        waitFor([&] { return client.state() == "connected"; });
        require(QFile::exists(markerPath), "same account reuses device keys");
        client.stop();
        client.start("different account");
        waitFor([&] { return !QFile::exists(markerPath); });
        require(client.accountSettings()["mnemonic"].toString() == "different account", "changed account saved after previous child stops");

        client.forgetAccount();
        waitFor([&] { return !client.accountAvailable() && !client.accountDataPresent(); });
        client.start();
        require(client.state() == "error", "forgotten account must block connection");
        mode("unauthenticated");
        client.start("test account");
        waitFor([&] { return client.state() == "error"; });
        require(client.accountSaved(), "entered phrase is remembered even when connection fails");
        require(client.state() == "error", "saved phrase must not authenticate an unverified helper");
        client.forgetAccount();
        waitFor([&] { return !client.accountAvailable() && !client.accountDataPresent(); });
        std::cout << "PASS: authenticated stdin protocol, missing account, saved account, forget, occupied port, reconnect ordering and cancellation\n";
    } catch (const std::exception &error) {
        std::cerr << "FAIL: " << error.what() << '\n'; return 1;
    }
}
