//
//  ALOpusEncoder.h
//  AudioLogger-iOS
//
//  Created by Bryan on 1/1/17.
//  Copyright © 2017 bcattle. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <libopus/opus_types.h>

@interface ALOpusEncoder : NSObject

// Make all changes to settings before calling `configure`
/*Settings*/
@property (nonatomic, assign) int                max_frame_bytes;
@property (nonatomic, assign) opus_int32         bitrate;
// For simplicity, we don't do resampling, so these should be equal
@property (nonatomic, assign) opus_int32         rate;
@property (nonatomic, assign) opus_int32         coding_rate;
@property (nonatomic, assign) opus_int32         frame_size;
@property (nonatomic, assign) int                chan;
@property (nonatomic, assign) int                with_hard_cbr;
@property (nonatomic, assign) int                with_cvbr;
@property (nonatomic, assign) int                expect_loss;
@property (nonatomic, assign) int                complexity;
//@property (nonatomic, assign) int                downmix;
@property (nonatomic, assign) int                *opt_ctls_ctlval;
@property (nonatomic, assign) int                opt_ctls;
@property (nonatomic, assign) int                max_ogg_delay; /*48kHz samples*/
@property (nonatomic, assign) int                seen_file_icons;
@property (nonatomic, assign) int                comment_padding;
@property (nonatomic, assign) int                serialno;
@property (nonatomic, assign) opus_int32         lookahead;

-(instancetype)initWithOutputFilename:(NSString*)outfile;
// Once all settings are set, call this
-(void) configure;
-(void) runEncodingLoop;

@end
