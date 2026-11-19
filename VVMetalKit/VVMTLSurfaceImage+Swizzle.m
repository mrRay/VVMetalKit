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
#import "VVMTLPool.h"




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

//	the op that draws this surface (as SOURCE) into the passed RGB texture
- (SwizzleShaderOpInfo) _swizzleOpInfoToDrawIntoRGBTexture:(id<VVMTLTextureImage>)outRGB	{
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

	//	build the dst image info from the RGB texture, then the op (surface as src)
	SwizzleShaderImageInfo		dstInfo = MakeSwizzleShaderImageInfo(dstPF, (unsigned int)outRGB.width, (unsigned int)outRGB.height);
	return [self makeSwizzleOpInfoToDrawIntoDstImageInfo:dstInfo];
}

- (BOOL) convertToRGBTexture:(id<VVMTLTextureImage>)outRGB scene:(SwizzleMTLScene *)inScene inCommandBuffer:(id<MTLCommandBuffer>)inCB	{
	if (outRGB==nil || inScene==nil)	{
		NSLog(@"ERR: prereq A not met, %s",__func__);
		return NO;
	}

	//	build the op, then dispatch
	SwizzleShaderOpInfo			op = [self _swizzleOpInfoToDrawIntoRGBTexture:outRGB];
	return [inScene
		convertSrcSurfaceImage:self
		dstRGBTexture:outRGB
		swizzleInfo:op
		inCommandBuffer:inCB];
}

- (BOOL) convertPlaneTexturesToRGBTexture:(id<VVMTLTextureImage>)outRGB scene:(SwizzleMTLScene *)inScene inCommandBuffer:(id<MTLCommandBuffer>)inCB	{
	if (outRGB==nil || inScene==nil || inCB==nil)	{
		NSLog(@"ERR: prereq A not met, %s",__func__);
		return NO;
	}

	//	only a bi-planar 4:2:0 surface that has its CVPixelBuffer (and describes that pixel buffer) can be read this way.  not an error: the caller is told, and reads the surface another way
	CVPixelBufferRef		cvpb = self.cvpb;
	if (cvpb == NULL || self.swizzlePixelFormat != SwizzlePF_UYVY_PKPL_420_UI_8 || CVPixelBufferGetPlaneCount(cvpb) != 2)
		return NO;
	if (self.width != CVPixelBufferGetWidth(cvpb) || self.height != CVPixelBufferGetHeight(cvpb))
		return NO;
	CVMetalTextureCacheRef		texCache = VVMTLPool.global.cvTexCache;
	if (texCache == NULL)
		return NO;

	//	one texture per plane, straight off the pixel buffer's IOSurface (no copy): one channel for Y, two for Cb/Cr.  the cache hands back the textures it already made for a surface it has seen, so a source that recycles its surfaces (a decoder does) stops allocating after its first few frames
	NSSize					planeSizes[2];
	CVMetalTextureRef		planeRefs[2] = { NULL, NULL };
	MTLPixelFormat			planeFormats[2] = { MTLPixelFormatR8Unorm, MTLPixelFormatRG8Unorm };
	NSMutableArray<id<VVMTLTextureImage>>		*planes = [NSMutableArray arrayWithCapacity:2];
	for (size_t i=0; i<2; ++i)	{
		planeSizes[i] = NSMakeSize(CVPixelBufferGetWidthOfPlane(cvpb, i), CVPixelBufferGetHeightOfPlane(cvpb, i));
		CVReturn		cvErr = CVMetalTextureCacheCreateTextureFromImage(
			kCFAllocatorDefault,
			texCache,
			cvpb,
			NULL,
			planeFormats[i],
			(size_t)planeSizes[i].width,
			(size_t)planeSizes[i].height,
			i,
			&planeRefs[i]);
		//	the texture image retains the CVMetalTexture for as long as it lives
		id<VVMTLTextureImage>		plane = (cvErr != kCVReturnSuccess) ? nil : [VVMTLPool.global textureForCVMTLTex:planeRefs[i] sized:planeSizes[i]];
		if (planeRefs[i] != NULL)
			CVBufferRelease(planeRefs[i]);
		if (plane == nil)	{
			//	logged here, not by the caller: only this knows the CoreVideo error, which is what tells a passing failure (allocation) from a machine that won't make these textures
			NSLog(@"ERR: couldn't make a texture from plane %zu (%d x %d), CVReturn %d, %s",i,(int)planeSizes[i].width,(int)planeSizes[i].height,(int)cvErr,__func__);
			return NO;
		}
		[planes addObject:plane];
	}

	//	build the op, then dispatch.  the op's src image info is only read for its pixel format and resolution here- the planes aren't found by offset
	SwizzleShaderOpInfo			op = [self _swizzleOpInfoToDrawIntoRGBTexture:outRGB];
	if (![inScene
		convertSrcPlaneTextures:planes
		dstBuffer:nil
		dstRGBTexture:outRGB
		swizzleInfo:op
		inCommandBuffer:inCB])	{
		return NO;
	}

	//	the plane textures alias the pixel buffer's surface, and whoever made the pixel buffer reuses that surface once the buffer is released: keep this surface (and so its pixel buffer) alive until the GPU has read the planes
	VVMTLSurfaceImage		*keepAlive = self;
	[inCB addCompletedHandler:^(id<MTLCommandBuffer> completed)	{
		VVMTLSurfaceImage		*tmp = keepAlive;
		tmp = nil;
	}];
	return YES;
}


@end
