#include "NymAccountStore.h"
#include <QObject>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QStandardPaths>
#if defined(Q_OS_MACOS) && !defined(NYM_CLIENT_TEST)
#include <Security/Security.h>
#endif

namespace NymAccountStore {
void wipe(QByteArray &secret) {
    volatile char *p = secret.data();
    for (qsizetype i = 0; i < secret.size(); ++i) p[i] = 0;
    secret.clear();
}
QString path() {
#ifdef NYM_CLIENT_TEST
    return QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + "/nym.conf";
#else
    return QDir::homePath() + "/Monero/xmr-wallet-plus/nym.conf";
#endif
}
bool load(QJsonObject &config, QString &error) {
    config = {};
    QFile file(path());
    if (!QFileInfo::exists(path())) return true;
    if (!file.open(QIODevice::ReadOnly) || file.size() > 65536) {
        error = QObject::tr("No se puede leer nym.conf."); return false;
    }
    QJsonParseError parse;
    auto bytes = file.readAll();
    const auto doc = QJsonDocument::fromJson(bytes, &parse);
    wipe(bytes);
    if (parse.error != QJsonParseError::NoError || !doc.isObject()) {
        error = QObject::tr("nym.conf no contiene un objeto JSON válido. No se ha modificado."); return false;
    }
    config = doc.object();
    if (config.contains("mnemonic") && !config["mnemonic"].isString()) {
        error = QObject::tr("El campo mnemonic de nym.conf debe ser texto."); return false;
    }
    return true;
}
bool save(QJsonObject config, QString &error) {
    if (QFileInfo(path()).isSymLink()) {
        error = QObject::tr("No se guardará la cuenta en un nym.conf que sea un enlace simbólico."); return false;
    }
    if (!QDir().mkpath(QFileInfo(path()).absolutePath())) {
        error = QObject::tr("No se puede crear la carpeta de nym.conf."); return false;
    }
    config["version"] = 1;
    config.remove("device_name");
    QSaveFile file(path());
    file.setDirectWriteFallback(false);
    if (!file.open(QIODevice::WriteOnly) || !file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner)) {
        error = QObject::tr("No se puede guardar nym.conf con permisos privados."); return false;
    }
    auto bytes = QJsonDocument(config).toJson(QJsonDocument::Indented);
    const bool written = file.write(bytes) == bytes.size();
    wipe(bytes);
    if (!written || !file.commit()) {
        error = QObject::tr("No se pudo completar el guardado de nym.conf."); return false;
    }
    return true;
}
bool exists() {
    QJsonObject config; QString error;
    return load(config, error) && !config["mnemonic"].toString().isEmpty();
}
bool read(QByteArray &secret, QString &error) {
    QJsonObject config;
    if (!load(config, error)) return false;
    wipe(secret);
    secret = config["mnemonic"].toString().toUtf8();
    return true;
}
bool write(const QByteArray &secret, QString &error) {
    QJsonObject config;
    if (!load(config, error)) return false;
    if (config["mnemonic"].toString().simplified() != QString::fromUtf8(secret).simplified())
        config.remove("device_id");
    config["mnemonic"] = QString::fromUtf8(secret);
    return save(config, error);
}
#if defined(Q_OS_MACOS) && !defined(NYM_CLIENT_TEST)
static CFMutableDictionaryRef query() {
    auto q = CFDictionaryCreateMutable(nullptr, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(q, kSecClass, kSecClassGenericPassword);
    CFDictionarySetValue(q, kSecAttrService, CFSTR("org.xmrwalletplus.nym-account"));
    CFDictionarySetValue(q, kSecAttrAccount, CFSTR("subscription-phrase-v1"));
    return q;
}
static bool result(OSStatus status, QString &error) {
    if (status == errSecSuccess) return true;
    error = QObject::tr("Could not access the macOS keychain (error %1).").arg(status);
    return false;
}
// Implemented in Objective-C++ so the account store remains portable C++.
void disableAuthenticationUI(CFMutableDictionaryRef query);
bool legacyExists() {
    auto q = query();
    CFDictionarySetValue(q, kSecReturnAttributes, kCFBooleanTrue);
    disableAuthenticationUI(q);
    CFTypeRef value = nullptr;
    const auto status = SecItemCopyMatching(q, &value);
    if (value) CFRelease(value);
    CFRelease(q);
    // A locked item is still an account; accessing it can prompt on Connect.
    return status == errSecSuccess || status == errSecInteractionNotAllowed || status == errSecAuthFailed;
}
bool readLegacy(QByteArray &secret, QString &error) {
    auto q = query();
    CFDictionarySetValue(q, kSecReturnData, kCFBooleanTrue);
    CFTypeRef value = nullptr;
    const auto status = SecItemCopyMatching(q, &value);
    CFRelease(q);
    if (status == errSecItemNotFound) { wipe(secret); return true; }
    if (!result(status, error)) return false;
    const auto data = static_cast<CFDataRef>(value);
    secret = QByteArray(reinterpret_cast<const char *>(CFDataGetBytePtr(data)), CFDataGetLength(data));
    CFRelease(value);
    return true;
}
bool removeLegacy(QString &error) {
    auto q = query(); const auto status = SecItemDelete(q); CFRelease(q);
    return status == errSecItemNotFound || result(status, error);
}
#else
bool legacyExists() { return false; }
bool readLegacy(QByteArray &secret, QString &) { wipe(secret); return true; }
bool removeLegacy(QString &) { return true; }
#endif
bool remove(QString &error) {
    if (QFileInfo::exists(path()) && !QFile::remove(path())) {
        error = QObject::tr("No se pudo eliminar nym.conf."); return false;
    }
    return removeLegacy(error);
}
bool migrateLegacy(QString &error) {
    QByteArray secret;
    if (!readLegacy(secret, error)) return false;
    if (secret.isEmpty()) { error = QObject::tr("No hay ninguna cuenta Nym guardada en el llavero."); return false; }
    QJsonObject config;
    if (!load(config, error)) { wipe(secret); return false; }
    const auto existing = config["mnemonic"].toString().toUtf8();
    if (!existing.isEmpty() && existing != secret) {
        wipe(secret);
        error = QObject::tr("nym.conf ya contiene otra cuenta. No se ha sustituido ni borrado ninguna frase.");
        return false;
    }
    const bool saved = write(secret, error);
    wipe(secret);
    // Never remove the old secret unless the atomic file save has succeeded.
    return saved && removeLegacy(error);
}
}
