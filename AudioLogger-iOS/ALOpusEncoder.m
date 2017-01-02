/* Copyright (C)2002-2011 Jean-Marc Valin
 Copyright (C)2007-2013 Xiph.Org Foundation
 Copyright (C)2008-2013 Gregory Maxwell
 File: opusenc.c
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

//
//  ALOpusEncoder.m
//  AudioLogger-iOS
//
//  Created by Bryan on 1/1/17.
//  Copyright © 2017 bcattle. All rights reserved.
//

#import "ALOpusEncoder.h"

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdio.h>
#include <getopt.h>

#include <stdlib.h>
#include <string.h>
#if (!defined WIN32 && !defined _WIN32) || defined(__MINGW32__)
#include <unistd.h>
#include <time.h>
#endif
#include <math.h>

#ifdef _MSC_VER
#define snprintf _snprintf
#endif

# define I64FORMAT "lld"
# define fopen_utf8(_x,_y) fopen((_x),(_y))
# define argc_utf8 argc
# define argv_utf8 argv

#include <libopus/opus.h>
#include <libopus/opus_multistream.h>
#include <ogg/ogg.h>
//#include "wav_io.h"

#include "opus_header.h"
#include "opusenc.h"
#include "diag_range.h"
#include "cpusupport.h"

#ifdef VALGRIND
#include <valgrind/memcheck.h>
#define VG_UNDEF(x,y) VALGRIND_MAKE_MEM_UNDEFINED((x),(y))
#define VG_CHECK(x,y) VALGRIND_CHECK_MEM_IS_DEFINED((x),(y))
#else
#define VG_UNDEF(x,y)
#define VG_CHECK(x,y)
#endif

static void comment_init(char **comments, int* length, const char *vendor_string);
static void comment_pad(char **comments, int* length, int amount);

/*Write an Ogg page to a file pointer*/
static inline int oe_write_page(ogg_page *page, FILE *fp)
{
    int written;
    written=fwrite(page->header,1,page->header_len, fp);
    written+=fwrite(page->body,1,page->body_len, fp);
    return written;
}

#define MAX_FRAME_BYTES 61295
#define IMIN(a,b) ((a) < (b) ? (a) : (b))   /**< Minimum int value.   */
#define IMAX(a,b) ((a) > (b) ? (a) : (b))   /**< Maximum int value.   */


@implementation ALOpusEncoder {
//    input_format raw_format;
    
    OpusMSEncoder      *st;
    const char         *opus_version;
    unsigned char      *packet;
    float              *input;
    /*I/O*/
    oe_enc_opt         inopt;
//    const input_format *in_format;
//    char               *outFile;
    NSString           *outFile;
    FILE               *fout;
    ogg_stream_state   os;
    ogg_page           og;
    ogg_packet         op;
    ogg_int64_t        last_granulepos;
    ogg_int64_t        enc_granulepos;
    ogg_int64_t        original_samples;
    ogg_int32_t        _id;
    int                last_segments;
    int                eos;
    OpusHeader         header;
    /*Counters*/
    opus_int64         nb_encoded;
    opus_int64         bytes_written;
    opus_int64         pages_out;
    opus_int64         total_bytes;
    opus_int64         total_samples;
    opus_int32         nbBytes;
    opus_int32         nb_samples;
    opus_int32         peak_bytes;
    opus_int32         min_bytes;
    time_t             start_time;
    time_t             stop_time;
    time_t             last_spin;
    int                last_spin_len;
}

