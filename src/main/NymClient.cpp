#include "NymClient.h"
#include "NymAccountStore.h"
#include <QDir>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QHostAddress>
#include <QTcpServer>

NymClient::NymClient(QObject *parent) : QObject(parent)
{
    m_startTimer.setSingleShot(true);
    m_accountSaved = NymAccountStore::exists();
    m_startTimer.setInterval(255000);
    m_stopTimer.setSingleShot(true);
    m_stopTimer.setInterval(8000);
    connect(&m_startTimer, &QTimer::timeout, this, [this] {
        fail(tr("The independent Nym client did not connect in time. Try reconnecting."));
    });
    connect(&m_stopTimer, &QTimer::timeout, this, [this] { m_process.kill(); });
    connect(&m_process, &QProcess::started, this, [this] {
        QByteArray payload = QJsonDocument(QJsonObject{{"mnemonic", QString::fromUtf8(m_phrase)}}).toJson(QJsonDocument::Compact) + '\n';
        m_process.write(payload);
        NymAccountStore::wipe(payload);
    });
    connect(&m_process, &QProcess::readyReadStandardOutput, this, &NymClient::readOutput);
    connect(&m_process, &QProcess::readyReadStandardError, this, [this] {
        m_errors = (m_errors + m_process.readAllStandardError()).right(4096);
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            fail(tr("Could not start the bundled Nym client: %1").arg(m_process.errorString()));
    });
    connect(&m_process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
            [this](int, QProcess::ExitStatus) {
        readOutput();
        m_startTimer.stop();
        m_stopTimer.stop();
        m_stopping = false;
        if (m_forgetPending) {
            finishForget();
        } else if (m_restart && m_wanted) {
            m_restart = false;
            launch();
        } else if (m_wanted) {
            fail(tr("The independent Nym client stopped. %1").arg(QString::fromUtf8(m_errors).trimmed()));
        } else if (m_state != "error") {
            m_state = "off";
            emit changed();
        }
    });
    connect(qApp, &QCoreApplication::aboutToQuit, this, &NymClient::stop);
}

NymClient::~NymClient()
{
    NymAccountStore::wipe(m_phrase);
    // A QProcess cannot outlive its owner; kill only our child if graceful stop stalls.
    disconnect(&m_process, nullptr, this, nullptr);
    m_process.closeWriteChannel();
    if (m_process.state() != QProcess::NotRunning && !m_process.waitForFinished(1500)) {
        m_process.kill();
        m_process.waitForFinished(1000);
    }
}

QString NymClient::program() const
{
    return QCoreApplication::applicationDirPath() + "/xmr-nym-client"
#ifdef Q_OS_WIN
        + ".exe"
#endif
        ;
}

bool NymClient::available() const { return QFileInfo(program()).isExecutable(); }

void NymClient::start(const QString &words)
{
    if (m_wanted || m_forgetPending) return;
    if (!words.trimmed().isEmpty()) {
        NymAccountStore::wipe(m_phrase);
        m_phrase = words.simplified().toUtf8();
    }
    if (m_phrase.isEmpty()) {
        QString error;
        if (!NymAccountStore::read(m_phrase, error)) { fail(error); return; }
    }
    if (m_phrase.isEmpty()) {
        fail(tr("Introduce las 24 palabras de tu cuenta NymVPN para conectar."));
        return;
    }
    m_wanted = true;
    if (m_process.state() != QProcess::NotRunning) {
        m_restart = true;
        m_state = "working";
        stopProcess();
        emit changed();
    } else launch();
}

void NymClient::reconnect()
{
    if (m_state == "working" || m_forgetPending) return;
    if (m_phrase.isEmpty()) { start(); return; }
    m_wanted = true;
    m_restart = true;
    m_state = "working";
    m_message.clear();
    m_entry.clear();
    m_exit.clear();
    emit changed();
    if (m_process.state() == QProcess::NotRunning) {
        m_restart = false;
        launch();
    } else stopProcess();
}

void NymClient::stopProcess()
{
    m_startTimer.stop();
    if (m_process.state() == QProcess::NotRunning || m_stopping) return;
    m_stopping = true;
    m_process.closeWriteChannel();
    m_stopTimer.start();
}

void NymClient::stop()
{
    m_wanted = false;
    m_restart = false;
    m_state = "off";
    m_message.clear();
    m_entry.clear();
    m_exit.clear();
    stopProcess();
    emit changed();
}

void NymClient::fail(const QString &message)
{
    m_wanted = false;
    m_restart = false;
    m_state = "error";
    NymAccountStore::wipe(m_phrase);
    m_message = message;
    stopProcess();
    emit changed();
}

