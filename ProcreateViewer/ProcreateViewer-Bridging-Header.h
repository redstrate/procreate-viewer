/*
 Here we import Apple's functions to decode __CFKeyedArchiverUID types.
 */
#include <CoreFoundation/CFBase.h>

typedef const struct __CFKeyedArchiverUID * CFKeyedArchiverUIDRef;

extern uint32_t _CFKeyedArchiverUIDGetValue(CFKeyedArchiverUIDRef uid);