-(instancetype)initWithOutputFilename:(NSString*)filename {
    self = [super init];
    if (self) {
//        raw_format = (input_format){NULL, 0, raw_open, wav_close, "raw",N_("RAW file reader")};
        
        last_granulepos=0;
        enc_granulepos=0;
        original_samples=0;
        _id=-1;
        last_segments=0;
        eos=0;
        /*Counters*/
        nb_encoded=0;
        bytes_written=0;
        pages_out=0;
        total_bytes=0;
        total_samples=0;
        peak_bytes=0;
        last_spin=0;
        last_spin_len=0;
        /*Settings*/
        outFile = filename;
        _bitrate=-1;
        _rate=48000;
        _coding_rate=48000;
        _frame_size=960;
        _chan=2;
        _with_hard_cbr=0;
        _with_cvbr=0;
        _expect_loss=0;
        _complexity=10;
//        _downmix=0;
        _opt_ctls=0;
        _max_ogg_delay=48000; /*48kHz samples*/
        _seen_file_icons=0;
        _comment_padding=512;
        _lookahead=0;
        
        if(query_cpu_support()){
            fprintf(stderr,"\n\n** WARNING: This program was compiled with SSE%s\n",query_cpu_support()>1?"2":"");
            fprintf(stderr,"            but this CPU claims to lack these instructions. **\n\n");
        }
        
        _opt_ctls_ctlval=NULL;
//        in_format=NULL;

        // Next step: set all configuration options and call `configure`
    }
    return self;
}

// Make all changes to settings before calling `configure`
-(void) configure {
    inopt.channels=_chan;
    inopt.rate=_coding_rate=_rate;
    /* 0 dB gain is recommended unless you know what you're doing */
    inopt.gain=0;
    inopt.samplesize=16;
    inopt.endianness=0;
    inopt.rawmode=0;
    inopt.ignorelength=0;
    inopt.copy_comments=1;
    inopt.copy_pictures=1;
    
    start_time = time(NULL);
//    srand(((getpid()&65535)<<15)^start_time);
//    _serialno=rand();
    _serialno=arc4random();
    
    opus_version=opus_get_version_string();
    /*Vendor string should just be the encoder library,
     the ENCODER comment specifies the tool used.*/
    comment_init(&inopt.comments, &inopt.comments_length, opus_version);
    comment_add(&inopt.comments, &inopt.comments_length, "ENCODER", "opusenc from AudioLogger-iOS");
    
//    if(_downmix==0&&inopt.channels>2&&_bitrate>0&&_bitrate<(16000*inopt.channels)){
//        if(!quiet)fprintf(stderr,"Notice: Surround bitrate less than 16kbit/sec/channel, downmixing.\n");
//        _downmix=inopt.channels>8?1:2;
//    }
    
//    if(_downmix>0&&_downmix<inopt.channels)_downmix=setup_downmix(&inopt,_downmix);
//    else _downmix=0;
    
    _rate=inopt.rate;
    _chan=inopt.channels;
    inopt.skip=0;
    
    /*In order to code the complete length we'll need to do a little padding*/
    setup_padder(&inopt,&original_samples);
    
    if(_rate>24000)_coding_rate=48000;
    else if(_rate>16000)_coding_rate=24000;
    else if(_rate>12000)_coding_rate=16000;
    else if(_rate>8000)_coding_rate=12000;
    else _coding_rate=8000;
    
    _frame_size=_frame_size/(48000/_coding_rate);
    
    // For simplicity, we don't do resampling, so these should be equal
    assert(_rate == _coding_rate);
    
    /*Scale the resampler complexity, but only for 48000 output because
     the near-cutoff behavior matters a lot more at lower rates.*/
//    if(_rate!=_coding_rate)setup_resample(&inopt,_coding_rate==48000?(_complexity+1)/2:5,_coding_rate);
    
//    if(_rate!=_coding_rate&&_complexity!=10&&!quiet){
//        fprintf(stderr,"Notice: Using resampling with complexity<10.\n");
//        fprintf(stderr,"Opusenc is fastest with 48, 24, 16, 12, or 8kHz input.\n\n");
//    }
    
    /*OggOpus headers*/ /*FIXME: broke forcemono*/
    header.channels=_chan;
    header.channel_mapping=header.channels>8?255:_chan>2;
    header.input_sample_rate=_rate;
    header.gain=inopt.gain;
    
    [self setupEncoder];
    [self setupStreamAndWriteHeader];
    
    eos=0;
    nb_samples=-1;
    
    // Ready to encode!
}

