/* unix/config.h.  Generated automatically by configure.  */
/* unix/config.h.in.  Generated automatically from configure.in by autoheader.  */
/* config.h (template) */
#ifndef _config_h_
#define _config_h_

/* @FOO@ : Define or undefine value FOO as appropriate. */

/* Define if your C++ compiler implements exception-handling.  */
#define HAVE_EXCEPTIONS 1

/* Define if you have the <strstrea.h> header file.  */
/* #undef HAVE_STRSTREA_H */

/* Define if you have the strncasecmp function.  */
#ifndef HAVE_STRNCASECMP 
#define HAVE_STRNCASECMP 
#endif

/* Define if you have the strcasecmp function.  */
#ifndef HAVE_STRCASECMP 
#define HAVE_STRCASECMP 
#endif

/* Define if standard member ``ios::binary'' is called ``ios::bin''. */
/* #undef HAVE_IOS_BIN */

/* Define if ``ios::openmode'' is supported. */
#define HAVE_IOS_OPENMODE 1

/* Define if standard member function ``fstream::is_open()'' is not available.  */
/* #undef DONT_HAVE_IS_OPEN */

/* Define whether istream member function ``seekg(streamoff,seekdir).offset()''
   should be used instead of standard ``seekg(streamoff,seekdir); tellg()''.
*/
/* #undef HAVE_SEEKG_OFFSET */



/* Define if the C++ compiler supports BOOL */
#define HAVE_BOOL 1

/* Define if you need the GNU extensions to compile */
/* #undef _GNU_SOURCE */


/* Define if you have the <dlfcn.h> header file. */
/* #undef HAVE_DLFCN_H */

/* Define if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H 1

/* Define if you support file names longer than 14 characters. */
#define HAVE_LONG_FILE_NAMES 1

/* Define if you have the <memory.h> header file. */
#define HAVE_MEMORY_H 1

/* Define if you have the <stdbool.h> header file. */
#define HAVE_STDBOOL_H 1

/* Define if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1

/* Define if you have the <stdlib.h> header file. */
#define HAVE_STDLIB_H 1

/* Define if you have the <string.h> header file. */
#define HAVE_STRING_H 1

/* Define if you have the <strings.h> header file. */
#define HAVE_STRINGS_H 1

/* Define if you have the <sys/stat.h> header file. */
#define HAVE_SYS_STAT_H 1

/* Define if you have the <sys/types.h> header file. */
#define HAVE_SYS_TYPES_H 1

/* Define if you have the <unistd.h> header file. */
#define HAVE_UNISTD_H 1

/* Name of package */
#define PACKAGE "libsidplay"

/* The size of a `char', as computed by sizeof. */
#define SIZEOF_CHAR 1

/* The size of a `int', as computed by sizeof. */
#define SIZEOF_INT 4

/* The number of bytes in type long */
/* #undef SIZEOF_LONG */

/* The size of a `long int', as computed by sizeof. */
#define SIZEOF_LONG_INT 4

/* The number of bytes in type short */
/* #undef SIZEOF_SHORT */

/* The size of a `short int', as computed by sizeof. */
#define SIZEOF_SHORT_INT 2

/* The number of bytes in type void* */
/* #undef SIZEOF_VOIDP */

/* Define if you have the ANSI C header files. */
#define STDC_HEADERS 1

/* Version number of package */
#define VERSION "2.1.0"

/* Define if your processor stores words with the most significant byte first
   (like Motorola and SPARC, unlike Intel and VAX). */

// [AV]
#include "TargetConditionals.h"
   
#if TARGET_RT_LITTLE_ENDIAN
	#undef WORDS_BIGENDIAN
#else
	#define WORDS_BIGENDIAN 1
#endif


#endif /* _config_h_ */
