#include "RichTextHelper.h"

#include <QQuickTextDocument>
#include <QTextBlock>
#include <QTextDocument>
#include <QTextList>

namespace {
const QString monoFamily = QStringLiteral("Menlo");

int styleLevel(const QString &style)
{
    if (style == QLatin1String("title")) return 1;
    if (style == QLatin1String("heading")) return 2;
    if (style == QLatin1String("subheading")) return 3;
    return 0;
}

int styleSize(int level)
{
    return level == 1 ? 28 : level == 2 ? 22 : level == 3 ? 18 : 0;
}

QTextListFormat::Style listFormatStyle(const QString &style)
{
    if (style == QLatin1String("circle")) return QTextListFormat::ListCircle;
    if (style == QLatin1String("square")) return QTextListFormat::ListSquare;
    if (style == QLatin1String("decimal")) return QTextListFormat::ListDecimal;
    if (style == QLatin1String("lower-alpha")) return QTextListFormat::ListLowerAlpha;
    if (style == QLatin1String("upper-alpha")) return QTextListFormat::ListUpperAlpha;
    if (style == QLatin1String("lower-roman")) return QTextListFormat::ListLowerRoman;
    if (style == QLatin1String("upper-roman")) return QTextListFormat::ListUpperRoman;
    return QTextListFormat::ListDisc;
}
}

RichTextHelper::RichTextHelper(QObject *parent)
    : QObject(parent)
{
    connect(this, &RichTextHelper::selectionChanged, this, &RichTextHelper::formatChanged);
}

QTextDocument *RichTextHelper::doc() const
{
    return m_quickDocument ? m_quickDocument->textDocument() : nullptr;
}

void RichTextHelper::setDocument(QQuickTextDocument *document)
{
    if (document == m_quickDocument)
        return;
    if (doc())
        disconnect(doc(), nullptr, this, nullptr);
    m_quickDocument = document;
    if (doc()) {
        connect(doc(), &QTextDocument::contentsChange, this, &RichTextHelper::onContentsChange);
        connect(doc(), &QTextDocument::contentsChanged, this, &RichTextHelper::formatChanged);
    }
    m_pendingPosition = -1;
    emit documentChanged();
    emit formatChanged();
}

void RichTextHelper::setCursorPosition(int position)
{
    if (position == m_cursorPosition)
        return;
    m_cursorPosition = position;
    if (position != m_pendingPosition)
        m_pendingPosition = -1;
    emit selectionChanged();
}

void RichTextHelper::setSelectionStart(int position)
{
    if (position == m_selectionStart)
        return;
    m_selectionStart = position;
    emit selectionChanged();
}

void RichTextHelper::setSelectionEnd(int position)
{
    if (position == m_selectionEnd)
        return;
    m_selectionEnd = position;
    emit selectionChanged();
}

QTextCursor RichTextHelper::selectionCursor() const
{
    QTextDocument *d = doc();
    if (!d)
        return QTextCursor();
    QTextCursor cursor(d);
    const int last = d->characterCount() - 1;
    if (m_selectionStart != m_selectionEnd) {
        cursor.setPosition(qBound(0, m_selectionStart, last));
        cursor.setPosition(qBound(0, m_selectionEnd, last), QTextCursor::KeepAnchor);
    } else {
        cursor.setPosition(qBound(0, m_cursorPosition, last));
    }
    return cursor;
}

QTextBlock RichTextHelper::currentBlock() const
{
    QTextDocument *d = doc();
    if (!d)
        return QTextBlock();
    return d->findBlock(m_selectionStart == m_selectionEnd ? m_cursorPosition : qMin(m_selectionStart, m_selectionEnd));
}

QTextCharFormat RichTextHelper::currentCharFormat() const
{
    if (m_selectionStart == m_selectionEnd && m_pendingPosition >= 0 && m_pendingPosition == m_cursorPosition)
        return m_pending;
    QTextCursor cursor = selectionCursor();
    if (cursor.isNull())
        return QTextCharFormat();
    if (cursor.hasSelection()) {
        // format of the first selected character
        QTextCursor first(cursor.document());
        first.setPosition(cursor.selectionStart() + 1);
        return first.charFormat();
    }
    return cursor.charFormat();
}

QString RichTextHelper::fontFamily() const
{
    const QStringList families = currentCharFormat().fontFamilies().toStringList();
    // the editor font (also written into the saved HTML) counts as no font chosen
    if (families.isEmpty() || (doc() && families.first() == doc()->defaultFont().family()))
        return QString();
    return families.first();
}

