#include "FutureScheduler.h"

#include <mutex>

#include <QThread>
#include <QThreadPool>

FutureScheduler::FutureScheduler(QObject *parent, QThreadPool *pool)
    : QObject(parent), Alive(0), Stopping(false), Pool(pool ? pool : QThreadPool::globalInstance())
{
    static std::once_flag once;
    std::call_once(once, []() {
        // most tasks just wait on the network (up to 60 s through NYM), so 4 threads filled up
        // during sync and everything else queued behind them
        QThreadPool::globalInstance()->setMaxThreadCount(qMax(12, QThread::idealThreadCount()));
    });
}

FutureScheduler::~FutureScheduler()
{
    shutdownWaitForFinished();
}

void FutureScheduler::shutdownWaitForFinished() noexcept
{
    QMutexLocker locker(&Mutex);

    Stopping = true;
    while (Alive > 0)
    {
        Condition.wait(&Mutex);
    }
}

QPair<bool, QFuture<void>> FutureScheduler::run(std::function<void()> function) noexcept
{
    return execute<void>([this, function](QFutureWatcher<void> *) {
        return QtConcurrent::run(Pool, [this, function] {
            try
            {
                function();
            }
            catch (const std::exception &exception)
            {
                qWarning() << "Exception thrown from async function: " << exception.what();
            }
            done();
        });
    });
}

QPair<bool, QFuture<QJSValueList>> FutureScheduler::run(std::function<QJSValueList()> function, const QJSValue &callback)
{
    if (!callback.isCallable())
    {
        throw std::runtime_error("js callback must be callable");
    }

    return execute<QJSValueList>([this, function, callback](QFutureWatcher<QJSValueList> *watcher) {
        connect(watcher, &QFutureWatcher<QJSValueList>::finished, [watcher, callback] {
            QJSValue(callback).call(watcher->future().result());
        });
        return QtConcurrent::run(Pool, [this, function] {
            QJSValueList result;
            try
            {
                result = function();
            }
            catch (const std::exception &exception)
            {
                qWarning() << "Exception thrown from async function: " << exception.what();
            }
            done();
            return result;
        });
    });
}

bool FutureScheduler::stopping() const noexcept
{
    return Stopping;
}

bool FutureScheduler::add() noexcept
{
    QMutexLocker locker(&Mutex);

    if (Stopping)
    {
        return false;
    }

    ++Alive;
    return true;
}

void FutureScheduler::done() noexcept
{
    {
        QMutexLocker locker(&Mutex);
        --Alive;
    }

    Condition.wakeAll();
}