-(void) setupEncoder {
    int i, ret;
    
    /*Initialize OPUS encoder*/
    /*Framesizes <10ms can only use the MDCT modes, so we switch on RESTRICTED_LOWDELAY
     to save the extra 2.5ms of codec lookahead when we'll be using only small frames.*/
    st=opus_multistream_surround_encoder_create(_coding_rate, _chan, header.channel_mapping, &header.nb_streams, &header.nb_coupled,
                                                header.stream_map, _frame_size<480/(48000/_coding_rate)?OPUS_APPLICATION_RESTRICTED_LOWDELAY:OPUS_APPLICATION_AUDIO, &ret);
    if(ret!=OPUS_OK){
        fprintf(stderr, "Error cannot create encoder: %s\n", opus_strerror(ret));
        exit(1);
    }
    
    min_bytes=_max_frame_bytes=(1275*3+7)*header.nb_streams;
    packet=malloc(sizeof(unsigned char)*_max_frame_bytes);
    if(packet==NULL){
        fprintf(stderr,"Error allocating packet buffer.\n");
        exit(1);
    }
    
    if(_bitrate<0){
        /*Lower default rate for sampling rates [8000-44100) by a factor of (rate+16k)/(64k)*/
        _bitrate=((64000*header.nb_streams+32000*header.nb_coupled)*
                 (IMIN(48,IMAX(8,((_rate<44100?_rate:48000)+1000)/1000))+16)+32)>>6;
    }
    
    if(_bitrate>(1024000*_chan)||_bitrate<500){
        fprintf(stderr,"Error: Bitrate %d bits/sec is insane.\nDid you mistake bits for kilobits?\n",_bitrate);
        fprintf(stderr,"--bitrate values from 6-256 kbit/sec per channel are meaningful.\n");
        exit(1);
    }
    _bitrate=IMIN(_chan*256000,_bitrate);
    
    ret=opus_multistream_encoder_ctl(st, OPUS_SET_BITRATE(_bitrate));
    if(ret!=OPUS_OK){
        fprintf(stderr,"Error OPUS_SET_BITRATE returned: %s\n",opus_strerror(ret));
        exit(1);
    }
    
    ret=opus_multistream_encoder_ctl(st, OPUS_SET_VBR(!_with_hard_cbr));
    if(ret!=OPUS_OK){
        fprintf(stderr,"Error OPUS_SET_VBR returned: %s\n",opus_strerror(ret));
        exit(1);
    }
    
    if(!_with_hard_cbr){
        ret=opus_multistream_encoder_ctl(st, OPUS_SET_VBR_CONSTRAINT(_with_cvbr));
        if(ret!=OPUS_OK){
            fprintf(stderr,"Error OPUS_SET_VBR_CONSTRAINT returned: %s\n",opus_strerror(ret));
            exit(1);
        }
    }
    
    ret=opus_multistream_encoder_ctl(st, OPUS_SET_COMPLEXITY(_complexity));
    if(ret!=OPUS_OK){
        fprintf(stderr,"Error OPUS_SET_COMPLEXITY returned: %s\n",opus_strerror(ret));
        exit(1);
    }
    
    ret=opus_multistream_encoder_ctl(st, OPUS_SET_PACKET_LOSS_PERC(_expect_loss));
    if(ret!=OPUS_OK){
        fprintf(stderr,"Error OPUS_SET_PACKET_LOSS_PERC returned: %s\n",opus_strerror(ret));
        exit(1);
    }
    
#ifdef OPUS_SET_LSB_DEPTH
    ret=opus_multistream_encoder_ctl(st, OPUS_SET_LSB_DEPTH(IMAX(8,IMIN(24,inopt.samplesize))));
    if(ret!=OPUS_OK){
        fprintf(stderr,"Warning OPUS_SET_LSB_DEPTH returned: %s\n",opus_strerror(ret));
    }
#endif
    
    /*This should be the last set of CTLs, except the lookahead get, so it can override the defaults.*/
    for(i=0;i<_opt_ctls;i++){
        int target=_opt_ctls_ctlval[i*3];
        if(target==-1){
            ret=opus_multistream_encoder_ctl(st,_opt_ctls_ctlval[i*3+1],_opt_ctls_ctlval[i*3+2]);
            if(ret!=OPUS_OK){
                fprintf(stderr,"Error opus_multistream_encoder_ctl(st,%d,%d) returned: %s\n",_opt_ctls_ctlval[i*3+1],_opt_ctls_ctlval[i*3+2],opus_strerror(ret));
                exit(1);
            }
        }else if(target<header.nb_streams){
            OpusEncoder *oe;
            opus_multistream_encoder_ctl(st,OPUS_MULTISTREAM_GET_ENCODER_STATE(i,&oe));
            ret=opus_encoder_ctl(oe, _opt_ctls_ctlval[i*3+1],_opt_ctls_ctlval[i*3+2]);
            if(ret!=OPUS_OK){
                fprintf(stderr,"Error opus_encoder_ctl(st[%d],%d,%d) returned: %s\n",target,_opt_ctls_ctlval[i*3+1],_opt_ctls_ctlval[i*3+2],opus_strerror(ret));
                exit(1);
            }
        }else{
            fprintf(stderr,"Error --set-ctl-int target stream %d is higher than the maximum stream number %d.\n",target,header.nb_streams-1);
            exit(1);
        }
    }
    
    /*We do the lookahead check late so user CTLs can change it*/
    ret=opus_multistream_encoder_ctl(st, OPUS_GET_LOOKAHEAD(&_lookahead));
    if(ret!=OPUS_OK){
        fprintf(stderr,"Error OPUS_GET_LOOKAHEAD returned: %s\n",opus_strerror(ret));
        exit(1);
    }
    inopt.skip+=_lookahead;
    /*Regardless of the rate we're coding at the ogg timestamping/skip is
     always timed at 48000.*/
    header.preskip=inopt.skip*(48000./_coding_rate);
    /* Extra samples that need to be read to compensate for the pre-skip */
    inopt.extraout=(int)header.preskip*(_rate/48000.);
    
    fout=fopen_utf8([outFile cStringUsingEncoding:NSASCIIStringEncoding], "wb");
    if(!fout){
        perror([outFile cStringUsingEncoding:NSASCIIStringEncoding]);
        exit(1);
    }
}