int RichTextHelper::fontSize() const
{
    const QTextCharFormat format = currentCharFormat();
    if (format.hasProperty(QTextFormat::FontPixelSize))
        return format.intProperty(QTextFormat::FontPixelSize);
    if (format.hasProperty(QTextFormat::FontPointSize))
        return qRound(format.fontPointSize() * 96.0 / 72.0);
    return m_defaultFontSize;
}

bool RichTextHelper::bold() const { return currentCharFormat().fontWeight() >= QFont::DemiBold; }
bool RichTextHelper::italic() const { return currentCharFormat().fontItalic(); }
bool RichTextHelper::underline() const { return currentCharFormat().fontUnderline(); }
bool RichTextHelper::strikeout() const { return currentCharFormat().fontStrikeOut(); }

QColor RichTextHelper::textColor() const
{
    const QTextCharFormat format = currentCharFormat();
    return format.hasProperty(QTextFormat::ForegroundBrush) ? format.foreground().color() : QColor();
}

QColor RichTextHelper::highlightColor() const
{
    const QTextCharFormat format = currentCharFormat();
    return format.hasProperty(QTextFormat::BackgroundBrush) ? format.background().color() : QColor();
}

int RichTextHelper::alignment() const
{
    const Qt::Alignment align = currentBlock().blockFormat().alignment() & Qt::AlignHorizontal_Mask;
    if (align & Qt::AlignHCenter) return Qt::AlignHCenter;
    if (align & Qt::AlignRight) return Qt::AlignRight;
    if (align & Qt::AlignJustify) return Qt::AlignJustify;
    return Qt::AlignLeft;
}

QString RichTextHelper::listStyle() const
{
    const QTextBlock block = currentBlock();
    QTextList *list = block.textList();
    if (!list)
        return QStringLiteral("none");
    if (block.blockFormat().marker() != QTextBlockFormat::MarkerType::NoMarker)
        return QStringLiteral("check");
    switch (list->format().style()) {
    case QTextListFormat::ListCircle: return QStringLiteral("circle");
    case QTextListFormat::ListSquare: return QStringLiteral("square");
    case QTextListFormat::ListDecimal: return QStringLiteral("decimal");
    case QTextListFormat::ListLowerAlpha: return QStringLiteral("lower-alpha");
    case QTextListFormat::ListUpperAlpha: return QStringLiteral("upper-alpha");
    case QTextListFormat::ListLowerRoman: return QStringLiteral("lower-roman");
    case QTextListFormat::ListUpperRoman: return QStringLiteral("upper-roman");
    default: return QStringLiteral("disc");
    }
}

qreal RichTextHelper::lineHeight() const
{
    const QTextBlockFormat format = currentBlock().blockFormat();
    if (format.lineHeightType() != QTextBlockFormat::ProportionalHeight)
        return 1.0;
    return format.lineHeight() / 100.0;
}

QString RichTextHelper::paragraphStyle() const
{
    switch (currentBlock().blockFormat().headingLevel()) {
    case 1: return QStringLiteral("title");
    case 2: return QStringLiteral("heading");
    case 3: return QStringLiteral("subheading");
    default: break;
    }
    return fontFamily() == monoFamily ? QStringLiteral("mono") : QStringLiteral("body");
}

void RichTextHelper::applyChar(const std::function<void(QTextCharFormat &)> &change)
{
    QTextCursor cursor = selectionCursor();
    if (cursor.isNull())
        return;
    if (!cursor.hasSelection()) {
        // no selection: remember it for the next typed text, like the typing attributes on macOS
        QTextCharFormat format = currentCharFormat();
        change(format);
        m_pending = format;
        m_pendingPosition = m_cursorPosition;
        emit formatChanged();
        return;
    }
    const int start = cursor.selectionStart();
    const int end = cursor.selectionEnd();
    m_applying = true;
    cursor.beginEditBlock();
    for (QTextBlock block = cursor.document()->findBlock(start); block.isValid() && block.position() < end; block = block.next()) {
        for (QTextBlock::iterator it = block.begin(); !it.atEnd(); ++it) {
            const QTextFragment fragment = it.fragment();
            const int from = qMax(start, fragment.position());
            const int to = qMin(end, fragment.position() + fragment.length());
            if (from >= to)
                continue;
            QTextCharFormat format = fragment.charFormat();
            change(format);
            QTextCursor part(cursor.document());
            part.setPosition(from);
            part.setPosition(to, QTextCursor::KeepAnchor);
            part.setCharFormat(format);
        }
    }
    cursor.endEditBlock();
    m_applying = false;
    emit formatChanged();
}

