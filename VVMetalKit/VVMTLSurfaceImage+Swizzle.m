//
//  VVMTLSurfaceImage+Swizzle.m
//  VVMetalKit
//
//  Created by testadmin on 6/22/26.
//

#import "VVMTLSurfaceImage+Swizzle.h"
#import "VVMTLSurfaceImageDescriptor.h"
#import "SwizzleMTLScene.h"
#import <VVMetalKit/VVMTLTextureImage.h>




@implementation VVMTLSurfaceImage (Swizzle)


//	resolves both facts about a CoreVideo pixel format at once: its SwizzlePF byte layout and its SwizzleColorRange.
//	keeping these together (rather than in two separate switches) keeps a format's layout and range from drifting apart.
- (void) _resolveSwizzlePF:(SwizzlePF *)outPF colorRange:(SwizzleColorRange *)outRange	{
	SwizzlePF			pf = SwizzlePF_Unknown;
	SwizzleColorRange	range = SwizzleColorRange_legacy;

	VVMTLSurfaceImageDescriptor		*desc = (VVMTLSurfaceImageDescriptor*)self.descriptor;
	OSType			cvFmt = desc.cvPixelFormat;
	switch (cvFmt)	{
	case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:		//	'420f'
		pf = SwizzlePF_UYVY_PKPL_420_UI_8;
		range = SwizzleColorRange_full;
		break;
	case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:	//	'420v'
		pf = SwizzlePF_UYVY_PKPL_420_UI_8;
		range = SwizzleColorRange_video;
		break;
	case kCVPixelFormatType_420YpCbCr8Planar:				//	'y420'
		pf = SwizzlePF_UYVY_PL_420_UI_8;
		range = SwizzleColorRange_video;
		break;
	default:
		pf = SwizzlePF_Unknown;
		range = SwizzleColorRange_legacy;
		break;
	}

	if (outPF != NULL)
		*outPF = pf;
	if (outRange != NULL)
		*outRange = range;
}

- (SwizzlePF) swizzlePixelFormat	{
	SwizzlePF		pf = SwizzlePF_Unknown;
	[self _resolveSwizzlePF:&pf colorRange:NULL];
	return pf;
}

- (SwizzleColorRange) swizzleColorRange	{
	SwizzleColorRange		range = SwizzleColorRange_legacy;
	[self _resolveSwizzlePF:NULL colorRange:&range];
	return range;
}

//	resolves the YCbCr primaries from the CVPixelBuffer's kCVImageBufferYCbCrMatrixKey attachment.
//	this is per-conversion (microseconds, once per op-build)- no cached state on the recycled surface.  handles a nil CVPixelBuffer / absent / unrecognized attachment by falling back to the legacy (709) default.
- (SwizzleColorPrimaries) swizzleColorPrimaries	{
	CVPixelBufferRef		cvpb = self.cvpb;
	if (cvpb == NULL)
		return SwizzleColorPrimaries_legacy;

	//	CVBufferCopyAttachment returns a +1 reference (the older CVBufferGetAttachment is deprecated as of macOS 12.0, our deployment target)
	CFTypeRef		matrixAttachment = CVBufferCopyAttachment(cvpb, kCVImageBufferYCbCrMatrixKey, NULL);
	if (matrixAttachment == NULL)
		return SwizzleColorPrimaries_legacy;

	SwizzleColorPrimaries	returnMe = SwizzleColorPrimaries_legacy;
	if (CFGetTypeID(matrixAttachment) == CFStringGetTypeID())	{
		CFStringRef		matrixStr = (CFStringRef)matrixAttachment;
		if (CFEqual(matrixStr, kCVImageBufferYCbCrMatrix_ITU_R_709_2))
			returnMe = SwizzleColorPrimaries_709;
		else if (CFEqual(matrixStr, kCVImageBufferYCbCrMatrix_ITU_R_601_4))
			returnMe = SwizzleColorPrimaries_601;
		else if (CFEqual(matrixStr, kCVImageBufferYCbCrMatrix_ITU_R_2020))
			returnMe = SwizzleColorPrimaries_2020;
	}

	CFRelease(matrixAttachment);
	return returnMe;
}

