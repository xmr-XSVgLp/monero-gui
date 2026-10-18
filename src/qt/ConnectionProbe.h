#pragma once

#include <functional>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QNetworkAccessManager>
#include <QNetworkProxy>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>

namespace connection_probe {
struct HttpResult
{
    bool ok = false;
    qint64 totalMs = 0;
    qint64 firstByteMs = 0;
    qint64 bodyBytes = 0;
    int status = 0;
    QByteArray body;
    QString error;
};

// Called on a worker thread. Qt handles chunk framing, TLS, redirects and partial
// reads; an HTTP error page must never count as a successful speed measurement.
inline HttpResult httpRequest(const QNetworkProxy &proxy, bool tls, const QString &host, quint16 port,
                              const QByteArray &method, const QByteArray &path, const QByteArray &payload,
                              int timeoutMs, bool keepBody, const std::function<bool()> &cancelled = {})
{
    HttpResult result;
    if (cancelled && cancelled()) { result.error = "cancelled"; return result; }
    QElapsedTimer elapsed;
    elapsed.start();
    QNetworkAccessManager manager;
    manager.setProxy(proxy);
    QUrl url;
    url.setScheme(tls ? "https" : "http");
    url.setHost(host);
    url.setPort(port);
    url = url.resolved(QUrl::fromEncoded(path));
    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "XMR-Wallet-Plus");
    request.setRawHeader("Accept", "*/*");
    request.setRawHeader("Accept-Encoding", "identity");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    if (!payload.isEmpty()) request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    QNetworkReply *reply = manager.sendCustomRequest(request, method, payload);
    QEventLoop loop;
    bool timedOut = false, wasCancelled = false;
    const auto consume = [&] {
        const QByteArray bytes = reply->readAll();
        if (bytes.isEmpty()) return;
        if (result.firstByteMs == 0) result.firstByteMs = elapsed.elapsed();
        result.bodyBytes += bytes.size();
        if (keepBody) result.body += bytes;
    };
    QObject::connect(reply, &QNetworkReply::readyRead, &loop, consume);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QTimer deadline;
    deadline.setSingleShot(true);
    QObject::connect(&deadline, &QTimer::timeout, &loop, [&] { timedOut = true; reply->abort(); });
    deadline.start(timeoutMs);
    QTimer cancellation;
    QObject::connect(&cancellation, &QTimer::timeout, &loop, [&] {
        if (cancelled && cancelled()) { wasCancelled = true; reply->abort(); }
    });
    if (cancelled) cancellation.start(100);
    loop.exec();
    if (reply->bytesAvailable()) consume();
    result.totalMs = elapsed.elapsed();
    result.status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    result.ok = !timedOut && !wasCancelled && reply->error() == QNetworkReply::NoError
                && result.status >= 200 && result.status < 300;
    if (!result.ok) {
        if (wasCancelled) result.error = "cancelled";
        else if (timedOut) result.error = "timeout";
        else if (result.status >= 300) result.error = QString("HTTP %1: %2").arg(result.status).arg(reply->errorString());
        else result.error = reply->errorString();
    }
    delete reply;
    return result;
}
} // namespace connection_probe