void RichTextHelper::applyBlocks(const std::function<void(QTextCursor &, QTextBlock &)> &change)
{
    QTextCursor cursor = selectionCursor();
    if (cursor.isNull())
        return;
    const int start = cursor.selectionStart();
    const int end = cursor.selectionEnd();
    m_applying = true;
    cursor.beginEditBlock();
    for (QTextBlock block = cursor.document()->findBlock(start); block.isValid() && block.position() <= end; block = block.next()) {
        QTextCursor blockCursor(block);
        change(blockCursor, block);
    }
    cursor.endEditBlock();
    m_applying = false;
    emit formatChanged();
}

void RichTextHelper::onContentsChange(int position, int removed, int added)
{
    if (m_applying || m_pendingPosition < 0 || added <= removed || position != m_pendingPosition)
        return;
    // the first characters typed after choosing a format with no selection take that format;
    // what follows inherits it from them
    QTextCursor cursor(doc());
    cursor.setPosition(position);
    cursor.setPosition(position + added - removed, QTextCursor::KeepAnchor);
    m_applying = true;
    cursor.setCharFormat(m_pending);
    m_applying = false;
    m_pendingPosition = -1;
}

void RichTextHelper::setBold(bool on)
{
    applyChar([on](QTextCharFormat &f) { f.setFontWeight(on ? QFont::Bold : QFont::Normal); });
}

void RichTextHelper::setItalic(bool on)
{
    applyChar([on](QTextCharFormat &f) { f.setFontItalic(on); });
}

void RichTextHelper::setUnderline(bool on)
{
    applyChar([on](QTextCharFormat &f) { f.setFontUnderline(on); });
}

void RichTextHelper::setStrikeout(bool on)
{
    applyChar([on](QTextCharFormat &f) { f.setFontStrikeOut(on); });
}

void RichTextHelper::setFontFamily(const QString &family)
{
    applyChar([family](QTextCharFormat &f) {
        if (family.isEmpty())
            f.clearProperty(QTextFormat::FontFamilies);
        else
            f.setFontFamilies(QStringList{family});
    });
}

void RichTextHelper::setFontSize(int pixelSize)
{
    if (pixelSize < 6 || pixelSize > 200)
        return;
    applyChar([pixelSize](QTextCharFormat &f) {
        f.clearProperty(QTextFormat::FontPointSize);
        f.setProperty(QTextFormat::FontPixelSize, pixelSize);
    });
}

void RichTextHelper::setTextColor(const QColor &color)
{
    applyChar([color](QTextCharFormat &f) {
        if (color.isValid())
            f.setForeground(color);
        else
            f.clearForeground();
    });
}

void RichTextHelper::setHighlightColor(const QColor &color)
{
    applyChar([color](QTextCharFormat &f) {
        if (color.isValid() && color.alpha() > 0)
            f.setBackground(color);
        else
            f.clearBackground();
    });
}

void RichTextHelper::setAlignment(int alignment)
{
    applyBlocks([alignment](QTextCursor &cursor, QTextBlock &block) {
        QTextBlockFormat format = block.blockFormat();
        format.setAlignment(Qt::Alignment(alignment) | Qt::AlignAbsolute);
        cursor.setBlockFormat(format);
    });
}

void RichTextHelper::setLineHeight(qreal factor)
{
    applyBlocks([factor](QTextCursor &cursor, QTextBlock &block) {
        QTextBlockFormat format = block.blockFormat();
        if (qFuzzyCompare(factor, 1.0))
            format.setLineHeight(0, QTextBlockFormat::SingleHeight);
        else
            format.setLineHeight(factor * 100.0, QTextBlockFormat::ProportionalHeight);
        cursor.setBlockFormat(format);
    });
}

