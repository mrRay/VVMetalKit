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




/**		VVMTLPool is a pool for recycling (and generating) Metal resources (textures and buffers).
		- Recycling assets is almost always significantly faster/more efficient than trashing and re-generating them repeatedly.
		- Has a global singleton accessible via the class method- your app probably only needs one instance of this class
		- Generates both `VVMTLTextureImage` and `VVMTLBuffer` instances
*/




@interface VVMTLPool : NSObject <VVMTLRecyclingPool>

///	The global singleton class- it's nil by default, and must be populated manually.
@property (class,strong,readwrite) VVMTLPool * global;

///	The standard method for creating an instance of VVMTLPool.
- (instancetype) initWithDevice:(id<MTLDevice>)n;

///	The device used by the pool- set on init.
@property (readonly) id<MTLDevice> device;
///	Instances of VVMTLPool have a CVMetalTextureCacheRef by default.
@property (readonly) CVMetalTextureCacheRef cvTexCache;
@property (readonly) BOOL supportsMemoryless;
@property (readonly) BOOL supportsTileShaders;

///	Sometimes you just need an empty black texture.  Maybe you just need to bind something on an edge case.  Always returns the same texture (so don't try to write to it)
@property (strong,readonly) id<VVMTLTextureImage> emptyBlackTexture;

///	This method will attempt to recycle an unused texture that matches the passed desription- if none can be found, a new texture matching the description will be allocated and returned.
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

///	Returns a buffer with the passed length and storage mode.  May return an existing buffer if one's available- otherwise, a new buffer will be allocated.
- (id<VVMTLBuffer>) bufferWithLength:(size_t)inLength storage:(MTLStorageMode)inStorage;
///	Copies the data from the passed ptr into a new buffer.  Safe to delete the passed ptr when this returns.
- (id<VVMTLBuffer>) bufferWithLength:(size_t)inLength storage:(MTLStorageMode)inStorage basePtr:(nullable void*)b;
///	The MTLBuffer returned by this will be backed by the passed ptr, and modifying the MTLBuffer will modify its backing.  This buffer creation method doesn't copy the data.
- (id<VVMTLBuffer>) bufferWithLengthNoCopy:(size_t)inLength storage:(MTLStorageMode)inStorage basePtr:(nullable void*)b bufferDeallocator:(nullable void (^)(void *pointer, NSUInteger length))d;

- (void) timestampThis:(nullable id<VVMTLTimestamp>)n;

@end




NS_ASSUME_NONNULL_END
