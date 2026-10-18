#pragma once
#include <QByteArray>
#include <QString>
#include <QJsonObject>

namespace NymAccountStore {
QString path();
bool load(QJsonObject &config, QString &error);
bool save(QJsonObject config, QString &error);
bool legacyExists();
bool migrateLegacy(QString &error);
bool exists();
bool read(QByteArray &secret, QString &error);
bool write(const QByteArray &secret, QString &error);
bool remove(QString &error);
void wipe(QByteArray &secret);
}
