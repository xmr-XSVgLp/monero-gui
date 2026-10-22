#pragma once

#include <QFileInfo>
#include <QtGlobal>

// Homebrew OpenSSL's compiled CA path is absent on a clean Mac. Use the
// OS-provided roots before any SSL context is constructed. Keep system_ca
// verification (including hostname checks) and respect explicit overrides.
inline void configureSystemCaCertificates()
{
#ifdef Q_OS_MACOS
    if (!qEnvironmentVariableIsSet("SSL_CERT_FILE")
            && QFileInfo(QStringLiteral("/etc/ssl/cert.pem")).isReadable())
        qputenv("SSL_CERT_FILE", QByteArrayLiteral("/etc/ssl/cert.pem"));
#endif
}