-(void) setupStreamAndWriteHeader {
    int ret;
    
    /*Initialize Ogg stream struct*/
    if(ogg_stream_init(&os, _serialno)==-1){
        fprintf(stderr,"Error: stream init failed\n");
        exit(1);
    }
    
    /*Write header*/
    {
        unsigned char header_data[100];
        int packet_size=opus_header_to_packet(&header, header_data, 100);
        op.packet=header_data;
        op.bytes=packet_size;
        op.b_o_s=1;
        op.e_o_s=0;
        op.granulepos=0;
        op.packetno=0;
        ogg_stream_packetin(&os, &op);
        
        while((ret=ogg_stream_flush(&os, &og))){
            if(!ret)break;
            ret=oe_write_page(&og, fout);
            if(ret!=og.header_len+og.body_len){
                fprintf(stderr,"Error: failed writing header to output stream\n");
                exit(1);
            }
            bytes_written+=ret;
            pages_out++;
        }
        
        comment_pad(&inopt.comments, &inopt.comments_length, _comment_padding);
        op.packet=(unsigned char *)inopt.comments;
        op.bytes=inopt.comments_length;
        op.b_o_s=0;
        op.e_o_s=0;
        op.granulepos=0;
        op.packetno=1;
        ogg_stream_packetin(&os, &op);
    }
    
    /* writing the rest of the opus header packets */
    while((ret=ogg_stream_flush(&os, &og))){
        if(!ret)break;
        ret=oe_write_page(&og, fout);
        if(ret!=og.header_len + og.body_len){
            fprintf(stderr,"Error: failed writing header to output stream\n");
            exit(1);
        }
        bytes_written+=ret;
        pages_out++;
    }
    
    free(inopt.comments);
    
    input=malloc(sizeof(float)*_frame_size*_chan);
    if(input==NULL){
        fprintf(stderr,"Error: couldn't allocate sample buffer.\n");
        exit(1);
    }
}

