// Palette files: JKQTPImageTools::registerPalettesFromFile() — the text (.csv/.rgb/.pal) reader with
// its regex-driven format detection and the ParaView XML <ColorMap> reader (QDomDocument), plus the
// LUT builders it calls. Byte 0 selects the file suffix (bits 0-1) and interpolation (bit 2); the
// rest is written to a scratch file in a per-process QTemporaryDir (under $TMPDIR, default /tmp) and
// loaded through the public API.
#include "qt_fuzz_app.h"
// Include everything jkqtpbasicimagetools.h pulls in first, so the access override below only
// touches JKQTPImageTools. The harness needs it to drop the palettes each input registers:
// registerPalettesFromFile() appends to a process-global LUT store with no public way to remove
// entries, so without a reset the store grows on every input and the run ends in a false OOM.
#include <QIcon>
#include <QDebug>
#include <QImage>
#include <QStringList>
#include <QColor>
#include <QReadWriteLock>
#include <QFile>
#include <QString>
#include <QDir>
#include <QTemporaryDir>
#include <cmath>
#include <cfloat>
#include <limits>
#include <vector>
#include <stdint.h>
#include "jkqtcommon/jkqtcommon_imexport.h"
#include "jkqtcommon/jkqtpmathtools.h"
#include "jkqtcommon/jkqttools.h"
#define private public
#include "jkqtcommon/jkqtpbasicimagetools.h"
#undef private
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <memory>

// One scratch directory per process, created once: QTemporaryDir honours $TMPDIR (QDir::tempPath)
// and gives a unique mkdtemp-style name, so parallel jobs never share a file. Removed at exit.
static std::unique_ptr<QTemporaryDir> g_dir;
static QString g_base;

extern "C" int LLVMFuzzerInitialize(int *argc, char ***argv) {
    jkqt_fuzz_init_app(argc, argv);
    g_dir.reset(new QTemporaryDir());
    if (!g_dir->isValid()) {
        fprintf(stderr, "fuzz_palette: cannot create a scratch dir under %s: %s\n",
                qPrintable(QDir::tempPath()), qPrintable(g_dir->errorString()));
        abort();
    }
    g_base = g_dir->filePath("palette.");
    return 0;
}

static void reset_user_palettes() {
    QWriteLocker lock(&JKQTPImageTools::lutMutex);
    auto &store = JKQTPImageTools::global_jkqtpimagetools_lutstore;
    for (auto it = store.begin(); it != store.end();) {
        if (it.key() >= JKQTPMathImageFIRST_REGISTERED_USER_PALETTE) it = store.erase(it);
        else ++it;
    }
    JKQTPImageTools::global_next_userpalette = JKQTPMathImageFIRST_REGISTERED_USER_PALETTE;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size < 1 || size > 64 * 1024) return 0;
    static const char *const kExt[4] = {"csv", "rgb", "pal", "xml"};
    const QString path = g_base + kExt[data[0] & 3];
    const bool interpolate = (data[0] & 4) != 0;
    {
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return 0;
        f.write(reinterpret_cast<const char *>(data + 1), static_cast<qint64>(size - 1));
    }
    const QVector<int> ids = JKQTPImageTools::registerPalettesFromFile(path, interpolate);
    for (int id : ids) {
        (void)JKQTPImageTools::GetPaletteImage(id, 16);
    }
    QFile::remove(path);
    reset_user_palettes();
    return 0;
}
