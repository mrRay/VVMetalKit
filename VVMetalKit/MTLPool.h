#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <VVMetalKit/MTLImgBuffer.h>

NS_ASSUME_NONNULL_BEGIN




@interface MTLPool : NSObject

+ (MTLPool *) global;
+ (void) createGlobalPoolWithDevice:(id<MTLDevice>)inDevice;

@property (readonly) id<MTLDevice> device;

@property (assign) NSUInteger housekeepingThreshold;

- (CVMetalTextureCacheRef) cvTexCache;

//	buffers retain the pool that created them- this ensures that any "in flight" buffers will have their resources freed, and the corresponding pool will also be released as soon as possible
- (void) prepForRelease;

//	call this periodically to destroy buffers that have been in the pool "too long"
- (void) housekeeping;

//	MTLImgBuffers call this when they're deallocated
- (void) _returnToPool:(MTLImgBuffer *)n;


//	retrieves a texture of the passed size from the pool or creates one if there aren't any available
- (MTLImgBuffer *) bgra8TexSized:(CGSize)n;

- (MTLImgBuffer *) rgba8TexSized:(CGSize)n;

- (MTLImgBuffer *) rgb10a2TexSized:(CGSize)n;

- (MTLImgBuffer *) rgb10a2BufferBackedTexSized:(CGSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;

- (MTLImgBuffer *) rgb10a2NormTexSized:(CGSize)n;

- (MTLImgBuffer *) rgba16TexSized:(CGSize)n;

- (MTLImgBuffer *) rgbaFloatTexSized:(CGSize)n;

- (MTLImgBuffer *) rgbaFloatBufferBackedTexSized:(CGSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;

- (MTLImgBuffer *) rgbaBufferBackedFloatTexSized:(CGSize)n;

- (MTLImgBuffer *) bgra8BufferBackedTexSized:(CGSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;

- (MTLImgBuffer *) rgbaHalfFloatTexSized:(CGSize)n;

- (MTLImgBuffer *) rgbaHalfFloatBufferBackedTexSized:(CGSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;

- (MTLImgBuffer *) bufferForExistingTexture:(id<MTLTexture>)n;

- (MTLImgBuffer *) bgra8IOSurfaceBackedTexSized:(CGSize)n;

- (MTLImgBuffer *) rgbaFloat32IOSurfaceBackedTexSized:(CGSize)n;

- (MTLImgBuffer *) rgbaHalfFloatIOSurfaceBackedTexFromCVPB:(CVPixelBufferRef)inCVPB;

//	retains the passed texture ref and releases it when the returned object is released
- (MTLImgBuffer *) bufferForCVMTLTex:(CVMetalTextureRef)inRef sized:(CGSize)inSize;

//	if 'inTexCache' is nil, will use the pool's tex cache
//	if 'inCompletionHandler' is nil, will wait for the cmd buffer to complete before returning (if it's non-nil, will return immediately & execute the block when rendering completes)
//- (MTLImgBuffer *) bufferForCVPixelBuffer:(CVPixelBufferRef)inCVPB texCache:(CVMetalTextureCacheRef)inTexCache anamorphicRatio:(double)inAR inCommandBuffer:(id<MTLCommandBuffer>)inCB completionHandler:(void(^)(MTLImgBuffer * requestedTex))inCompletionHandler;


@end




NS_ASSUME_NONNULL_END