-(void) runEncodingLoop {
    int i, ret;
    
    // Setup the function pointer to read samples from the delegate
    //  --> typedef long (*audio_read_func)(void *src, float *buffer, int samples);
#warning todo
    
    /*Main encoding loop (one frame per iteration)*/
    while(!op.e_o_s){
        int size_segments,cur_frame_size;
        _id++;
        
        if(nb_samples<0){
            nb_samples = inopt.read_samples(inopt.readdata,input,_frame_size);
            total_samples+=nb_samples;
            if(nb_samples<_frame_size)op.e_o_s=1;
            else op.e_o_s=0;
        }
        op.e_o_s|=eos;
        
        if(start_time==0){
            start_time = time(NULL);
        }
        
        cur_frame_size=_frame_size;
        
        /*No fancy end padding, just fill with zeros for now.*/
        if(nb_samples<cur_frame_size)for(i=nb_samples*_chan;i<cur_frame_size*_chan;i++)input[i]=0;
        
        /*Encode current frame*/
        VG_UNDEF(packet,max_frame_bytes);
        VG_CHECK(input,sizeof(float)*chan*cur_frame_size);
        nbBytes=opus_multistream_encode_float(st, input, cur_frame_size, packet, _max_frame_bytes);
        if(nbBytes<0){
            fprintf(stderr, "Encoding failed: %s. Aborting.\n", opus_strerror(nbBytes));
            break;
        }
        VG_CHECK(packet,nbBytes);
        VG_UNDEF(input,sizeof(float)*chan*cur_frame_size);
        nb_encoded+=cur_frame_size;
        enc_granulepos+=cur_frame_size*48000/_coding_rate;
        total_bytes+=nbBytes;
        size_segments=(nbBytes+255)/255;
        peak_bytes=IMAX(nbBytes,peak_bytes);
        min_bytes=IMIN(nbBytes,min_bytes);
        
        /*Flush early if adding this packet would make us end up with a
         continued page which we wouldn't have otherwise.*/
        while((((size_segments<=255)&&(last_segments+size_segments>255))||
               (enc_granulepos-last_granulepos>_max_ogg_delay))&&
              ogg_stream_flush_fill(&os, &og,255*255)){
            if(ogg_page_packets(&og)!=0)last_granulepos=ogg_page_granulepos(&og);
            last_segments-=og.header[26];
            ret=oe_write_page(&og, fout);
            if(ret!=og.header_len+og.body_len){
                fprintf(stderr,"Error: failed writing data to output stream\n");
                exit(1);
            }
            bytes_written+=ret;
            pages_out++;
        }
        
        /*The downside of early reading is if the input is an exact
         multiple of the frame_size you'll get an extra frame that needs
         to get cropped off. The downside of late reading is added delay.
         If your ogg_delay is 120ms or less we'll assume you want the
         low delay behavior.*/
        if((!op.e_o_s)&&_max_ogg_delay>5760){
            nb_samples = inopt.read_samples(inopt.readdata,input,_frame_size);
            total_samples+=nb_samples;
            if(nb_samples<_frame_size)eos=1;
            if(nb_samples==0)op.e_o_s=1;
        } else nb_samples=-1;
        
        op.packet=(unsigned char *)packet;
        op.bytes=nbBytes;
        op.b_o_s=0;
        op.granulepos=enc_granulepos;
        if(op.e_o_s){
            /*We compute the final GP as ceil(len*48k/input_rate). When a resampling
             decoder does the matching floor(len*input/48k) conversion the length will
             be exactly the same as the input.*/
            op.granulepos=((original_samples*48000+_rate-1)/_rate)+header.preskip;
        }
        op.packetno=2+_id;
        ogg_stream_packetin(&os, &op);
        last_segments+=size_segments;
        
        /*If the stream is over or we're sure that the delayed flush will fire,
         go ahead and flush now to avoid adding delay.*/
        while((op.e_o_s||(enc_granulepos+(_frame_size*48000/_coding_rate)-last_granulepos>_max_ogg_delay)||
               (last_segments>=255))?
              ogg_stream_flush_fill(&os, &og,255*255):
              ogg_stream_pageout_fill(&os, &og,255*255)){
            if(ogg_page_packets(&og)!=0)last_granulepos=ogg_page_granulepos(&og);
            last_segments-=og.header[26];
            ret=oe_write_page(&og, fout);
            if(ret!=og.header_len+og.body_len){
                fprintf(stderr,"Error: failed writing data to output stream\n");
                exit(1);
            }
            bytes_written+=ret;
            pages_out++;
        }
    }
    stop_time = time(NULL);
    
    [self finishEncoding];
}

