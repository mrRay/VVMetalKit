//
//  VVMTLTextureImageDescriptor.h
//  VVMetalKit
//
//  Created by testadmin on 6/26/23.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#import "VVMTLRecycleableDescriptor.h"

NS_ASSUME_NONNULL_BEGIN




//	data container class.  contents describe the relevant distinguishing characteristics of the GPU resource 
//	(and associated CPU resources, if any) that we're going to recycle.




@interface VVMTLTextureImageDescriptor : NSObject <VVMTLRecycleableDescriptor>

+ (instancetype) createWithWidth:(NSUInteger)inWidth height:(NSUInteger)inHeight pixelFormat:(MTLPixelFormat)inPfmt storage:(MTLStorageMode)inStorage usage:(MTLTextureUsage)inUsage;

- (instancetype) initWithWidth:(NSUInteger)inWidth height:(NSUInteger)inHeight pixelFormat:(MTLPixelFormat)inPfmt storage:(MTLStorageMode)inStorage usage:(MTLTextureUsage)inUsage;

@property (assign,readwrite) NSUInteger width;
@property (assign,readwrite) NSUInteger height;
@property (assign,readwrite) MTLPixelFormat pfmt;
@property (assign,readwrite) MTLStorageMode storage;
@property (assign,readwrite) MTLTextureUsage usage;
@property (assign,readwrite) BOOL mtlBufferBacking;	//	NO by default, if YES we're looking for a texture backed by a id<VVMTLBuffer>
@property (assign,readwrite) BOOL iosfcBacking;	//	NO by default, if YES we're looking for a texture backed by an IOSurfaceRef
@property (assign,readwrite) BOOL cvpbBacking;	//	NO by default, if YES we're looking for a texture backed by a CVPixelBufferRef (or maybe a texture backed by an IOSurface backed by a CVPixelBufferRef!)

@end




@interface NSObject (VVMTLTextureImageDescriptorNSObjectAdditions)
@property (readonly) BOOL isVVMTLTextureImageDescriptor;
@end




NS_ASSUME_NONNULL_END
