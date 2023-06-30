//
//  VVMTLBuffer.h
//  VVMetalKit
//
//  Created by testadmin on 6/23/23.
//

#ifndef MTLBuffer_h
#define MTLBuffer_h

#import <Metal/Metal.h>

#import <VVMetalKit/VVMTLImage.h>
#import <VVMetalKit/VVMTLTimestamp.h>
#import <VVMetalKit/VVMTLRecycleable.h>
#import <VVMetalKit/VVMTLRecyclingPool.h>
#import <VVMetalKit/VVMTLRecycleableDescriptor.h>
#import <VVMetalKit/VVMTLBufferDescriptor.h>




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
