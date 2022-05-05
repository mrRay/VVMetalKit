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




size_t SwizzleShaderImageInfoGetLength(SwizzleShaderImageInfo *inInfo)	{
	if (inInfo == nil)
		return 0;
	
	size_t			returnMe = 0;
	
	int				lastPlane = inInfo->planeCount - 1;
	size_t			lastPlaneOffset = inInfo->planes[lastPlane].offset;
	size_t			lastPlaneBytesPerRow = inInfo->planes[lastPlane].bytesPerRow;
	
	switch (inInfo->pf)	{
	case SwizzlePF_Unknown:
		break;
	
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBX_PK_UI_8:
	case SwizzlePF_BGRA_PK_UI_8:
	case SwizzlePF_BGRX_PK_UI_8:
	case SwizzlePF_ARGB_PK_UI_8:
	
	case SwizzlePF_RGBA_PK_FP_32:
	
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
	}
	
	return returnMe;
}


SwizzleShaderImageInfo MakeSwizzleShaderImageInfo(SwizzlePF inPF, unsigned int inWidth, unsigned int inHeight)	{
	unsigned int		bytesPerRow = 0;
	
	unsigned int		widthRoundedUYVY = inWidth + (inWidth % 2);
	//unsigned int		heightRoundedUp = inHeight + (inHeight % 2);
	
	switch (inPF)	{
	case SwizzlePF_Unknown:					bytesPerRow = 0;		break;
	
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBX_PK_UI_8:
	case SwizzlePF_BGRA_PK_UI_8:
	case SwizzlePF_BGRX_PK_UI_8:
	case SwizzlePF_ARGB_PK_UI_8:			bytesPerRow = 8 * 4 * inWidth / 8;		break;
	
	case SwizzlePF_RGBA_PK_FP_32:			bytesPerRow = 32 * 4 * inWidth / 8;		break;
	
	case SwizzlePF_UYVY_PK_422_UI_8:
	case SwizzlePF_YUYV_PK_422_UI_8:		bytesPerRow = 8 * 2 * widthRoundedUYVY / 8;		break;
	case SwizzlePF_UYVY_PK_422_UI_10:		bytesPerRow = ((inWidth + 47) / 48) * 128;		break;
	
	case SwizzlePF_UYVA_PKPL_422_UI_8:		bytesPerRow = 8 * 3 * widthRoundedUYVY / 8;		break;
	case SwizzlePF_UYVY_PKPL_422_UI_16:		bytesPerRow = 16 * 2 * widthRoundedUYVY / 8;		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:		bytesPerRow = 16 * 3 * widthRoundedUYVY / 8;		break;
	
	case SwizzlePF_UYVY_PKPL_420_UI_8:		bytesPerRow = 8 * 2 * widthRoundedUYVY / 8;		break;
	case SwizzlePF_UYVY_PL_420_UI_8:		bytesPerRow = 8 * 2 * widthRoundedUYVY / 8;		break;
	}
	
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
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBX_PK_UI_8:
	case SwizzlePF_BGRA_PK_UI_8:
	case SwizzlePF_BGRX_PK_UI_8:
	case SwizzlePF_ARGB_PK_UI_8:
	
	case SwizzlePF_RGBA_PK_FP_32:
	
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
		returnMe.planes[1].offset = returnMe.planes[0].offset + (returnMe.res[1] * returnMe.planes[0].bytesPerRow);
		returnMe.planes[1].bytesPerRow = inBytesPerRow/2;
		break;
	case SwizzlePF_UYVY_PKPL_422_UI_16:
		returnMe.planeCount = 2;
		returnMe.planes[0].offset = 0;
		returnMe.planes[0].bytesPerRow = inBytesPerRow;
		returnMe.planes[1].offset = returnMe.planes[0].offset + (returnMe.res[1] * returnMe.planes[0].bytesPerRow);
		returnMe.planes[1].bytesPerRow = inBytesPerRow;
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		returnMe.planeCount = 3;
		returnMe.planes[0].offset = 0;
		returnMe.planes[0].bytesPerRow = inBytesPerRow;
		returnMe.planes[1].offset = returnMe.planes[0].offset + (returnMe.res[1] * returnMe.planes[0].bytesPerRow);
		returnMe.planes[1].bytesPerRow = inBytesPerRow;
		returnMe.planes[2].offset = returnMe.planes[1].offset + (returnMe.res[1] * returnMe.planes[1].bytesPerRow);
		returnMe.planes[2].bytesPerRow = inBytesPerRow;
		break;
	
	case SwizzlePF_UYVY_PKPL_420_UI_8:
		returnMe.planeCount = 2;
		returnMe.planes[0].offset = 0;
		returnMe.planes[0].bytesPerRow = inBytesPerRow;
		returnMe.planes[1].offset = (inBytesPerRow * returnMe.res[1]);
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
	}
	return returnMe;
}




SwizzleShaderOpInfo MakeSwizzleShaderOpInfo(SwizzleShaderImageInfo inSrc, SwizzleShaderImageInfo inDst)	{
	SwizzleShaderOpInfo		returnMe;
	returnMe.srcImg = inSrc;
	returnMe.dstImg = inDst;
	returnMe.srcImgFrame = MakeRect(0,0,inDst.res[0],inDst.res[1]);
	returnMe.flipH = false;
	returnMe.flipV = false;
	returnMe.fadeToBlack = 0.0;
	returnMe.readSrcImgFromBuffer = false;
	//returnMe.dstPixelsToProcess = XXX;	//	NO do not do this here, the backend populates this at runtime during rendering
	returnMe.dstPixelsToProcess[0] = 0;	//	doesn't matter, populated by swizzler
	returnMe.dstPixelsToProcess[1] = 0;
	return returnMe;
}

