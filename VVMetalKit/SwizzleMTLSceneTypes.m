//
//  SwizzleMTLSceneTypes.m
//  VVMetalKit
//
//  Created by testadmin on 3/1/22.
//

#import <Foundation/Foundation.h>
#import "SwizzleMTLSceneTypes.h"
#include "SizingTool_c.h"




NSString * NSStringFromSwizzlePF(SwizzlePF inPF)	{
	char		destCharPtr[5];
	destCharPtr[0] = (inPF>>24) & 0xFF;
	destCharPtr[1] = (inPF>>16) & 0xFF;
	destCharPtr[2] = (inPF>>8) & 0xFF;
	destCharPtr[3] = (inPF) & 0xFF;
	destCharPtr[4] = 0;
	return [NSString stringWithCString:destCharPtr encoding:NSASCIIStringEncoding];
}




unsigned int SwizzleShaderImageInfoGetBytesPerRow(SwizzleShaderImageInfo *inInfo)	{
	unsigned int		inWidth = inInfo->res[0];
	SwizzlePF			inPF = inInfo->pf;
	unsigned int		bytesPerRow = 0;
	
	unsigned int		widthRoundedUYVY = inWidth + (inWidth % 2);
	//unsigned int		heightRoundedUp = inHeight + (inHeight % 2);
	//unsigned int		widthRoundedDXT = inWidth + (inWidth % 4);
	//unsigned int		heightRoundedDXT = inHeight + (inHeight % 4);
	
	switch (inPF)	{
	case SwizzlePF_Unknown:					bytesPerRow = 0;		break;
	
	case SwizzlePF_Luma_PK_UI_8:			bytesPerRow = 8 * 1 * inWidth / 8;		break;
	case SwizzlePF_Luma_PK_FP_32:			bytesPerRow = 32 * 1 * inWidth / 8;		break;
	
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBX_PK_UI_8:
	case SwizzlePF_BGRA_PK_UI_8:
	case SwizzlePF_BGRX_PK_UI_8:
	case SwizzlePF_ARGB_PK_UI_8:			bytesPerRow = 8 * 4 * inWidth / 8;		break;
	
	case SwizzlePF_RGBA_PK_FP_32:			bytesPerRow = 32 * 4 * inWidth / 8;		break;
	
	case SwizzlePF_HSVA_PK_UI_8:
	case SwizzlePF_CMYK_PK_UI_8:			bytesPerRow = 8 * 4 * inWidth / 8;		break;
	
	case SwizzlePF_UYVY_PK_422_UI_8:
	case SwizzlePF_YUYV_PK_422_UI_8:		bytesPerRow = 8 * 2 * widthRoundedUYVY / 8;		break;
	case SwizzlePF_UYVY_PK_422_UI_10:		bytesPerRow = ((inWidth + 47) / 48) * 128;		break;
	
	case SwizzlePF_UYVA_PKPL_422_UI_8:		bytesPerRow = 8 * 2 * widthRoundedUYVY / 8;		break;
	case SwizzlePF_UYVY_PKPL_422_UI_16:		bytesPerRow = 16 * widthRoundedUYVY / 8;		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:		bytesPerRow = 16 * widthRoundedUYVY / 8;		break;
	
	case SwizzlePF_UYVY_PKPL_420_UI_8:		bytesPerRow = 8 * widthRoundedUYVY / 8;		break;
	case SwizzlePF_UYVY_PL_420_UI_8:		bytesPerRow = 8 * widthRoundedUYVY / 8;		break;
	
	//case SwizzlePF_RGB_PK_YCoCg:			bytesPerRow = 8 * widthRoundedDXT / 8;		break;
	//case SwizzlePF_RGB_PKPL_YCoCgA:			bytesPerRow = 8 * widthRoundedDXT / 8;		break;
	}
	
	return bytesPerRow;
}
unsigned int SwizzleShaderImageInfoGetLength(SwizzleShaderImageInfo *inInfo)	{
	if (inInfo == nil)
		return 0;
	
	unsigned int			returnMe = 0;
	
	int				lastPlane = inInfo->planeCount - 1;
	unsigned int			lastPlaneOffset = inInfo->planes[lastPlane].offset;
	unsigned int			lastPlaneBytesPerRow = inInfo->planes[lastPlane].bytesPerRow;
	
	switch (inInfo->pf)	{
	case SwizzlePF_Unknown:
		break;
	
	case SwizzlePF_Luma_PK_UI_8:
	case SwizzlePF_Luma_PK_FP_32:
	
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBX_PK_UI_8:
	case SwizzlePF_BGRA_PK_UI_8:
	case SwizzlePF_BGRX_PK_UI_8:
	case SwizzlePF_ARGB_PK_UI_8:
	
	case SwizzlePF_RGBA_PK_FP_32:
	
	case SwizzlePF_HSVA_PK_UI_8:
	case SwizzlePF_CMYK_PK_UI_8:
	
	case SwizzlePF_UYVY_PK_422_UI_8:
	case SwizzlePF_YUYV_PK_422_UI_8:
	case SwizzlePF_UYVY_PK_422_UI_10:
	
	case SwizzlePF_UYVA_PKPL_422_UI_8:
	case SwizzlePF_UYVY_PKPL_422_UI_16:
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		returnMe = lastPlaneOffset + (lastPlaneBytesPerRow * inInfo->res[1]);
		break;
		
	case SwizzlePF_UYVY_PKPL_420_UI_8:
	case SwizzlePF_UYVY_PL_420_UI_8:
		returnMe = lastPlaneOffset + (lastPlaneBytesPerRow * inInfo->res[1] / 2);
		break;
	
	//case SwizzlePF_RGB_PK_YCoCg:
	//	returnMe = inInfo->res[0] * inInfo->res[1];
	//	break;
	//case SwizzlePF_RGB_PKPL_YCoCgA:	//	YCoCg is 1 byte per pixel, A is stored as RGTC1 which is 8 bytes per 4x4 pixel block for a total of 1.5 bytes per pixel.
	//	returnMe = (((inInfo->res[0] * inInfo->res[1]) / 2) * 3);
	//	break;
	}
	
	return returnMe;
}


