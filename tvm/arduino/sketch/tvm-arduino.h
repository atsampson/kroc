#ifndef TVM_ARDUINO_H
#define TVM_ARDUINO_H

// Define for lots of useful printed-out stuff.
// #define DEBUG

#include <WProgram.h>

// The Wiring stuff defines BYTE as 0, but the Transterpreter headers use it as
// a type name.
#undef BYTE

extern "C" {
	#include <tvm.h>
}

//{{{  debug.cpp
extern void hexprint(int n);
//}}}
//{{{  ffi.cpp
extern "C" {
	extern SFFI_FUNCTION sffi_table[];
	extern const int sffi_table_length;
}
//}}}
//{{{  tbc.cpp
extern int init_context_from_tbc (ECTX context, const prog_char *data, WORDPTR memory, UWORD memory_size);
//}}}
//{{{  tvm.cpp
extern int main (void);
//}}}

#endif
