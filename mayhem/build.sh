#!/usr/bin/env bash
#
# mayhem/build.sh — JKQtPlotter: sanitized static libs + libFuzzer harnesses, and the upstream
# QtTest unit tests built with normal flags. Re-runnable and offline (all deps are Debian Qt 6).
set -euo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

COMMON_CMAKE=(
  -G Ninja
  -DBUILD_SHARED_LIBS=OFF
  -DJKQtPlotter_BUILD_EXAMPLES=OFF
  -DJKQtPlotter_BUILD_TOOLS=OFF
  -DJKQtPlotter_BUILD_WITH_PRECOMPILED_HEADERS=OFF
  -DJKQtPlotter_BUILD_LIB_JKQTFASTPLOTTER=OFF
  -DJKQtPlotter_BUILD_DECORATE_LIBNAMES_WITH_BUILDTYPE=OFF
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
)

# 1) The project itself, sanitized + SanCov-instrumented (build-* is gitignored upstream).
#    Debug build type with its flags overridden, so no -DNDEBUG and DWARF stays at 3.
FUZZ_FLAGS="-O1 $SANITIZER_FLAGS -fsanitize=fuzzer-no-link $DEBUG_FLAGS"
cmake -S . -B build-fuzz "${COMMON_CMAKE[@]}" \
  -DJKQtPlotter_BUILD_TESTS=OFF \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_C_FLAGS_DEBUG="" -DCMAKE_CXX_FLAGS_DEBUG="" \
  -DCMAKE_C_FLAGS="$FUZZ_FLAGS" -DCMAKE_CXX_FLAGS="$FUZZ_FLAGS"
cmake --build build-fuzz -j"$MAYHEM_JOBS"

# Static libs in dependency order (plotter -> mathtext -> math -> common).
lib() { find build-fuzz/lib -name "lib$1[0-9].a" | head -n1; }
LIBS=("$(lib JKQTPlotter)" "$(lib JKQTMathText)" "$(lib JKQTMath)" "$(lib JKQTCommon)")
for l in "${LIBS[@]}"; do [ -f "$l" ] || { echo "missing static lib" >&2; exit 1; }; done
QT_CFLAGS=$(pkg-config --cflags Qt6Widgets Qt6Svg Qt6Xml Qt6OpenGLWidgets Qt6PrintSupport)
QT_LIBS=$(pkg-config --libs Qt6Widgets Qt6Svg Qt6Xml Qt6OpenGLWidgets Qt6PrintSupport)
# The libraries' PUBLIC compile definitions (XITS/FiraMath, print support, libm probes), taken from
# the compile line of the plotter lib so harness and library agree on class layouts.
mapfile -t LIB_DEFS < <(ninja -C build-fuzz -t commands | grep -m1 'jkqtpbaseplotter\.cpp' | tr ' ' '\n' \
  | grep -E '^-D(JKQT|jkqt|JKQtPlotter_)' | grep -v '_LIB_EXPORT_LIBRARY' | sort -u)
INC=("${LIB_DEFS[@]}" -I"$SRC/lib" -I"$SRC/build-fuzz/lib" -I"$SRC/mayhem/harnesses")

HFLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS -O1 -fPIC -std=c++17"
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o build-fuzz/lsan_off.o
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o build-fuzz/standalone_main.o

for h in fuzz_mathtext fuzz_mathparser fuzz_csscolor fuzz_plotterstyle fuzz_palette; do
  # shellcheck disable=SC2086
  $CXX $HFLAGS "${INC[@]}" $QT_CFLAGS -c "$SRC/mayhem/harnesses/$h.cpp" -o "build-fuzz/$h.o"
  # shellcheck disable=SC2086
  $CXX $HFLAGS $LIB_FUZZING_ENGINE "build-fuzz/$h.o" build-fuzz/lsan_off.o "${LIBS[@]}" $QT_LIBS -lGL -lm \
    -o "$SRC/$h"
  # shellcheck disable=SC2086
  $CXX $HFLAGS "build-fuzz/$h.o" build-fuzz/standalone_main.o build-fuzz/lsan_off.o "${LIBS[@]}" $QT_LIBS -lGL -lm \
    -o "$SRC/$h-standalone"
done

# 2) The upstream QtTest unit tests, NORMAL flags, separate tree (test.sh only runs them).
cmake -S . -B build-tests "${COMMON_CMAKE[@]}" \
  -DJKQtPlotter_BUILD_TESTS=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS"
cmake --build build-tests -j"$MAYHEM_JOBS"
