#import <TargetConditionals.h>
#import <Foundation/Foundation.h>
#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
#import <VVMetalKitTouch/VVMTLComputeScene.h>
#import <VVMetalKitTouch/SwizzleMTLSceneTypes.h>
#else
#import <VVMetalKit/VVMTLComputeScene.h>
#import <VVMetalKit/SwizzleMTLSceneTypes.h>
#endif

NS_ASSUME_NONNULL_BEGIN




@interface SwizzleMTLScene : VVMTLComputeScene

//	'inSrc'- MTLBuffer containing image data, the layout of which is described by 'inInfo.srcImg'.  the image data here is the source image.  can never be nil.
//	'inDst'- MTLBuffer into which image data will be written, described by 'inInfo.dstImg'.  the image data here is the destination image.  may be nil.
//	'inRGB'- id<VVMTLTextureImage> containing a MTLTexture.  dimensions must match the dimensions of 'inDst'.  RGB image data will be written to this texture as part of the swizzle while converting the src image data to the dst image data.  may be nil.
//	'inInfo'- describes the swizzle operation.  contains data structures describing the format and layout of the src and dst buffers, H and V flippedness, fade-to-black-edness, and other fun stuff.
- (void) convertSrcBuffer:(id<VVMTLBuffer>)inSrc
	dstBuffer:(nullable id<VVMTLBuffer>)inDst
	dstRGBTexture:(nullable id<VVMTLTextureImage>)inRGB
	swizzleInfo:(SwizzleShaderOpInfo)inInfo
	inCommandBuffer:(id<MTLCommandBuffer>)inCB;

//	'inSrc'- id<VVMTLTextureImage> containing a MTLTexture.  not a MTLBuffer, but 'inInfo.srcImg' must still be populated!  the image data here is the source image.  can never be nil.
//	'inDst'- MTLBuffer into which image data will be written, described by 'inInfo.dstImg'.  the image data here is the destination image.  may be nil.
//	'inRGB'- id<VVMTLTextureImage> containing a MTLTexture.  dimensions must match the dimensions of 'inDst'.  RGB image data will be written to this texture as part of the swizzle while converting the src image data to the dst image data.  may be nil.
//	'inInfo'- describes the swizzle operation.  contains data structures describing the format and layout of the src and dst buffers, H and V flippedness, fade-to-black-edness, and other fun stuff.
- (void) convertSrcRGBTexture:(id<VVMTLTextureImage>)inSrc
	dstBuffer:(nullable id<VVMTLBuffer>)inDst
	dstRGBTexture:(nullable id<VVMTLTextureImage>)inRGB
	swizzleInfo:(SwizzleShaderOpInfo)inInfo
	inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