SwizzleShaderImageInfo MakeSwizzleShaderImageInfo(SwizzlePF inPF, unsigned int inWidth, unsigned int inHeight)	{
	SwizzleShaderImageInfo		tmpInfo;
	//	populate the struct we'll be returning enough to calculate its bytes per row as per the above function
	tmpInfo.pf = inPF;
	tmpInfo.res[0] = inWidth;
	tmpInfo.res[1] = inHeight;
	tmpInfo.planeCount = 1;
	//	calculate the bytes per row
	unsigned int			bytesPerRow = SwizzleShaderImageInfoGetBytesPerRow(&tmpInfo);
	//	return a fully populated struct via a standard method
	return MakeSwizzleShaderImageInfoWithBytesPerRow(inPF, inWidth, inHeight, bytesPerRow);
}


SwizzleShaderImageInfo MakeSwizzleShaderImageInfoWithBytesPerRow(SwizzlePF inPF, unsigned int inWidth, unsigned int inHeight, unsigned int inBytesPerRow)	{
	
	SwizzleShaderImageInfo		returnMe;
	returnMe.pf = inPF;
	returnMe.res[0] = inWidth;
	returnMe.res[1] = inHeight;
	//returnMe.bytesPerRow = inBytesPerRow;
	switch (inPF)	{
	
	case SwizzlePF_Unknown:
		returnMe.planeCount = 1;
		break;
	
	case SwizzlePF_Luma_PK_UI_8:
	case SwizzlePF_Luma_PK_FP_32:
	
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBX_PK_UI_8:
	case SwizzlePF_BGRA_PK_UI_8:
	case SwizzlePF_BGRX_PK_UI_8:
	case SwizzlePF_ARGB_PK_UI_8:
	
	case SwizzlePF_RGBA_PK_FP_32:
	
	case SwizzlePF_HSVA_PK_UI_8:
	case SwizzlePF_CMYK_PK_UI_8:
	
	case SwizzlePF_UYVY_PK_422_UI_8:
	case SwizzlePF_YUYV_PK_422_UI_8:
	case SwizzlePF_UYVY_PK_422_UI_10:
		returnMe.planeCount = 1;
		returnMe.planes[0].offset = 0;
		returnMe.planes[0].bytesPerRow = inBytesPerRow;
		break;
	
	case SwizzlePF_UYVA_PKPL_422_UI_8:
		returnMe.planeCount = 2;
		returnMe.planes[0].offset = 0;
		returnMe.planes[0].bytesPerRow = inBytesPerRow;
		returnMe.planes[1].offset = returnMe.planes[0].offset + (returnMe.res[1] * inBytesPerRow);
		returnMe.planes[1].bytesPerRow = inBytesPerRow / 2;
		break;
	case SwizzlePF_UYVY_PKPL_422_UI_16:
		returnMe.planeCount = 2;
		returnMe.planes[0].offset = 0;
		returnMe.planes[0].bytesPerRow = inBytesPerRow;
		returnMe.planes[1].offset = returnMe.planes[0].offset + (returnMe.res[1] * inBytesPerRow);
		returnMe.planes[1].bytesPerRow = inBytesPerRow;
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		returnMe.planeCount = 3;
		returnMe.planes[0].offset = 0;
		returnMe.planes[0].bytesPerRow = inBytesPerRow;
		returnMe.planes[1].offset = returnMe.planes[0].offset + (returnMe.res[1] * inBytesPerRow);
		returnMe.planes[1].bytesPerRow = inBytesPerRow;
		returnMe.planes[2].offset = returnMe.planes[1].offset + (returnMe.res[1] * inBytesPerRow);
		returnMe.planes[2].bytesPerRow = inBytesPerRow;
		break;
	
	case SwizzlePF_UYVY_PKPL_420_UI_8:
		returnMe.planeCount = 2;
		returnMe.planes[0].offset = 0;
		returnMe.planes[0].bytesPerRow = inBytesPerRow;
		returnMe.planes[1].offset = returnMe.planes[0].offset + (inBytesPerRow * returnMe.res[1]);
		returnMe.planes[1].bytesPerRow = inBytesPerRow;
		break;
	
	case SwizzlePF_UYVY_PL_420_UI_8:
		returnMe.planeCount = 3;
		returnMe.planes[0].offset = 0;
		returnMe.planes[0].bytesPerRow = inBytesPerRow;
		returnMe.planes[1].offset = returnMe.planes[0].offset + (inBytesPerRow * returnMe.res[1]);
		returnMe.planes[1].bytesPerRow = inBytesPerRow;
		returnMe.planes[2].offset = returnMe.planes[1].offset + (inBytesPerRow * returnMe.res[1]);
		returnMe.planes[2].bytesPerRow = inBytesPerRow;
		break;
	
	//case SwizzlePF_RGB_PK_YCoCg:
	//	returnMe.planeCount = 1;
	//	returnMe.planes[0].offset = 0;
	//	returnMe.planes[0].bytesPerRow = inBytesPerRow;
	//	break;
	//case SwizzlePF_RGB_PKPL_YCoCgA:
	//	{
	//		//unsigned int		widthRoundedDXT = inWidth + (inWidth % 4);
	//		unsigned int		heightRoundedDXT = inHeight + (inHeight % 4);
	//		returnMe.planeCount = 2;
	//		returnMe.planes[0].offset = 0;
	//		returnMe.planes[0].bytesPerRow = inBytesPerRow;
	//		returnMe.planes[1].offset = returnMe.planes[0].offset + (inBytesPerRow * heightRoundedDXT);
	//		returnMe.planes[1].bytesPerRow = inBytesPerRow / 2;
	//	}
	//	break;
	}
	return returnMe;
}


