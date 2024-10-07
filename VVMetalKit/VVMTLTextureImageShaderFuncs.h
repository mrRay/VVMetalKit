//
//  VVMTLTextureImageShaderFuncs.h
//  VVMetalKit
//
//  Created by testadmin on 10/2/24.
//

#ifndef VVMTLTextureImageShaderFuncs_h
#define VVMTLTextureImageShaderFuncs_h

#include <VVMetalKit/SizingTool_metal.h>
#include <VVMetalKit/VVMTLTextureImageShaderTypes.h>


//	the following constants and functions are only defined for metal!
#ifdef __METAL_VERSION__


//	'normSampleLoc' is normalized and uses a cartesian coordinate space
static inline float4 NormSampleImage(texture2d<float, access::sample> inSampler, constant VVMTLTextureImageStruct * inImgData, thread GPoint * normSampleLoc)	{
	if (is_null_texture(inSampler))
		return float4(0,0,0,1);
	
	constexpr sampler		linearSampler(filter::linear, coord::pixel, address::clamp_to_edge);
	
	//	pixel-based coords, metal coordinate system
	GRect		sampleRegion_pxl_mcs = inImgData->srcRectMtl;
	
	//	sample location is already normalized- account for flippedness and conversion to the metal coordinate space
	GPoint		sampleLoc = { normSampleLoc->x, 1.0-normSampleLoc->y };
	if (inImgData->flipV)	{
		sampleLoc.y = 1.0 - sampleLoc.y;
	}
	if (inImgData->flipH)	{
		sampleLoc.x = 1.0 - sampleLoc.x;
	}
	
	//	convert the normalized sample location to a pixel location within the region we're sampling
	GPoint		sampleLoc_pxl_mcs = PixelForNormCoordsInRect(sampleLoc, sampleRegion_pxl_mcs);
	
	//	sample the texture and return the color
	return inSampler.sample( linearSampler, float2(sampleLoc_pxl_mcs.x, sampleLoc_pxl_mcs.y) );
}


#endif	//	__METAL_VERSION__



#endif /* VVMTLTextureImageShaderFuncs_h */
