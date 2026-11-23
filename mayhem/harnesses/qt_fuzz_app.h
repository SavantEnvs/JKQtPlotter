// Shared Qt bootstrap for the GUI harnesses: one QApplication on the offscreen platform,
// created once in LLVMFuzzerInitialize. It holds no per-input state.
#pragma once
#include <QApplication>
#include <cstdlib>

static inline void jkqt_fuzz_init_app(int *argc, char ***argv) {
    setenv("QT_QPA_PLATFORM", "offscreen", 0);
    setenv("QT_LOGGING_RULES", "*.debug=false;*.warning=false", 0);
    static QApplication *app = new QApplication(*argc, *argv);
    (void)app;
}
