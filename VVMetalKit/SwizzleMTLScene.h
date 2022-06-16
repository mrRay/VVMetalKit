#import <TargetConditionals.h>
#import <Foundation/Foundation.h>
#if TARGET_OS_IOS
#import <VVMetalKitTouch/MTLComputeScene.h>
#import <VVMetalKitTouch/SwizzleMTLSceneTypes.h>
#else
#import <VVMetalKit/MTLComputeScene.h>
#import <VVMetalKit/SwizzleMTLSceneTypes.h>
#endif

NS_ASSUME_NONNULL_BEGIN




@interface SwizzleMTLScene : MTLComputeScene

//	the MTLBuffer returned by this will be backed by the passed ptr, and modifying the MTLBuffer will modify its backing.
- (id<MTLBuffer>) bufferWithLengthNoCopy:(size_t)inLength basePtr:(nullable void*)b bufferDeallocator:(nullable void (^)(void *pointer, NSUInteger length))d;

//	copies the data from the passed ptr into a new buffer.  safe to delete the passed ptr when this returns.
- (id<MTLBuffer>) bufferWithLength:(size_t)inLength basePtr:(nullable void*)b;

//	'inSrc'- MTLBuffer containing image data, the layout of which is described by 'inInfo.srcImg'.  the image data here is the source image.  can never be nil.
//	'inDst'- MTLBuffer into which image data will be written, described by 'inInfo.dstImg'.  the image data here is the destination image.  may be nil.
//	'inRGB'- MTLImgBuffer containing a MTLTexture.  dimensions must match the dimensions of 'inDst'.  RGB image data will be written to this texture as part of the swizzle while converting the src image data to the dst image data.  may be nil.
//	'inInfo'- describes the swizzle operation.  contains data structures describing the format and layout of the src and dst buffers, H and V flippedness, fade-to-black-edness, and other fun stuff.
- (void) convertSrcBuffer:(id<MTLBuffer>)inSrc dstBuffer:(nullable id<MTLBuffer>)inDst dstRGBTexture:(nullable MTLImgBuffer *)inRGB swizzleInfo:(SwizzleShaderOpInfo)inInfo inCommandBuffer:(id<MTLCommandBuffer>)inCB;

//	'inSrc'- MTLImgBuffer containing a MTLTexture.  not a MTLBuffer, but 'inInfo.srcImg' must still be populated!  the image data here is the source image.  can never be nil.
//	'inDst'- MTLBuffer into which image data will be written, described by 'inInfo.dstImg'.  the image data here is the destination image.  may be nil.
//	'inRGB'- MTLImgBuffer containing a MTLTexture.  dimensions must match the dimensions of 'inDst'.  RGB image data will be written to this texture as part of the swizzle while converting the src image data to the dst image data.  may be nil.
//	'inInfo'- describes the swizzle operation.  contains data structures describing the format and layout of the src and dst buffers, H and V flippedness, fade-to-black-edness, and other fun stuff.
- (void) convertSrcRGBTexture:(MTLImgBuffer *)inSrc dstBuffer:(nullable id<MTLBuffer>)inDst dstRGBTexture:(nullable MTLImgBuffer *)inRGB swizzleInfo:(SwizzleShaderOpInfo)inInfo inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
