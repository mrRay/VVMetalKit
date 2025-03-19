#import <Foundation/Foundation.h>
#import <VVMetalKit/VVMTLComputeScene.h>
#import <VVMetalKit/SwizzleMTLSceneTypes.h>

NS_ASSUME_NONNULL_BEGIN




///		Uses Metal compute to do pixel format conversion on image data contained in buffers or textures
@interface SwizzleMTLScene : VVMTLComputeScene

///	Converts the pixel format of the image in the passed buffer.
///	- Parameters:
///		- inSrc: MTLBuffer containing image data, the layout of which is described by 'inInfo.srcImg'.  the image data here is the source image.  can never be nil.
///		- outDst: MTLBuffer into which image data will be written, described by 'inInfo.dstImg'.  the image data here is the destination image.  may be nil.
///		- outTex: id<VVMTLTextureImage> containing a MTLTexture.  dimensions must match the dimensions of 'outDst'.  RGB image data will be written to this texture as part of the swizzle while converting the src image data to the dst image data.  may be nil.
///		- inInfo: describes the swizzle operation.  contains data structures describing the format and layout of the src and dst buffers, H and V flippedness, fade-to-black-edness, and other fun stuff.
///		- inCB: The command buffer in which the conversion will take place.
- (void) convertSrcBuffer:(id<VVMTLBuffer>)inSrc
	dstBuffer:(nullable id<VVMTLBuffer>)outDst
	dstRGBTexture:(nullable id<VVMTLTextureImage>)outTex
	swizzleInfo:(SwizzleShaderOpInfo)inInfo
	inCommandBuffer:(id<MTLCommandBuffer>)inCB;

///	Converts the pixel format of the image in the passed texture.
///	- Parameters:
///		- inSrc: id<VVMTLTextureImage> containing a MTLTexture.  not a MTLBuffer, but 'inInfo.srcImg' must still be populated!  the image data here is the source image.  can never be nil.
///		- outDst: MTLBuffer into which image data will be written, described by 'inInfo.dstImg'.  the image data here is the destination image.  may be nil.
///		- outTex: id<VVMTLTextureImage> containing a MTLTexture.  dimensions must match the dimensions of 'outDst'.  RGB image data will be written to this texture as part of the swizzle while converting the src image data to the dst image data.  may be nil.
///		- inInfo: describes the swizzle operation.  contains data structures describing the format and layout of the src and dst buffers, H and V flippedness, fade-to-black-edness, and other fun stuff.
///		- inCB: The command buffer in which the conversion will take place.
- (void) convertSrcRGBTexture:(id<VVMTLTextureImage>)inSrc
	dstBuffer:(nullable id<VVMTLBuffer>)outDst
	dstRGBTexture:(nullable id<VVMTLTextureImage>)outTex
	swizzleInfo:(SwizzleShaderOpInfo)inInfo
	inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
