// JKQTPMathParser: expression text -> tokenizer + recursive-descent parse -> evaluate().
#include "jkqtmath/jkqtpmathparser.h"
#include <cstddef>
#include <cstdint>
#include <string>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size > 4096) return 0;
    const std::string prog(reinterpret_cast<const char *>(data), size);
    JKQTPMathParser mp;  // fresh per input: variables/functions don't leak across inputs
    JKQTPMathParser::jkmpNode *n = nullptr;
    try {
        n = mp.parse(prog);
        if (n) n->evaluate();
    } catch (JKQTPMathParser::jkmpException &) {
        // the parser's documented error channel (jkmpError throws jkmpException)
    }
    delete n;
    return 0;
}
