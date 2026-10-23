// Rich text formatting for the Notes editor (a TextEdit with textFormat RichText).
// Works on the TextEdit's QTextDocument like the toolbar of macOS TextEdit: character
// format (font, size, bold, colours, highlight), paragraph styles, alignment, lists,
// checklists and line spacing. With no selection the format is kept for the next typed text.

#ifndef RICHTEXTHELPER_H
#define RICHTEXTHELPER_H

#include <functional>

#include <QColor>
#include <QObject>
#include <QPointer>
#include <QQuickTextDocument>
#include <QTextCharFormat>
#include <QTextCursor>

class QTextDocument;

class RichTextHelper : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QQuickTextDocument *document READ document WRITE setDocument NOTIFY documentChanged)
    Q_PROPERTY(int cursorPosition MEMBER m_cursorPosition WRITE setCursorPosition NOTIFY selectionChanged)
    Q_PROPERTY(int selectionStart MEMBER m_selectionStart WRITE setSelectionStart NOTIFY selectionChanged)
    Q_PROPERTY(int selectionEnd MEMBER m_selectionEnd WRITE setSelectionEnd NOTIFY selectionChanged)
    Q_PROPERTY(int defaultFontSize MEMBER m_defaultFontSize NOTIFY formatChanged)

    Q_PROPERTY(QString fontFamily READ fontFamily NOTIFY formatChanged)
    Q_PROPERTY(int fontSize READ fontSize NOTIFY formatChanged)
    Q_PROPERTY(bool bold READ bold NOTIFY formatChanged)
    Q_PROPERTY(bool italic READ italic NOTIFY formatChanged)
    Q_PROPERTY(bool underline READ underline NOTIFY formatChanged)
    Q_PROPERTY(bool strikeout READ strikeout NOTIFY formatChanged)
    Q_PROPERTY(QColor textColor READ textColor NOTIFY formatChanged)
    Q_PROPERTY(QColor highlightColor READ highlightColor NOTIFY formatChanged)
    Q_PROPERTY(int alignment READ alignment NOTIFY formatChanged)
    Q_PROPERTY(QString listStyle READ listStyle NOTIFY formatChanged)
    Q_PROPERTY(qreal lineHeight READ lineHeight NOTIFY formatChanged)
    Q_PROPERTY(QString paragraphStyle READ paragraphStyle NOTIFY formatChanged)

public:
    explicit RichTextHelper(QObject *parent = nullptr);

    QQuickTextDocument *document() const { return m_quickDocument; }
    void setDocument(QQuickTextDocument *document);
    void setCursorPosition(int position);
    void setSelectionStart(int position);
    void setSelectionEnd(int position);

    QString fontFamily() const;
    int fontSize() const;
    bool bold() const;
    bool italic() const;
    bool underline() const;
    bool strikeout() const;
    QColor textColor() const;
    QColor highlightColor() const;
    int alignment() const;
    QString listStyle() const;
    qreal lineHeight() const;
    QString paragraphStyle() const;

    Q_INVOKABLE void setBold(bool on);
    Q_INVOKABLE void setItalic(bool on);
    Q_INVOKABLE void setUnderline(bool on);
    Q_INVOKABLE void setStrikeout(bool on);
    Q_INVOKABLE void setFontFamily(const QString &family);   // "" = the editor font
    Q_INVOKABLE void setFontSize(int pixelSize);
    Q_INVOKABLE void setTextColor(const QColor &color);      // invalid = automatic
    Q_INVOKABLE void setHighlightColor(const QColor &color); // invalid = none
    Q_INVOKABLE void setAlignment(int alignment);
    Q_INVOKABLE void setListStyle(const QString &style);     // none, disc, circle, square, decimal, lower-alpha, upper-alpha, lower-roman, upper-roman, check
    Q_INVOKABLE void setLineHeight(qreal factor);
    Q_INVOKABLE void setParagraphStyle(const QString &style); // body, title, heading, subheading, mono
    Q_INVOKABLE int insertText(const QString &text, const QString &family); // replaces the selection; returns the new cursor position
    Q_INVOKABLE bool toggleCheck(int position);              // position = start of a checklist item; ticks or unticks it

signals:
    void documentChanged();
    void selectionChanged();
    void formatChanged();

private:
    QTextDocument *doc() const;
    QTextCursor selectionCursor() const;
    QTextCharFormat currentCharFormat() const;
    QTextBlock currentBlock() const;
    void applyChar(const std::function<void(QTextCharFormat &)> &change);
    void applyBlocks(const std::function<void(QTextCursor &, QTextBlock &)> &change);
    void onContentsChange(int position, int removed, int added);

    QPointer<QQuickTextDocument> m_quickDocument;
    int m_cursorPosition = 0;
    int m_selectionStart = 0;
    int m_selectionEnd = 0;
    int m_defaultFontSize = 15;
    // typing format chosen with no selection, applied to the next text typed at m_pendingPosition
    QTextCharFormat m_pending;
    int m_pendingPosition = -1;
    bool m_applying = false;
};

#endif // RICHTEXTHELPER_H
