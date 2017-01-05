//
//  ALOpusEncoder.m
//  AudioLogger-iOS
//
//  Created by Bryan on 1/4/17.
//  Copyright © 2017 bcattle. All rights reserved.
//

#import "ALOpusEncoder.h"
#import <oggz/oggz.h>

@interface ALOpusEncoder ()
@property (nonatomic, assign) OGGZ *oggz;
@property (nonatomic, assign) long serialNo;
@property (nonatomic, assign) ogg_int64_t packetno;
@end

@implementation ALOpusEncoder

- (instancetype)initWithFilename:(NSString*)filename
{
    self = [super init];
    if (self) {
        _oggz = oggz_open([filename UTF8String], OGGZ_WRITE);
        if (_oggz == NULL) {
            NSLog(@"Error opening output file");
            return nil;
        }
        _serialNo = oggz_serialno_new(_oggz);
        _packetno = 0;
        [self writeOggHeader];
        // Ready to go!
    }
    return self;
}

-(void) close {
    int err = oggz_close(_oggz);
    if (err != 0) {
        NSLog(@"ERROR oggz_close: %d", err);
    }
}

-(void) writeOggHeader {
    // https://wiki.xiph.org/OggOpus
    
    ogg_packet op;
    char s[][9] = {"OpusHead", "OpusTags"};
    int err;
    long wrote;
    
    for (int i = 0; i < 2; i++) {
        op = (ogg_packet){
            .packet = (unsigned char *)s[i],
            .bytes = strlen(s[i]),
            .b_o_s = _packetno == 0,
            .e_o_s = 0,
            .granulepos = 0,
            .packetno = _packetno,
        };
        _packetno++;
        err = oggz_write_feed(_oggz, &op, _serialNo, OGGZ_FLUSH_BEFORE | OGGZ_FLUSH_AFTER, NULL);
        if (err != 0) {
            NSLog(@"ERROR oggz_write_feed: %d", err);
            break;
        }
        // Write the packet
        while ((wrote = oggz_write(_oggz, 32)) > 0);
        if (wrote < 0) {
            NSLog(@"ERROR oggz_write: %d", err);
            break;
        }
    }
}

-(void) writeOggPacketWithPayload:(NSString*)packet {
    
}

@end
