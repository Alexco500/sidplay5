#ifndef MD5_DEFS_H
#define MD5_DEFS_H

#include <sidconfig.h>

#if defined(SID_WORDS_BIGENDIAN) || defined(XSID_WORDS_BIGENDIAN) || defined(WORD_BIGENDIAN)
#define MD5_WORDS_BIG_ENDIAN
#endif

#endif /* MD5_DEFS_H */
