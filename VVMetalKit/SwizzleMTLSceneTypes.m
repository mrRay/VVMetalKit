//
//  SwizzleMTLSceneTypes.m
//  VVMetalKit
//
//  Created by testadmin on 3/1/22.
//

#import <Foundation/Foundation.h>
#import "SwizzleMTLSceneTypes.h"
#include "SizingTool_c.h"





SwizzleShaderImageInfo MakeSwizzleShaderImageInfo(SwizzlePF inPF, unsigned int inWidth, unsigned int inHeight, unsigned int inBytesPerRow)	{
	SwizzleShaderImageInfo		returnMe;
	returnMe.pf = inPF;
	returnMe.res[0] = inWidth;
	returnMe.res[1] = inHeight;
	//returnMe.bytesPerRow = inBytesPerRow;
	switch (inPF)	{
	case SwizzlePF_Unknown:
		returnMe.planeCount = 0;
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
		returnMe.planeCount = 1;
		returnMe.planes[0].offset = 0;
		returnMe.planes[0].bytesPerRow = inBytesPerRow;
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