-(void) finishEncoding {
    opus_multistream_encoder_destroy(st);
    ogg_stream_clear(&os);
    free(packet);
    free(input);
    if(_opt_ctls)free(_opt_ctls_ctlval);
    
//    if(_rate!=_coding_rate)clear_resample(&inopt);
    clear_padder(&inopt);
//    if(_downmix)clear_downmix(&inopt);
//    in_format->close_func(inopt.readdata);
    if(fout)fclose(fout);
}

@end

/*
 Comments will be stored in the Vorbis style.
 It is describled in the "Structure" section of
 http://www.xiph.org/ogg/vorbis/doc/v-comment.html
 
 However, Opus and other non-vorbis formats omit the "framing_bit".
 
 The comment header is decoded as follows:
 1) [vendor_length] = read an unsigned integer of 32 bits
 2) [vendor_string] = read a UTF-8 vector as [vendor_length] octets
 3) [user_comment_list_length] = read an unsigned integer of 32 bits
 4) iterate [user_comment_list_length] times {
 5) [length] = read an unsigned integer of 32 bits
 6) this iteration's user comment = read a UTF-8 vector as [length] octets
 }
 7) done.
 */

#define readint(buf, base) (((buf[base+3]<<24)&0xff000000)| \
((buf[base+2]<<16)&0xff0000)| \
((buf[base+1]<<8)&0xff00)| \
(buf[base]&0xff))
#define writeint(buf, base, val) do{ buf[base+3]=((val)>>24)&0xff; \
buf[base+2]=((val)>>16)&0xff; \
buf[base+1]=((val)>>8)&0xff; \
buf[base]=(val)&0xff; \
}while(0)

static void comment_init(char **comments, int* length, const char *vendor_string)
{
    /*The 'vendor' field should be the actual encoding library used.*/
    int vendor_length=strlen(vendor_string);
    int user_comment_list_length=0;
    int len=8+4+vendor_length+4;
    char *p=(char*)malloc(len);
    if(p==NULL){
        fprintf(stderr, "malloc failed in comment_init()\n");
        exit(1);
    }
    memcpy(p, "OpusTags", 8);
    writeint(p, 8, vendor_length);
    memcpy(p+12, vendor_string, vendor_length);
    writeint(p, 12+vendor_length, user_comment_list_length);
    *length=len;
    *comments=p;
}