- (SwizzleShaderImageInfo) swizzleDstImageInfo	{
	SwizzlePF		pf = self.swizzlePixelFormat;

	//	copy the surface's ACTUAL cached per-plane geometry into the plane array- offsets and strides come from the IOSurface (read independently per plane), never naive math
	NSUInteger		count = self.planeCount;
	if (count > MAX_NUM_PLANES)
		count = MAX_NUM_PLANES;
	SwizzleShaderImagePlaneInfo		planes[MAX_NUM_PLANES];
	for (NSUInteger i=0; i<count; ++i)	{
		planes[i].offset = (unsigned int)[self offsetOfPlane:i];
		planes[i].bytesPerRow = (unsigned int)[self bytesPerRowOfPlane:i];
	}

	return MakeSwizzleShaderImageInfoWithPlanes(pf, (unsigned int)self.width, (unsigned int)self.height, (unsigned int)count, planes);
}

- (SwizzleShaderOpInfo) makeSwizzleOpInfoFromSrcImageInfo:(SwizzleShaderImageInfo)inSrcInfo	{
	SwizzleShaderOpInfo		returnMe = MakeSwizzleShaderOpInfo(inSrcInfo, self.swizzleDstImageInfo);
	returnMe.colorRange = self.swizzleColorRange;
	returnMe.colorPrimaries = self.swizzleColorPrimaries;
	return returnMe;
}

- (SwizzleShaderOpInfo) makeSwizzleOpInfoToDrawIntoDstImageInfo:(SwizzleShaderImageInfo)inDstInfo	{
	//	surface as the SOURCE this time- the geometry struct is role-agnostic, so swizzleDstImageInfo describes it equally well as a src.
	SwizzleShaderOpInfo		returnMe = MakeSwizzleShaderOpInfo(self.swizzleDstImageInfo, inDstInfo);
	returnMe.colorRange = self.swizzleColorRange;
	returnMe.colorPrimaries = self.swizzleColorPrimaries;
	return returnMe;
}

- (void) convertToRGBTexture:(id<VVMTLTextureImage>)outRGB scene:(SwizzleMTLScene *)inScene inCommandBuffer:(id<MTLCommandBuffer>)inCB	{
	if (outRGB==nil || inScene==nil)	{
		NSLog(@"ERR: prereq A not met, %s",__func__);
		return;
	}

	//	derive the dst layout from the texture's ACTUAL pixel format rather than assuming BGRA8.  (the shader writes via texture.write(), so Metal maps channel order from the real format regardless- but keep dstImg.pf honest so the op-info describes the true destination.)
	SwizzlePF		dstPF;
	switch (outRGB.texture.pixelFormat)	{
	case MTLPixelFormatRGBA8Unorm:
	case MTLPixelFormatRGBA8Unorm_sRGB:
		dstPF = SwizzlePF_RGBA_PK_UI_8;
		break;
	case MTLPixelFormatRGBA32Float:
		dstPF = SwizzlePF_RGBA_PK_FP_32;
		break;
	case MTLPixelFormatBGRA8Unorm:
	case MTLPixelFormatBGRA8Unorm_sRGB:
	default:
		dstPF = SwizzlePF_BGRA_PK_UI_8;	//	safe fallback- all packed-RGB formats share the 1x1 shader eval size
		break;
	}

	//	build the dst image info from the RGB texture, then the op (surface as src), then dispatch
	SwizzleShaderImageInfo		dstInfo = MakeSwizzleShaderImageInfo(dstPF, (unsigned int)outRGB.width, (unsigned int)outRGB.height);
	SwizzleShaderOpInfo			op = [self makeSwizzleOpInfoToDrawIntoDstImageInfo:dstInfo];
	[inScene
		convertSrcSurfaceImage:self
		dstRGBTexture:outRGB
		swizzleInfo:op
		inCommandBuffer:inCB];
}


@end
