#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h> 


Boolean GetMetadataForFile(void* thisInterface, 
			   CFMutableDictionaryRef attributes, 
			   CFStringRef contentTypeUTI,
			   CFStringRef pathToFile)
{
	// read file header
	const char* filename = CFStringGetCStringPtr(pathToFile, kCFStringEncodingMacRoman);
	char filebuffer[0x7c];
	
	FILE* fp = fopen( filename, "rb" );

	if ( fp == NULL ) {
		return FALSE;
	}

	fread( filebuffer, 1, 0x7c, fp );
	fclose( fp );

	const int maxStringLen = 33;
	char title[maxStringLen];
	char author[maxStringLen];
	char released[maxStringLen];
	unsigned short defaultSubtune;
	unsigned short subTuneCount;

	if (filebuffer[ 0 ] != 'P' && filebuffer[ 0 ] != 'R') {
		return FALSE;
	}

	if ( filebuffer[ 1 ] != 'S' ||
		 filebuffer[ 2 ] != 'I' ||
		 filebuffer[ 3 ] != 'D' ) {
		return FALSE;
	}

	// get subtune information from header
	subTuneCount = *(unsigned short*)(filebuffer + 0x0e);
	defaultSubtune = *(unsigned short*)(filebuffer + 0x10);

#if TARGET_RT_LITTLE_ENDIAN
	subTuneCount = Endian16_Swap(subTuneCount);
	defaultSubtune = Endian16_Swap(defaultSubtune);
#endif		

	// get info strings from header
	memcpy(title, filebuffer + 0x16, 32);
	title[32] = 0;

	memcpy(author, filebuffer + 0x36, 32);
	author[32] = 0;

	memcpy(released, filebuffer + 0x56, 32);
	released[32] = 0;
	
	// create CFStrings from strings in header
	CFStringRef titleStringRef = CFStringCreateWithCString( NULL, title, kCFStringEncodingISOLatin1 );
	CFStringRef authorStringRef = CFStringCreateWithCString( NULL, author, kCFStringEncodingISOLatin1 );
	CFStringRef releasedStringRef = CFStringCreateWithCString( NULL, released, kCFStringEncodingISOLatin1 );

	// create CFNumbers from subtune info
	unsigned short tmp = subTuneCount;
	CFNumberRef subTuneCountRef = CFNumberCreate( NULL, kCFNumberShortType, &tmp );
	tmp = defaultSubtune;
	CFNumberRef defaultSubtuneRef = CFNumberCreate( NULL, kCFNumberShortType, &tmp );
	
	// create single-item author array
	CFMutableArrayRef authorsArray = CFArrayCreateMutable(kCFAllocatorDefault, 1, &kCFTypeArrayCallBacks);
	CFArrayAppendValue(authorsArray, authorStringRef);

	// set all attribute key/value pairs
    CFDictionarySetValue(attributes, kMDItemTitle, titleStringRef);
    CFDictionarySetValue(attributes, kMDItemComposer, authorStringRef);
	CFDictionarySetValue(attributes, kMDItemAuthors, authorsArray);
    CFDictionarySetValue(attributes, CFSTR("org_sidmusic_Released"), releasedStringRef);
    CFDictionarySetValue(attributes, CFSTR("org_sidmusic_SubtuneCount"), subTuneCountRef);
    CFDictionarySetValue(attributes, CFSTR("org_sidmusic_DefaultSubtune"), defaultSubtuneRef);

	CFRelease(titleStringRef);
	CFRelease(authorStringRef);
	CFRelease(authorsArray);
	CFRelease(releasedStringRef);
	CFRelease(subTuneCountRef);
	CFRelease(defaultSubtuneRef);

    return TRUE;
}
