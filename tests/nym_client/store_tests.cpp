#include "../../src/main/NymAccountStore.h"
#include <QCoreApplication>
#include <QStandardPaths>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <iostream>
#include <stdexcept>
void require(bool ok, const char *message) { if (!ok) throw std::runtime_error(message); }
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    QStandardPaths::setTestModeEnabled(true);
    app.setApplicationName("nym-json-store-test-" + QString::number(app.applicationPid()));
    const QString directory = QFileInfo(NymAccountStore::path()).absolutePath();
    try {
        QString error; QJsonObject data;
        require(!NymAccountStore::exists(), "fresh install has no saved account");
        require(NymAccountStore::load(data, error) && data.isEmpty(), "missing file is empty config");
        data["device_name"] = "Test device";
        data["extension"] = "preserve";
        require(NymAccountStore::save(data, error), "save device metadata");
        require(!NymAccountStore::exists(), "metadata alone does not authorize connection");
        require(NymAccountStore::write("test-only-secret", error), "write account atomically");
        QByteArray secret;
        require(NymAccountStore::read(secret, error) && secret == "test-only-secret", "reload account from disk");
        NymAccountStore::wipe(secret);
        require(NymAccountStore::load(data, error) && !data.contains("device_name") && data["extension"] == "preserve", "drop removed device name and preserve other metadata");
        data["device_id"] = "stable-device";
        require(NymAccountStore::save(data, error), "save device identity");
        require(NymAccountStore::write("test-only-secret", error), "save same phrase");
        require(NymAccountStore::load(data, error) && data["device_id"] == "stable-device", "same phrase preserves identity");
        require(NymAccountStore::write("different-secret", error), "change phrase");
        require(NymAccountStore::load(data, error) && !data.contains("device_id"), "changed phrase clears identity");
        auto perms = QFile::permissions(NymAccountStore::path());
        require(!(perms & (QFileDevice::ReadGroup | QFileDevice::WriteGroup | QFileDevice::ReadOther | QFileDevice::WriteOther)), "private config permissions");
        QFile file(NymAccountStore::path());
        require(file.open(QIODevice::WriteOnly | QIODevice::Truncate), "prepare malformed config");
        file.write("{broken"); file.close();
        require(!NymAccountStore::write("replacement", error), "never overwrite malformed config");
        require(file.open(QIODevice::ReadOnly), "read malformed file");
        require(file.readAll() == "{broken", "failed save preserved original file"); file.close();
        require(NymAccountStore::remove(error) && !QFileInfo::exists(NymAccountStore::path()), "forget removes config");
        QDir(directory).removeRecursively();
        std::cout << "PASS: JSON round trip, removed device name, private permissions, malformed-file preservation and forgetting\n";
    } catch (const std::exception &e) {
        QDir(directory).removeRecursively();
        std::cerr << "FAIL: " << e.what() << '\n'; return 1;
    }
}
