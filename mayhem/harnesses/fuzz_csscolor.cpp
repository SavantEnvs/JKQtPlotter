// CSS-like style strings: JKQTPCSSParser (colors, gradients, numbers with units) and the
// colour/brush converters every style loader uses. The first byte selects the entry point.
#include "qt_fuzz_app.h"
#include "jkqtcommon/jkqtpcsstools.h"
#include "jkqtcommon/jkqtpstringtools.h"
#include <QGradient>
#include <QPixmap>
#include <cstddef>
#include <cstdint>
#include <stdexcept>

extern "C" int LLVMFuzzerInitialize(int *argc, char ***argv) {
    jkqt_fuzz_init_app(argc, argv);
    return 0;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size < 1 || size > 4096) return 0;
    const QString s = QString::fromUtf8(reinterpret_cast<const char *>(data + 1), (qsizetype)(size - 1));
    try {
        switch (data[0] % 5) {
        case 0: (void)JKQTPCSSParser::readColor(s); break;
        case 1: (void)JKQTPCSSParser::readGradient(s); break;
        case 2: (void)JKQTPCSSParser::readNumberWithUnit(s); break;
        case 3: (void)jkqtp_String2QColor(s); break;
        default: {
            QGradient g;
            QPixmap pm;
            (void)jkqtp_String2QBrushStyleExt(s, &g, &pm);
            break;
        }
        }
    } catch (std::runtime_error &) {
        // JKQTPCSSParser::read*() report parse errors as std::runtime_error
    }
    return 0;
}
