//
//  VVMTLTimestamp.h
//  VVMetalKit
//
//  Created by testadmin on 6/23/23.
//

#ifndef MTLTimestamp_h
#define MTLTimestamp_h

#import <CoreMedia/CoreMedia.h>

@protocol VVMTLTimestamp;




@protocol VVMTLTimestamp

@property (assign,readwrite) CMTime time;
@property (assign,readwrite) CMTime duration;

- (BOOL) matchesTimestamp:(id<VVMTLTimestamp>)n;

@end




#endif /* MTLTimestamp_h */
