//
//  ALOpusEncoder.h
//  AudioLogger-iOS
//
//  Created by Bryan on 1/4/17.
//  Copyright © 2017 bcattle. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ALOpusEncoder : NSObject
-(instancetype)init NS_UNAVAILABLE;
-(instancetype __nullable)initWithFilename:(NSString*)filename;
-(void)startWriting;
-(void)stopWriting;
//-(void) close;
@end

NS_ASSUME_NONNULL_END
