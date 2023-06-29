//
//  VVMTLBuffer.h
//  VVMetalKit
//
//  Created by testadmin on 6/23/23.
//

#ifndef MTLBuffer_h
#define MTLBuffer_h

#import <Metal/Metal.h>

#import "VVMTLImage.h"
#import "VVMTLTimestamp.h"
#import "VVMTLRecycleable.h"
#import "VVMTLRecyclingPool.h"
#import "VVMTLRecycleableDescriptor.h"
#import "VVMTLBufferDescriptor.h"




@protocol VVMTLBuffer <VVMTLTimestamp, VVMTLRecycleable>

+ (instancetype __nonnull) createWithDescriptor:(VVMTLBufferDescriptor * __nonnull)n;

- (instancetype __nonnull) initWithDescriptor:(VVMTLBufferDescriptor * __nonnull)n;

@property (strong,readwrite,nonnull) id<MTLBuffer> buffer;

@end




@interface NSObject (VVMTLBufferNSObjectAdditions)
@property (readonly) BOOL isVVMTLBuffer;
@end




@interface VVMTLBuffer : NSObject <VVMTLBuffer>
@end




#endif /* MTLBuffer_h */
