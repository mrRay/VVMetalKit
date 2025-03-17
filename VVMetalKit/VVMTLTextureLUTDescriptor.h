//
//  VVMTLTextureLUTDescriptor.h
//  VVMetalKit
//
//  Created by testadmin on 7/12/23.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#import <VVMetalKit/VVMTLRecycleableDescriptor.h>

NS_ASSUME_NONNULL_BEGIN




///	Data container class.  Contents describe the relevant distinguishing characteristics of the GPU resource (and associated CPU resources, if any) that we're going to recycle.  When retrieving objects from the pool, the values of this class are compared the pool's contents to find a match.




@interface VVMTLTextureLUTDescriptor : NSObject <VVMTLRecycleableDescriptor>

+ (instancetype) createWithOrder:(uint8_t)inOrder size:(MTLSize)inSize pixelFormat:(MTLPixelFormat)inPfmt storage:(MTLStorageMode)inStorage usage:(MTLTextureUsage)inUsage;

- (instancetype) initWithOrder:(uint8_t)inOrder size:(MTLSize)inSize pixelFormat:(MTLPixelFormat)inPfmt storage:(MTLStorageMode)inStorage usage:(MTLTextureUsage)inUsage;

@property (assign,readwrite) uint8_t order;
@property (assign,readwrite) MTLSize size;
@property (assign,readwrite) MTLPixelFormat pfmt;
@property (assign,readwrite) MTLStorageMode storage;
@property (assign,readwrite) MTLTextureUsage usage;
@property (assign,readwrite) BOOL mtlBufferBacking;	//	NO by default, if YES we're looking for a texture backed by a id<VVMTLBuffer>

@end




@interface NSObject (VVMTLTextureLUTDescriptorNSObjectAdditions)
@property (readonly) BOOL isVVMTLTextureLUTDescriptor;
@end




NS_ASSUME_NONNULL_END
