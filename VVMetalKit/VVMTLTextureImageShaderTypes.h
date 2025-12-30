//
//  VVMTLTextureImageShaderTypes.h
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#ifndef VVMTLTextureImageShaderTypes_h
#define VVMTLTextureImageShaderTypes_h


#include <VVMetalKit/SizingToolTypes.h>

#include <simd/simd.h>




//	Contains properties of VVMTLTextureImage used to render that texture properly in a shader




typedef enum VVMTLTextureImageStructAlphaRenderMode {
	VVMTLTextureImageStructAlphaRenderMode_AppliedAlpha = 0,	//	The color of the image is modulated by its alpha channel (if the alpha channel is opaque, you can see the image- if it's transparent, you can see whatever's behind it)
	VVMTLTextureImageStructAlphaRenderMode_NoAlpha,	//	The alpha channel of the image to be displayed is ignored, the RGB channels are displayed
	VVMTLTextureImageStructAlphaRenderMode_OnlyAlpha	//	The RGB channels are disregarded, and instead a black and white image of the alpha channel is rendered
} VVMTLTextureImageStructAlphaRenderMode;


typedef struct VVMTLTextureImageStruct	{
	GRect			srcRectCart;	//	the region of the passed texture that contains the image we want to work with.  origin is BOTTOM LEFT CORNER of the image as it's loaded natively (cartesian coords)
	GRect			srcRectMtl;	//	same meaning as 'srcRectCart', but the origin is the TOP LEFT CORNER of the image as it's loaded (metal compatible coords)
	GRect			dstRect;	//	the rect at which 'srcRect' should be drawn, in whatever context it is being drawn.  origin is TOP LEFT CORNER of the context!
	bool			flipV;	//	whether or not the texture in 'srcRect' is flipped vertically compared to the orientation of 'dstRect'
	bool			flipH;	//	whether or not the texture in 'srcRect' is flipped horizontally compared to the orientation of 'dstRect'
	simd_float4		colorMultiplier;	//	multiply the sampled color by these vals, component-by-component
	VVMTLTextureImageStructAlphaRenderMode		alphaRenderMode;
} VVMTLTextureImageStruct;




#endif /* VVMTLTextureImageShaderTypes_h */
