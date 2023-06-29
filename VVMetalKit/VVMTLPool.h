//
//  VVMTLPool.h
//  VVMetalKit
//
//  Created by testadmin on 6/26/23.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <CoreVideo/CoreVideo.h>
#import <AppKit/AppKit.h>

#import "VVMTLRecyclingPool.h"
@protocol VVMTLTextureImage;
@protocol VVMTLBuffer;

NS_ASSUME_NONNULL_BEGIN




@interface VVMTLPool : NSObject <VVMTLRecyclingPool>

- (instancetype) initWithDevice:(id<MTLDevice>)n;

- (id<VVMTLTextureImage>) bgra8TexSized:(NSSize)n;
- (id<VVMTLTextureImage>) rgba8TexSized:(NSSize)n;
- (id<VVMTLTextureImage>) rgb10a2TexSized:(NSSize)n;
- (id<VVMTLTextureImage>) rgb10a2BufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;
//- (id<VVMTLTextureImage>) rgb10a2NormTexSized:(NSSize)n;
- (id<VVMTLTextureImage>) uyvyBufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;
//- (id<VVMTLTextureImage>) rgba16TexSized:(NSSize)n;
- (id<VVMTLTextureImage>) rgbaFloatTexSized:(NSSize)n;
//- (id<VVMTLTextureImage>) rgbaFloatBufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;
//- (id<VVMTLTextureImage>) rgbaBufferBackedFloatTexSized:(NSSize)n;
- (id<VVMTLTextureImage>) bgra8BufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;
//- (id<VVMTLTextureImage>) rgbaHalfFloatTexSized:(NSSize)n;
//- (id<VVMTLTextureImage>) rgbaHalfFloatBufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;
- (id<VVMTLTextureImage>) bufferForExistingTexture:(id<MTLTexture>)n;
- (id<VVMTLTextureImage>) bgra8IOSurfaceBackedTexSized:(NSSize)n;
//- (id<VVMTLTextureImage>) rgbaFloat32IOSurfaceBackedTexSized:(NSSize)n;
//- (id<VVMTLTextureImage>) rgbaHalfFloatIOSurfaceBackedTexFromCVPB:(CVPixelBufferRef)inCVPB;
//- (id<VVMTLTextureImage>) uyvyIOSurfaceBackedTexSized:(NSSize)n;
- (id<VVMTLTextureImage>) bufferForCVMTLTex:(CVMetalTextureRef)inRef sized:(NSSize)inSize;
- (id<VVMTLBuffer>) bufferButNoTexSized:(size_t)inBufferSize options:(MTLResourceOptions)inOpts;
- (id<VVMTLTextureImage>) createFromNSImage:(NSImage *)n;

- (id<VVMTLBuffer>) bufferWithLength:(size_t)inLength storage:(MTLStorageMode)inStorage;
//	copies the data from the passed ptr into a new buffer.  safe to delete the passed ptr when this returns.
- (id<VVMTLBuffer>) bufferWithLength:(size_t)inLength storage:(MTLStorageMode)inStorage basePtr:(nullable void*)b;
//	the MTLBuffer returned by this will be backed by the passed ptr, and modifying the MTLBuffer will modify its backing.
- (id<VVMTLBuffer>) bufferWithLengthNoCopy:(size_t)inLength storage:(MTLStorageMode)inStorage basePtr:(nullable void*)b bufferDeallocator:(nullable void (^)(void *pointer, NSUInteger length))d;

@property (readonly) id<MTLDevice> device;

@end




static inline MTLResourceOptions MTLResourceStorageModeForMTLStorageMode(MTLStorageMode inStorage);
static inline OSType BestGuessCVPixelFormatTypeForMTLPixelFormat(MTLPixelFormat inPF);




NS_ASSUME_NONNULL_END
