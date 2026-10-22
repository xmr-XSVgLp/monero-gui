#include "src/qt/SystemCaCertificates.h"
#include <cassert>
int main() {
#ifdef Q_OS_MACOS
    qunsetenv("SSL_CERT_FILE");
    configureSystemCaCertificates();
    assert(qgetenv("SSL_CERT_FILE") == "/etc/ssl/cert.pem");
    qputenv("SSL_CERT_FILE", "/explicit/custom/ca.pem");
    configureSystemCaCertificates();
    assert(qgetenv("SSL_CERT_FILE") == "/explicit/custom/ca.pem");
#endif
}
