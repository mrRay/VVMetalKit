#ifndef MTLImgBufferShaderTypes_h
#define MTLImgBufferShaderTypes_h

#import <TargetConditionals.h>
#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
#include <VVMetalKitTouch/SizingToolTypes.h>
#else
#include <VVMetalKit/SizingToolTypes.h>
#endif
//#include "SizingToolTypes.h"

#include <simd/simd.h>




typedef struct MTLImgBufferStruct	{
	GRect			srcRect;	//	the region of the passed texture that contains the image we want to work with.  origin is BOTTOM LEFT CORNER of the image as it's loaded natively
	GRect			dstRect;	//	the rect at which 'srcRect' should be drawn, in whatever context it is being drawn.  origin is TOP LEFT CORNER of the context!
	bool			flipV;	//	whether or not the texture in 'srcRect' is flipped vertically compared to the orientation of 'dstRect'
	bool			flipH;	//	whether or not the texture in 'srcRect' is flipped horizontally compared to the orientation of 'dstRect'
	simd_float4		colorMultiplier;	//	multiply the sampled color by these vals, component-by-component
} MTLImgBufferStruct;




#endif /* MTLImgBufferShaderTypes_h */