void RichTextHelper::setListStyle(const QString &style)
{
    QTextCursor cursor = selectionCursor();
    if (cursor.isNull())
        return;
    const bool check = style == QLatin1String("check");
    m_applying = true;
    cursor.beginEditBlock();
    if (style == QLatin1String("none")) {
        for (QTextBlock block = cursor.document()->findBlock(cursor.selectionStart()); block.isValid() && block.position() <= cursor.selectionEnd(); block = block.next()) {
            if (QTextList *list = block.textList())
                list->remove(block);
            QTextCursor blockCursor(block);
            QTextBlockFormat format = block.blockFormat();
            format.clearProperty(QTextFormat::BlockMarker);
            format.setIndent(0);
            blockCursor.setBlockFormat(format);
        }
    } else {
        QTextListFormat listFormat;
        listFormat.setStyle(listFormatStyle(style));
        if (QTextList *list = cursor.block().textList()) {
            listFormat.setIndent(list->format().indent());
            list->setFormat(listFormat);
            // selected paragraphs outside the list join it
            for (QTextBlock block = cursor.document()->findBlock(cursor.selectionStart()); block.isValid() && block.position() <= cursor.selectionEnd(); block = block.next())
                if (block.textList() != list)
                    list->add(block);
        } else {
            cursor.createList(listFormat);
        }
        for (QTextBlock block = cursor.document()->findBlock(cursor.selectionStart()); block.isValid() && block.position() <= cursor.selectionEnd(); block = block.next()) {
            QTextCursor blockCursor(block);
            QTextBlockFormat format = block.blockFormat();
            if (check) {
                if (format.marker() == QTextBlockFormat::MarkerType::NoMarker)
                    format.setMarker(QTextBlockFormat::MarkerType::Unchecked);
            } else {
                format.clearProperty(QTextFormat::BlockMarker);
            }
            blockCursor.setBlockFormat(format);
        }
    }
    cursor.endEditBlock();
    m_applying = false;
    emit formatChanged();
}

void RichTextHelper::setParagraphStyle(const QString &style)
{
    const int level = styleLevel(style);
    const bool mono = style == QLatin1String("mono");
    applyBlocks([level, mono](QTextCursor &cursor, QTextBlock &block) {
        QTextBlockFormat blockFormat = block.blockFormat();
        blockFormat.setHeadingLevel(level);
        cursor.setBlockFormat(blockFormat);

        QTextCharFormat format;
        format.setFontWeight(level > 0 ? QFont::Bold : QFont::Normal);
        if (mono)
            format.setFontFamilies(QStringList{monoFamily});
        QTextCharFormat charFormat = block.charFormat();
        for (QTextBlock::iterator it = block.begin(); !it.atEnd(); ++it) {
            const QTextFragment fragment = it.fragment();
            QTextCharFormat f = fragment.charFormat();
            f.clearProperty(QTextFormat::FontPointSize);
            f.clearProperty(QTextFormat::FontPixelSize);
            f.clearProperty(QTextFormat::FontFamilies);
            f.merge(format);
            if (level > 0)
                f.setProperty(QTextFormat::FontPixelSize, styleSize(level));
            QTextCursor part(cursor.document());
            part.setPosition(fragment.position());
            part.setPosition(fragment.position() + fragment.length(), QTextCursor::KeepAnchor);
            part.setCharFormat(f);
        }
        // empty paragraph: the style is used for what is typed in it
        charFormat.clearProperty(QTextFormat::FontPixelSize);
        charFormat.clearProperty(QTextFormat::FontFamilies);
        charFormat.merge(format);
        if (level > 0)
            charFormat.setProperty(QTextFormat::FontPixelSize, styleSize(level));
        QTextCursor(block).setBlockCharFormat(charFormat);
    });
}

bool RichTextHelper::toggleCheck(int position)
{
    QTextDocument *d = doc();
    if (!d)
        return false;
    QTextBlock block = d->findBlock(position);
    QTextBlockFormat format = block.blockFormat();
    // only a click left of the first character, where the box is drawn
    if (position != block.position() || !block.textList() || format.marker() == QTextBlockFormat::MarkerType::NoMarker)
        return false;
    format.setMarker(format.marker() == QTextBlockFormat::MarkerType::Checked ? QTextBlockFormat::MarkerType::Unchecked
                                                                              : QTextBlockFormat::MarkerType::Checked);
    m_applying = true;
    QTextCursor(block).setBlockFormat(format);
    m_applying = false;
    emit formatChanged();
    return true;
}

int RichTextHelper::insertText(const QString &text, const QString &family)
{
    QTextCursor cursor = selectionCursor();
    if (cursor.isNull())
        return m_cursorPosition;
    QTextCharFormat format = currentCharFormat();
    if (!family.isEmpty())
        format.setFontFamilies(QStringList{family});
    m_applying = true;
    cursor.insertText(text, format);
    m_applying = false;
    m_pendingPosition = -1;
    emit formatChanged();
    return cursor.position();
}
