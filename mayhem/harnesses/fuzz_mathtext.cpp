// JKQTMathText: LaTeX-subset markup -> parse() (tokenizer + node tree) -> getSize() -> draw().
// Markup is what applications feed into axis labels, legends and the jkqtmathtext_render tool.
#include "qt_fuzz_app.h"
#include "jkqtmathtext/jkqtmathtext.h"
#include <QImage>
#include <QPainter>
#include <cstddef>
#include <cstdint>

extern "C" int LLVMFuzzerInitialize(int *argc, char ***argv) {
    jkqt_fuzz_init_app(argc, argv);
    return 0;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    // Labels are short; very long inputs only slow layout down without new code.
    if (size > 4096) return 0;
    const QString markup = QString::fromUtf8(reinterpret_cast<const char *>(data), (qsizetype)size);
    JKQTMathText mt;  // fresh per input: nothing carries across iterations
    mt.useXITS();
    mt.setFontSize(12);
    if (mt.parse(markup)) {
        QImage img(320, 160, QImage::Format_ARGB32_Premultiplied);
        img.fill(Qt::white);
        QPainter p(&img);
        mt.getSize(p);
        mt.draw(p, Qt::AlignCenter, QRectF(0, 0, 320, 160));
        p.end();
    }
    return 0;
}