BOOL SwizzleShaderImageInfoEquality(SwizzleShaderImageInfo *a, SwizzleShaderImageInfo *b)	{
	if (a == nil && b == nil)
		return YES;
	if ((a == nil && b != nil) || (a != nil && b == nil))
		return NO;
	
	if (a->pf != b->pf)
		return NO;
	
	for (int i=0; i<2; ++i)	{
		if (a->res[i] != b->res[i])
			return NO;
	}
	
	if (a->planeCount != b->planeCount)
		return NO;
	
	for (int i=0; i<a->planeCount; ++i)	{
		if (a->planes[i].offset != b->planes[i].offset)
			return NO;
		if (a->planes[i].bytesPerRow != b->planes[i].bytesPerRow)
			return NO;
	}
	
	return YES;
}
BOOL SwizzleShaderImageInfoFormatMatch(SwizzleShaderImageInfo *a, SwizzleShaderImageInfo *b)	{
	if (a == nil && b == nil)
		return YES;
	if ((a == nil && b != nil) || (a != nil && b == nil))
		return NO;
	
	if (a->pf != b->pf)
		return NO;
	
	for (int i=0; i<2; ++i)	{
		if (a->res[i] != b->res[i])
			return NO;
	}
	
	if (a->planeCount != b->planeCount)
		return NO;
	
	//	don't bother checking offset or bytes per row- we're just checking for pixel format, res, and plane count matches...
	//for (int i=0; i<a->planeCount; ++i)	{
	//	if (a->planes[i].offset != b->planes[i].offset)
	//		return NO;
	//	if (a->planes[i].bytesPerRow != b->planes[i].bytesPerRow)
	//		return NO;
	//}
	
	return YES;
}




SwizzleShaderOpInfo MakeSwizzleShaderOpInfo(SwizzleShaderImageInfo inSrc, SwizzleShaderImageInfo inDst)	{
	SwizzleShaderOpInfo		returnMe;
	returnMe.srcImg = inSrc;
	returnMe.dstImg = inDst;
	returnMe.srcImgFrameInDst = MakeRect(0,0,inDst.res[0],inDst.res[1]);
	returnMe.flipH = false;
	returnMe.flipV = false;
	returnMe.fadeToBlack = 0.0;
	returnMe.readSrcImgFromBuffer = false;
	//returnMe.dstPixelsToProcess = XXX;	//	NO do not do this here, the backend populates this at runtime during rendering
	returnMe.dstPixelsToProcess[0] = 0;	//	doesn't matter, populated by swizzler
	returnMe.dstPixelsToProcess[1] = 0;
	return returnMe;
}

