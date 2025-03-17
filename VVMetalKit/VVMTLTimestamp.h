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




/**		This protocol describes the properties and methods an object is required to implement to allow it to be timestamped (when it should appear and how long it should stay visible for)
*/




@protocol VVMTLTimestamp

@property (assign,readwrite) CMTime time;
@property (assign,readwrite) CMTime duration;

- (BOOL) matchesTimestamp:(id<VVMTLTimestamp>)n;

@end




#endif /* MTLTimestamp_h */
