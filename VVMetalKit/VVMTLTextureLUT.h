//
//  VVMTLTextureLUT.h
//  VVMetalKit
//
//  Created by testadmin on 7/12/23.
//

#ifndef MTLTextureLUT_h
#define MTLTextureLUT_h

#import <Metal/Metal.h>

#import <VVMetalKit/VVMTLLUT.h>
#import <VVMetalKit/VVMTLRecycleable.h>
#import <VVMetalKit/VVMTLRecyclingPool.h>
#import <VVMetalKit/VVMTLRecycleableDescriptor.h>
#import <VVMetalKit/VVMTLTextureLUTDescriptor.h>
#import <VVMetalKit/VVMTLBuffer.h>




@protocol VVMTLTextureLUT <VVMTLLUT, VVMTLRecycleable>

+ (instancetype __nonnull) createWithDescriptor:(VVMTLTextureLUTDescriptor * __nonnull)n;

- (instancetype __nonnull) initWithDescriptor:(VVMTLTextureLUTDescriptor * __nonnull)n;

@property (strong,readwrite,nonnull) id<MTLTexture> texture;

//	If non-null, provides the backing for the texture. Receiver "retains" the id<VVMTLBuffer> for its lifetime.
@property (strong,readwrite,nullable) id<VVMTLBuffer> buffer;

@end




@interface NSObject (VVMTLTextureLUTNSObjectAdditions)
@property (readonly) BOOL isVVMTLTextureLUT;
@end




@interface VVMTLTextureLUT : NSObject <VVMTLTextureLUT>
@end




#endif /* MTLTextureLUT_h */