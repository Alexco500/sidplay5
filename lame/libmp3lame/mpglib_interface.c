/* -*- mode: C; mode: fold -*- */
/*
 *	LAME MP3 encoding engine
 *
 *	Copyright (c) 1999-2000 Mark Taylor
 *	Copyright (c) 2003 Olcios
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

/* $Id: mpglib_interface.c,v 1.26.2.1 2005/11/20 14:08:25 bouvigne Exp $ */

#ifdef HAVE_CONFIG_H
# include <lameconfig.h>
#endif

#ifdef HAVE_MPGLIB

#include <limits.h>
#include <stdlib.h>
#include <assert.h>

#include "interface.h"
#include "lame.h"

#ifdef WITH_DMALLOC
#include <dmalloc.h>
#endif


MPSTR   mp;
plotting_data *mpg123_pinfo = NULL;

int
lame_decode_exit(void)
{
    ExitMP3(&mp);
    return 0;
}


int
lame_decode_init(void)
{
    InitMP3(&mp);
    return 0;
}




/* copy mono samples */
#define COPY_MONO(DST_TYPE, SRC_TYPE)                                                           \
    DST_TYPE *pcm_l = (DST_TYPE *)pcm_l_raw;                                                    \
    SRC_TYPE *p_samples = (SRC_TYPE *)p;                                                        \
    for (i = 0; i < processed_samples; i++)                                                     \
      *pcm_l++ = (DST_TYPE)*p_samples++; 

/* copy stereo samples */
#define COPY_STEREO(DST_TYPE, SRC_TYPE)                                                         \
    DST_TYPE *pcm_l = (DST_TYPE *)pcm_l_raw, *pcm_r = (DST_TYPE *)pcm_r_raw;                    \
    SRC_TYPE *p_samples = (SRC_TYPE *)p;                                                        \
    for (i = 0; i < processed_samples; i++) {                                                   \
      *pcm_l++ = (DST_TYPE)*p_samples++;                                                        \
      *pcm_r++ = (DST_TYPE)*p_samples++;                                                        \
    }   



/*
 * For lame_decode:  return code
 * -1     error
 *  0     ok, but need more data before outputing any samples
 *  n     number of samples output.  either 576 or 1152 depending on MP3 file.
 */

int
lame_decode1_headersB_clipchoice(unsigned char *buffer, int len,
                     char pcm_l_raw[], char pcm_r_raw[], mp3data_struct * mp3data,
                     int *enc_delay, int *enc_padding, 
                     char *p, size_t psize, int decoded_sample_size,
                     int (*decodeMP3_ptr)(PMPSTR,unsigned char *,int,char *,int,int*) )
{
    static const int smpls[2][4] = {
        /* Layer   I    II   III */
        {0, 384, 1152, 1152}, /* MPEG-1     */ 
        {0, 384, 1152, 576} /* MPEG-2(.5) */
    };

    int     processed_bytes;
    int     processed_samples; /* processed samples per channel */
    int     ret;
    int     i;

    mp3data->header_parsed = 0;

    ret =
        (*decodeMP3_ptr)(&mp, buffer, len, p, psize, &processed_bytes);
    /* three cases:  
     * 1. headers parsed, but data not complete
     *       mp.header_parsed==1 
     *       mp.framesize=0           
     *       mp.fsizeold=size of last frame, or 0 if this is first frame
     *
     * 2. headers, data parsed, but ancillary data not complete
     *       mp.header_parsed==1 
     *       mp.framesize=size of frame           
     *       mp.fsizeold=size of last frame, or 0 if this is first frame
     *
     * 3. frame fully decoded:  
     *       mp.header_parsed==0 
     *       mp.framesize=0           
     *       mp.fsizeold=size of frame (which is now the last frame)
     *
     */
    if (mp.header_parsed || mp.fsizeold > 0 || mp.framesize > 0) {
	mp3data->header_parsed = 1;
        mp3data->stereo = mp.fr.stereo;
        mp3data->samplerate = freqs[mp.fr.sampling_frequency];
        mp3data->mode = mp.fr.mode;
        mp3data->mode_ext = mp.fr.mode_ext;
        mp3data->framesize = smpls[mp.fr.lsf][mp.fr.lay];

	/* free format, we need the entire frame before we can determine
	 * the bitrate.  If we haven't gotten the entire frame, bitrate=0 */
        if (mp.fsizeold > 0) /* works for free format and fixed, no overrun, temporal results are < 400.e6 */
            mp3data->bitrate = 8 * (4 + mp.fsizeold) * mp3data->samplerate /
                (1.e3 * mp3data->framesize) + 0.5;
        else if (mp.framesize > 0)
            mp3data->bitrate = 8 * (4 + mp.framesize) * mp3data->samplerate /
                (1.e3 * mp3data->framesize) + 0.5;
        else
            mp3data->bitrate =
                tabsel_123[mp.fr.lsf][mp.fr.lay - 1][mp.fr.bitrate_index];



        if (mp.num_frames > 0) {
            /* Xing VBR header found and num_frames was set */
            mp3data->totalframes = mp.num_frames;
            mp3data->nsamp = mp3data->framesize * mp.num_frames;
            *enc_delay = mp.enc_delay;
            *enc_padding = mp.enc_padding;
        }
    }

    switch (ret) {
    case MP3_OK:
        switch (mp.fr.stereo) {
        case 1: 
            processed_samples = processed_bytes / decoded_sample_size;
            if (decoded_sample_size == sizeof(short)) {
              COPY_MONO(short,short)
            }
            else {
              COPY_MONO(sample_t,FLOAT)                
            }
            break;
        case 2: 
            processed_samples = (processed_bytes / decoded_sample_size) >> 1; 
            if (decoded_sample_size == sizeof(short)) {
              COPY_STEREO(short,short)
            }
            else {
              COPY_STEREO(sample_t,FLOAT)
            }
            break;
        default:
            processed_samples = -1;
            assert(0);
            break;
        }
        break;

    case MP3_NEED_MORE:
        processed_samples = 0;
        break;

    default:
        assert(0);
    case MP3_ERR:
        processed_samples = -1;
        break;

    }

    /*fprintf(stderr,"ok, more, err:  %i %i %i\n", MP3_OK, MP3_NEED_MORE, MP3_ERR );*/
    /*fprintf(stderr,"ret = %i out=%i\n", ret, processed_samples );*/
    return processed_samples;
}


