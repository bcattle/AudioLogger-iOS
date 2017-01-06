//
//  ALOpusEncoder.m
//  AudioLogger-iOS
//
//  Created by Bryan on 1/4/17.
//  Copyright © 2017 bcattle. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <EZAudio/EZAudio.h>
#import <oggz/oggz.h>
#import "OpusKit.h"
#import "ALOpusEncoder.h"

@interface ALOpusEncoder () <EZMicrophoneDelegate>
@property (nonatomic, strong) EZMicrophone *microphone;
@property (nonatomic, strong) OKEncoder *opusEncoder;
@property (nonatomic, assign) OGGZ *oggz;
@property (nonatomic, assign) long serialNo;
@property (nonatomic, assign) long totalSamples;
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
    }
    return self;
}

-(void) startWriting {
    [self setupMicrophone];
}

-(void)dealloc {
    [self stopWriting];
}

-(void) close {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    int err = oggz_close(_oggz);
    if (err != 0) {
        NSLog(@"ERROR oggz_close: %d", err);
    }
}

- (void) setupMicrophone {
    NSError *error = nil;
    int preferredSampleRate = kOpusKitSampleRate_48000;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setPreferredSampleRate:preferredSampleRate error:&error];
    if (error) {
        NSLog(@"Error setting preferred sample rate to %d: %@", preferredSampleRate, error);
        return;
    }
    AudioStreamBasicDescription micFormat = (AudioStreamBasicDescription){
        .mFormatID          = kAudioFormatLinearPCM,
        .mFormatFlags       = kAudioFormatFlagIsBigEndian|kAudioFormatFlagIsPacked|kAudioFormatFlagIsSignedInteger,
        .mSampleRate        = 48000,
        .mChannelsPerFrame  = 1,
        .mBitsPerChannel    = 16,
        .mBytesPerPacket    = 2,
        .mFramesPerPacket   = 1,
        .mBytesPerFrame     = 2,
    };
//    AudioStreamBasicDescription micFormat = [EZAudioUtilities monoCanonicalFormatWithSampleRate:48000];
    self.microphone = [[EZMicrophone alloc] initWithMicrophoneDelegate:self withAudioStreamBasicDescription:micFormat];
//    self.microphone = [[EZMicrophone alloc] initWithMicrophoneDelegate:self];
//    AudioStreamBasicDescription micFormat = [self.microphone audioStreamBasicDescription];
    [self setupOpusFromABSD:micFormat];
    if (self.opusEncoder == nil) return;
    self.opusEncoder.bitrate = 22000;
    [self.microphone startFetchingAudio];
}

- (void) setupOpusFromABSD:(AudioStreamBasicDescription)absd {
    NSError *error = nil;
    self.opusEncoder = [OKEncoder encoderForASBD:absd application:kOpusKitApplicationAudio error:&error];
    if (error) {
        NSLog(@"Error setting up opus encoder: %@", error);
    }
}

-(void) writeOggHeader {
    // https://wiki.xiph.org/OggOpus
    
    ogg_packet op;
    //                                             | ver |#ch | pre-skp | sample rate (inf) |  gain  | ch map |
    uint8_t s1[19] = {'O','p','u','s','H','e','a','d', 0x1, 0x1, 0x0, 0x0, 0xb, 0xb, 0x8, 0x0, 0x0, 0x0, 0x0};
    uint8_t s2[8] = {'O','p','u','s','T','a','g','s'};
    uint8_t *s[] = {s1, s2};
    uint8_t sizes[] = {19, 8};
    int err;
    long wrote;
    
    for (int i = 0; i < 2; i++) {
        op = (ogg_packet){
            .packet = (unsigned char *)s[i],
            .bytes = sizes[i],
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

-(void)stopWriting {
    [_microphone stopFetchingAudio];
    [self close];
}

#pragma mark - Microphone Delegate

- (void)    microphone:(EZMicrophone *)microphone
         hasBufferList:(AudioBufferList *)bufferList
        withBufferSize:(UInt32)bufferSize
  withNumberOfChannels:(UInt32)numberOfChannels
{
    //NSLog(@"Got mic data: %u bytes", (unsigned int)bufferSize);
    ogg_int64_t curr_samples = _totalSamples;
    _totalSamples += bufferSize;
    NSLog(@"Got %ld samples, %.3f sec", _totalSamples, _totalSamples / 48000.0);
    [self.opusEncoder encodeBufferList:bufferList completionBlock:^(NSData *data, NSError *error) {
        if (data) {
            NSLog(@"opus data length: %lu", (unsigned long)data.length);
            // Write the encoded data to the file
            ogg_packet op = (ogg_packet){
                .packet = (unsigned char *)data.bytes,
                .bytes = data.length,
                .b_o_s = _packetno == 0,
                .e_o_s = 0,
                .granulepos = curr_samples,
                .packetno = _packetno,
            };
            _packetno++;
            oggz_write_feed(_oggz, &op, _serialNo, 0, NULL);
            oggz_write(_oggz, data.length);
        } else {
            NSLog(@"Error encoding frame to opus: %@", error);
        }
    }];
}

@end
