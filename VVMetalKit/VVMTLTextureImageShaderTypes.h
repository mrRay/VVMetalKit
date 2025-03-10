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




typedef struct VVMTLTextureImageStruct	{
	GRect			srcRectCart;	//	the region of the passed texture that contains the image we want to work with.  origin is BOTTOM LEFT CORNER of the image as it's loaded natively (cartesian coords)
	GRect			srcRectMtl;	//	same meaning as 'srcRectCart', but the origin is the TOP LEFT CORNER of the image as it's loaded (metal compatible coords)
	GRect			dstRect;	//	the rect at which 'srcRect' should be drawn, in whatever context it is being drawn.  origin is TOP LEFT CORNER of the context!
	bool			flipV;	//	whether or not the texture in 'srcRect' is flipped vertically compared to the orientation of 'dstRect'
	bool			flipH;	//	whether or not the texture in 'srcRect' is flipped horizontally compared to the orientation of 'dstRect'
	simd_float4		colorMultiplier;	//	multiply the sampled color by these vals, component-by-component
} VVMTLTextureImageStruct;




#endif /* VVMTLTextureImageShaderTypes_h */
