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

#import <VVMetalKit/VVMTLRecyclingPool.h>
@protocol VVMTLTextureImage;
@protocol VVMTLBuffer;
@protocol VVMTLTextureLUT;
@protocol VVMTLTimestamp;
@class VVMTLTextureImageDescriptor;
@class VVMTLTextureLUTDescriptor;

NS_ASSUME_NONNULL_BEGIN




@interface VVMTLPool : NSObject <VVMTLRecyclingPool>

@property (class,strong,readwrite) VVMTLPool * global;

- (instancetype) initWithDevice:(id<MTLDevice>)n;

@property (readonly) id<MTLDevice> device;
@property (readonly) CVMetalTextureCacheRef cvTexCache;
@property (readonly) BOOL supportsMemoryless;
@property (readonly) BOOL supportsTileShaders;

//	a lot of methods use this to recycle or generate a texture (and also an accompanying backing, as specified)
- (id<VVMTLTextureImage>) textureForDescriptor:(VVMTLTextureImageDescriptor*)inDesc;

- (id<VVMTLTextureImage>) bgra8TexSized:(NSSize)n;
- (id<VVMTLTextureImage>) bgra8TexSized:(NSSize)inSize sampleCount:(NSUInteger)inSampleCount;
- (id<VVMTLTextureImage>) bgra8SRGBTexSized:(NSSize)n;
- (id<VVMTLTextureImage>) rgba8TexSized:(NSSize)n;
- (id<VVMTLTextureImage>) rgba8SRGBTexSized:(NSSize)n;
- (id<VVMTLTextureImage>) rgb10a2TexSized:(NSSize)n;
- (id<VVMTLTextureImage>) rgb10a2BufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;
//- (id<VVMTLTextureImage>) rgb10a2NormTexSized:(NSSize)n;
- (id<VVMTLTextureImage>) uyvyBufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;
//- (id<VVMTLTextureImage>) rgba16TexSized:(NSSize)n;
- (id<VVMTLTextureImage>) rgbaHalfFloatTexSized:(NSSize)n;
- (id<VVMTLTextureImage>) rgbaFloatTexSized:(NSSize)n;
- (id<VVMTLTextureImage>) rgbaFloatTexSized:(NSSize)n sampleCount:(NSUInteger)inSampleCount;
//- (id<VVMTLTextureImage>) rgbaFloatBufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;
//- (id<VVMTLTextureImage>) rgbaBufferBackedFloatTexSized:(NSSize)n;

//	does NOT copy the passed data buffer- just declares it as the backing to a MTLBuffer, which in turn backs a MTLTexture.
- (id<VVMTLTextureImage>) bufferBackedTexSized:(NSSize)s pixelFormat:(MTLPixelFormat)pfmt basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;
//	DOES copy the passed data buffer!
- (id<VVMTLTextureImage>) bufferBackedTexSized:(NSSize)s pixelFormat:(MTLPixelFormat)pfmt basePtr:(void*)b bytesPerRow:(uint32_t)bpr;
//	creates an empty buffer-backed texture
- (id<VVMTLTextureImage>) bufferBackedTexSized:(NSSize)s pixelFormat:(MTLPixelFormat)pfmt bytesPerRow:(uint32_t)bpr;
//- (id<VVMTLTextureImage>) rgbaHalfFloatTexSized:(NSSize)n;
//- (id<VVMTLTextureImage>) rgbaHalfFloatBufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;
- (id<VVMTLTextureImage>) textureForExistingTexture:(id<MTLTexture>)n;
- (id<VVMTLTextureImage>) bgra8IOSurfaceBackedTexSized:(NSSize)n;
//- (id<VVMTLTextureImage>) rgbaFloat32IOSurfaceBackedTexSized:(NSSize)n;
//- (id<VVMTLTextureImage>) rgbaHalfFloatIOSurfaceBackedTexFromCVPB:(CVPixelBufferRef)inCVPB;
//- (id<VVMTLTextureImage>) uyvyIOSurfaceBackedTexSized:(NSSize)n;

- (id<VVMTLTextureImage>) lum8TexSized:(NSSize)n;
- (id<VVMTLTextureImage>) bufferBackedLum8TexSized:(NSSize)n;

- (id<VVMTLTextureImage>) depthTexSized:(NSSize)n;
- (id<VVMTLTextureImage>) depthTexSized:(NSSize)n sampleCount:(NSUInteger)inSampleCount;

- (id<VVMTLTextureImage>) textureForCVMTLTex:(CVMetalTextureRef)inRef sized:(NSSize)inSize;
//- (id<VVMTLBuffer>) bufferButNoTexSized:(size_t)inBufferSize options:(MTLResourceOptions)inOpts;
- (id<VVMTLTextureImage>) createFromNSImage:(NSImage *)n;
- (id<VVMTLTextureImage>) createFromNSBitmapImageRep:(NSBitmapImageRep *)n;

- (id<VVMTLTextureImage>) textureForIOSurface:(IOSurfaceRef)n;

- (id<VVMTLTextureLUT>) lutForDescriptor:(VVMTLTextureLUTDescriptor*)inDesc;

- (id<VVMTLTextureLUT>) bufferBacked1DLUTSized:(MTLSize)n;
- (id<VVMTLTextureLUT>) bufferBacked2DLUTSized:(MTLSize)n;
- (id<VVMTLTextureLUT>) bufferBacked3DLUTSized:(MTLSize)n;

- (id<VVMTLBuffer>) bufferWithLength:(size_t)inLength storage:(MTLStorageMode)inStorage;
//	copies the data from the passed ptr into a new buffer.  safe to delete the passed ptr when this returns.
- (id<VVMTLBuffer>) bufferWithLength:(size_t)inLength storage:(MTLStorageMode)inStorage basePtr:(nullable void*)b;
//	the MTLBuffer returned by this will be backed by the passed ptr, and modifying the MTLBuffer will modify its backing.
- (id<VVMTLBuffer>) bufferWithLengthNoCopy:(size_t)inLength storage:(MTLStorageMode)inStorage basePtr:(nullable void*)b bufferDeallocator:(nullable void (^)(void *pointer, NSUInteger length))d;

- (void) timestampThis:(nullable id<VVMTLTimestamp>)n;

@end




NS_ASSUME_NONNULL_END
