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
	returnMe.bytesPerRow = inBytesPerRow;
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
	returnMe.dstPixelsToProcess = 0;	//	doesn't matter, populated by swizzler
	return returnMe;
}