#define OUTSIZE_CLIPPED   4096*sizeof(short)

int
lame_decode1_headersB(unsigned char *buffer,
                     int len,
                     short pcm_l[], short pcm_r[], mp3data_struct * mp3data,
                     int *enc_delay, int *enc_padding)
{
  static char out[OUTSIZE_CLIPPED];

  return lame_decode1_headersB_clipchoice(buffer, len, (char *)pcm_l, (char *)pcm_r, mp3data, enc_delay, enc_padding, out, OUTSIZE_CLIPPED, sizeof(short), decodeMP3 );
}


/* we forbid input with more than 1152 samples per channel for output in the unclipped mode */
#define OUTSIZE_UNCLIPPED 1152*2*sizeof(FLOAT)

int 
lame_decode1_unclipped(unsigned char *buffer, int len, sample_t pcm_l[], sample_t pcm_r[])
{
  static char out[OUTSIZE_UNCLIPPED];
  mp3data_struct mp3data;
  int enc_delay,enc_padding;

  return lame_decode1_headersB_clipchoice(buffer, len, (char *)pcm_l, (char *)pcm_r, &mp3data, &enc_delay, &enc_padding, out, OUTSIZE_UNCLIPPED, sizeof(FLOAT), decodeMP3_unclipped  );
}



/*
 * For lame_decode:  return code
 *  -1     error
 *   0     ok, but need more data before outputing any samples
 *   n     number of samples output.  Will be at most one frame of
 *         MPEG data.  
 */

int
lame_decode1_headers(unsigned char *buffer,
                     int len,
                     short pcm_l[], short pcm_r[], mp3data_struct * mp3data)
{
    int enc_delay,enc_padding;
    return lame_decode1_headersB(buffer,len,pcm_l,pcm_r,mp3data,&enc_delay,&enc_padding);
}


int
lame_decode1(unsigned char *buffer, int len, short pcm_l[], short pcm_r[])
{
    mp3data_struct mp3data;

    return lame_decode1_headers(buffer, len, pcm_l, pcm_r, &mp3data);
}


/*
 * For lame_decode:  return code
 *  -1     error
 *   0     ok, but need more data before outputing any samples
 *   n     number of samples output.  a multiple of 576 or 1152 depending on MP3 file.
 */

int
lame_decode_headers(unsigned char *buffer,
                    int len,
                    short pcm_l[], short pcm_r[], mp3data_struct * mp3data)
{
    int     ret;
    int     totsize = 0;     /* number of decoded samples per channel */

    while (1) {
        switch (ret =
                lame_decode1_headers(buffer, len, pcm_l + totsize,
                                     pcm_r + totsize, mp3data)) {
        case -1:
            return ret;
        case 0:
            return totsize;
        default:
            totsize += ret;
            len = 0;    /* future calls to decodeMP3 are just to flush buffers */
            break;
        }
    }
}


int
lame_decode(unsigned char *buffer, int len, short pcm_l[], short pcm_r[])
{
    mp3data_struct mp3data;

    return lame_decode_headers(buffer, len, pcm_l, pcm_r, &mp3data);
}


#endif

/* end of mpglib_interface.c */

