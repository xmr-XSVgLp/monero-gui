#pragma once

#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QVariantMap>

// Owns only the bundled SDK helper. Never talks to nym-vpnd or nym-vpnc.
class NymClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString message READ message NOTIFY changed)
    Q_PROPERTY(QString entry READ entry NOTIFY changed)
    Q_PROPERTY(QString exit READ exit NOTIFY changed)
    Q_PROPERTY(QString address READ address CONSTANT)
    Q_PROPERTY(bool accountAvailable READ accountAvailable NOTIFY changed)
    Q_PROPERTY(bool accountDataPresent READ accountDataPresent NOTIFY changed)
    Q_PROPERTY(bool accountSaved READ accountSaved NOTIFY changed)
    Q_PROPERTY(QString device READ device NOTIFY changed)
    Q_PROPERTY(bool legacyAccountSaved READ legacyAccountSaved NOTIFY changed)
public:
    explicit NymClient(QObject *parent = nullptr);
    ~NymClient() override;
    QString state() const { return m_state; }
    QString message() const { return m_message; }
    QString entry() const { return m_entry; }
    QString exit() const { return m_exit; }
    QString address() const {
#ifdef NYM_CLIENT_TEST
        return QStringLiteral("127.0.0.1:17899");
#else
        return QStringLiteral("127.0.0.1:17890");
#endif
    }
    bool accountAvailable() const { return m_accountSaved || !m_phrase.isEmpty(); }
    bool accountDataPresent() const;
    bool accountSaved() const { return m_accountSaved; }
    QString device() const { return m_device; }
    bool legacyAccountSaved() const;
    Q_INVOKABLE QVariantMap accountSettings() const;
    Q_INVOKABLE QString migrateLegacyAccount();
    Q_INVOKABLE bool available() const;
    Q_INVOKABLE void start(const QString &words = QString());
    Q_INVOKABLE void reconnect();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void forgetAccount();
signals:
    void changed();
private:
    QString program() const;
    QString accountDirectory() const;
    void finishForget();
    void launch();
    void stopProcess();
    void fail(const QString &message);
    void readOutput();
    QProcess m_process;
    QTimer m_startTimer, m_stopTimer;
    QByteArray m_output, m_errors;
    QByteArray m_phrase;
    QString m_device;
    bool m_accountSaved = false, m_forgetPending = false;
    QString m_state = "off", m_message, m_entry, m_exit, m_previousExit;
    bool m_wanted = false, m_restart = false, m_stopping = false;
};
