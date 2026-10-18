#include "../../src/qt/ConnectionProbe.h"
#include <QCoreApplication>
#include <QTcpServer>
#include <QTcpSocket>
#include <QDebug>
#include <cstdlib>

static void check(bool condition, const char *description)
{
    if (!condition) { qCritical() << description; std::exit(1); }
}

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    // Optional live probe, always via the explicit proxy (never a direct fallback).
    if (argc == 3 && QByteArray(argv[1]) == "--nym-probe") {
        const QUrl proxyUrl("socks5://" + QString::fromLocal8Bit(argv[2]));
        check(proxyUrl.isValid() && !proxyUrl.host().isEmpty() && proxyUrl.port() > 0, "invalid proxy");
        const QNetworkProxy proxy(QNetworkProxy::Socks5Proxy, proxyUrl.host(), proxyUrl.port());
        const auto r = connection_probe::httpRequest(proxy, true, "speed.cloudflare.com", 443,
            "GET", "/__down?bytes=64000", {}, 90000, false);
        qInfo() << "HTTP" << r.status << "bytes" << r.bodyBytes << "ms" << r.totalMs << "complete" << r.ok << "error" << r.error;
        return r.ok && r.bodyBytes == 64000 ? 0 : 2;
    }
    QTcpServer server;
    check(server.listen(QHostAddress::LocalHost), "test server cannot listen");
    QObject::connect(&server, &QTcpServer::newConnection, [&] {
        QTcpSocket *client = server.nextPendingConnection();
        QObject::connect(client, &QTcpSocket::disconnected, client, &QObject::deleteLater);
        QObject::connect(client, &QTcpSocket::readyRead, client, [client] {
            QByteArray request = client->property("request").toByteArray() + client->readAll();
            client->setProperty("request", request);
            if (!request.contains("\r\n\r\n") || client->property("sent").toBool()) return;
            client->setProperty("sent", true);
            const QByteArray path = request.split(' ').value(1);
            if (path == "/chunked") {
                client->write("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: keep-alive\r\n\r\n3\r\nabc\r\n");
                QTimer::singleShot(20, client, [client] { client->write("2\r\nde\r\n0\r\n\r\n"); });
            } else if (path == "/partial") {
                client->write("HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\nabc");
            } else if (path == "/error") {
                client->write("HTTP/1.1 403 Forbidden\r\nContent-Length: 6\r\n\r\ndenied");
            } else if (path == "/redirect") {
                client->write("HTTP/1.1 302 Found\r\nLocation: /chunked\r\nContent-Length: 0\r\n\r\n");
                client->setProperty("sent", false); client->setProperty("request", QByteArray());
            } else {
                client->write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n");
            }
        });
    });
    const QNetworkProxy direct(QNetworkProxy::NoProxy);
    const auto get = [&](const QByteArray &path, int timeout = 1000, std::function<bool()> cancel = {}) {
        return connection_probe::httpRequest(direct, false, "127.0.0.1", server.serverPort(), "GET", path, {}, timeout, true, cancel);
    };
    auto r = get("/chunked");
    check(r.ok && r.body == "abcde" && r.bodyBytes == 5 && r.totalMs < 900, "chunked payload/completion must exclude framing and not await EOF");
    r = get("/partial", 150);
    check(!r.ok && r.bodyBytes == 3 && r.error == "timeout", "partial response must retain bytes and report timeout");
    r = get("/error");
    check(!r.ok && r.status == 403 && r.error.startsWith("HTTP 403"), "HTTP error must not be reported as download success");
    r = get("/redirect");
    check(r.ok && r.bodyBytes == 5 && r.body == "abcde", "redirect must use final response body");
    r = get("/zero");
    check(r.ok && r.bodyBytes == 0, "empty successful latency response");
    QElapsedTimer t; t.start();
    r = get("/partial", 3000, [&] { return t.elapsed() > 100; });
    check(!r.ok && r.error == "cancelled" && r.totalMs < 1000, "cancel must abort in-flight download");
    qInfo() << "PASS: chunked, partial, HTTP errors, redirects, empty bodies and cancellation";
}