void NymClient::launch()
{
    // launch runs only after the previous child has exited: its keys are no longer in use.
    QJsonObject config;
    QString saveError;
    if (!NymAccountStore::load(config, saveError)) { fail(saveError); return; }
    const QString previousPhrase = config["mnemonic"].toString().simplified();
    if (!previousPhrase.isEmpty() && previousPhrase != QString::fromUtf8(m_phrase).simplified()) {
        if (!QDir(accountDirectory()).removeRecursively()) {
            fail(tr("No se pudieron renovar las claves locales del dispositivo Nym."));
            return;
        }
        m_device.clear();
        m_previousExit.clear();
    }
    m_accountSaved = NymAccountStore::write(m_phrase, saveError);
    if (!m_accountSaved) { fail(saveError); return; }

    if (!available()) {
        fail(tr("The bundled Nym client is missing. Rebuild the app with compilar-macos.sh."));
        return;
    }
    QTcpServer reservation;
    if (!reservation.listen(QHostAddress::LocalHost, address().section(':', -1).toUShort())) {
        fail(tr("The wallet's Nym port (17890) is already in use. Close the other wallet instance and retry."));
        return;
    }
    reservation.close();
    m_output.clear();
    m_errors.clear();
    m_entry.clear();
    m_exit.clear();
    m_state = "working";
    m_message.clear();
    m_process.setProgram(program());
    m_process.setArguments({"--authenticated", address(), m_previousExit, accountDirectory()});
    m_startTimer.start();
    emit changed();
    m_process.start();
}

void NymClient::readOutput()
{
    m_output += m_process.readAllStandardOutput();
    if (m_output.size() > 65536) { fail(tr("Invalid response from the Nym client.")); return; }
    while (m_output.contains('\n')) {
        const int end = m_output.indexOf('\n');
        const auto object = QJsonDocument::fromJson(m_output.left(end)).object();
        m_output.remove(0, end + 1);
        if (!m_wanted || m_stopping) continue;
        if (object["event"] == "credentials") {
            m_message = tr("Preparando las credenciales de ancho de banda de NymVPN…");
            emit changed();
        } else if (object["event"] == "error") {
            fail(object["message"].toString());
        } else if (object["event"] == "ready" && object["address"].toString() == address()) {
            if (!object["authenticated"].toBool()) {
                fail(tr("El cliente Nym no ha confirmado la autenticación de la cuenta."));
                return;
            }
            m_message.clear();
            m_device = object["device"].toString();
            QString saveError;
            m_accountSaved = NymAccountStore::write(m_phrase, saveError);
            if (!m_accountSaved) m_message = saveError;
            QJsonObject config;
            QString storageError;
            if (NymAccountStore::load(config, storageError)) {
                config["device_id"] = m_device;
                if (!NymAccountStore::save(config, storageError)) m_message = storageError;
            } else m_message = storageError;
            m_startTimer.stop();
            m_entry = object["entry"].toString();
            m_exit = object["exit"].toString();
            m_previousExit = m_exit;
            m_state = "connected";
            emit changed();
        }
    }
}

QString NymClient::accountDirectory() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + "/nym-account-v1";
}

bool NymClient::accountDataPresent() const
{
    return QDir(accountDirectory()).exists() || QFileInfo::exists(NymAccountStore::path()) || NymAccountStore::legacyExists();
}

void NymClient::forgetAccount()
{
    m_forgetPending = true;
    stop();
    NymAccountStore::wipe(m_phrase);
    if (m_process.state() == QProcess::NotRunning) finishForget();
}

void NymClient::finishForget()
{
    QString error;
    const bool removed = NymAccountStore::remove(error);
    QDir directory(accountDirectory());
    const bool cleaned = !directory.exists() || directory.removeRecursively();
    m_accountSaved = NymAccountStore::exists();
    m_device.clear();
    m_previousExit.clear();
    m_forgetPending = false;
    if (!removed || !cleaned) {
        fail(error.isEmpty() ? tr("No se pudieron eliminar los datos locales de la cuenta Nym.") : error);
    } else {
        m_state = "off";
        m_message = tr("Cuenta Nym olvidada. Introduce sus 24 palabras para volver a conectar.");
        emit changed();
    }
}

bool NymClient::legacyAccountSaved() const { return NymAccountStore::legacyExists(); }

QVariantMap NymClient::accountSettings() const
{
    QJsonObject config; QString error;
    if (!NymAccountStore::load(config, error)) return {{"error", error}};
    auto values = config.toVariantMap();
    if (!m_phrase.isEmpty()) values["mnemonic"] = QString::fromUtf8(m_phrase);
    if (!m_device.isEmpty()) values["device_id"] = m_device;
    values["path"] = NymAccountStore::path();
    return values;
}

QString NymClient::migrateLegacyAccount()
{
    QString error;
    const bool migrated = NymAccountStore::migrateLegacy(error);
    m_accountSaved = NymAccountStore::exists();
    emit changed();
    return migrated ? QString() : error;
}
