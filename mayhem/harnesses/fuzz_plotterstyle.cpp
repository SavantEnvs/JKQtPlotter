// JKQTBasePlotter style loading: an INI style file (the format of lib/jkqtplotter/resources/styles/*.ini)
// -> QSettings -> loadCurrentPlotterStyle() (every style sub-loader and String2X converter) -> render.
#include "qt_fuzz_app.h"
#include "jkqtplotter/jkqtpbaseplotter.h"
#include <QByteArray>
#include <QDir>
#include <QFile>
#include <QSettings>
#include <QSize>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <unistd.h>

static QString g_dir;

extern "C" int LLVMFuzzerInitialize(int *argc, char ***argv) {
    jkqt_fuzz_init_app(argc, argv);
    const char *t = getenv("TMPDIR");
    g_dir = QString::fromLocal8Bit((t && *t) ? t : "/tmp");
    return 0;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size > 65536) return 0;
    // A unique file per input: QSettings caches parsed files by name, so reusing one
    // path could hand an input the previous input's settings.
    static unsigned long counter = 0;
    const QString path = QDir(g_dir).filePath(
        QString("jkqt_fuzz_style_%1_%2.ini").arg(getpid()).arg(counter++));
    {
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return 0;
        f.write(reinterpret_cast<const char *>(data), (qint64)size);
    }
    {
        QSettings settings(path, QSettings::IniFormat);
        JKQTBasePlotter plot(true);
        plot.loadCurrentPlotterStyle(settings);
        (void)plot.grabPixelImage(QSize(160, 120), false);
    }
    QFile::remove(path);
    return 0;
}