void comment_add(char **comments, int* length, char *tag, char *val)
{
    char* p=*comments;
    int vendor_length=readint(p, 8);
    int user_comment_list_length=readint(p, 8+4+vendor_length);
    int tag_len=(tag?strlen(tag)+1:0);
    int val_len=strlen(val);
    int len=(*length)+4+tag_len+val_len;
    
    p=(char*)realloc(p, len);
    if(p==NULL){
        fprintf(stderr, "realloc failed in comment_add()\n");
        exit(1);
    }
    
    writeint(p, *length, tag_len+val_len);      /* length of comment */
    if(tag){
        memcpy(p+*length+4, tag, tag_len);        /* comment tag */
        (p+*length+4)[tag_len-1] = '=';           /* separator */
    }
    memcpy(p+*length+4+tag_len, val, val_len);  /* comment */
    writeint(p, 8+4+vendor_length, user_comment_list_length+1);
    *comments=p;
    *length=len;
}

static void comment_pad(char **comments, int* length, int amount)
{
    if(amount>0){
        int i;
        int newlen;
        char* p=*comments;
        /*Make sure there is at least amount worth of padding free, and
         round up to the maximum that fits in the current ogg segments.*/
        newlen=(*length+amount+255)/255*255-1;
        p=realloc(p,newlen);
        if(p==NULL){
            fprintf(stderr,"realloc failed in comment_pad()\n");
            exit(1);
        }
        for(i=*length;i<newlen;i++)p[i]=0;
        *comments=p;
        *length=newlen;
    }
}
#undef readint
#undef writeint

// From audio-in.c

#import "lpc.h"

typedef struct {
    audio_read_func real_reader;
    void *real_readdata;
    ogg_int64_t *original_samples;
    int channels;
    int lpc_ptr;
    int *extra_samples;
    float *lpc_out;
} padder;

/* Read audio data, appending padding to make up any gap
 * between the available and requested number of samples
 * with LPC-predicted data to minimize the pertubation of
 * the valid data that falls in the same frame.
 */
static long read_padder(void *data, float *buffer, int samples) {
    padder *d = data;
    long in_samples = d->real_reader(d->real_readdata, buffer, samples);
    int i, extra=0;
    const int lpc_order=32;
    
    if(d->original_samples)*d->original_samples+=in_samples;
    
    if(in_samples<samples){
        if(d->lpc_ptr<0){
            d->lpc_out=calloc(d->channels * *d->extra_samples, sizeof(*d->lpc_out));
            if(in_samples>lpc_order*2){
                float *lpc=alloca(lpc_order*sizeof(*lpc));
                for(i=0;i<d->channels;i++){
                    vorbis_lpc_from_data(buffer+i,lpc,in_samples,lpc_order,d->channels);
                    vorbis_lpc_predict(lpc,buffer+i+(in_samples-lpc_order)*d->channels,
                                       lpc_order,d->lpc_out+i,*d->extra_samples,d->channels);
                }
            }
            d->lpc_ptr=0;
        }
        extra=samples-in_samples;
        if(extra>*d->extra_samples)extra=*d->extra_samples;
        *d->extra_samples-=extra;
    }
    memcpy(buffer+in_samples*d->channels,d->lpc_out+d->lpc_ptr*d->channels,extra*d->channels*sizeof(*buffer));
    d->lpc_ptr+=extra;
    return in_samples+extra;
}

void setup_padder(oe_enc_opt *opt,ogg_int64_t *original_samples) {
    padder *d = calloc(1, sizeof(padder));
    
    d->real_reader = opt->read_samples;
    d->real_readdata = opt->readdata;
    
    opt->read_samples = read_padder;
    opt->readdata = d;
    d->channels = opt->channels;
    d->extra_samples = &opt->extraout;
    d->original_samples=original_samples;
    d->lpc_ptr = -1;
    d->lpc_out = NULL;
}

void clear_padder(oe_enc_opt *opt) {
    padder *d = opt->readdata;
    
    opt->read_samples = d->real_reader;
    opt->readdata = d->real_readdata;
    
    if(d->lpc_out)free(d->lpc_out);
    free(d);
}

