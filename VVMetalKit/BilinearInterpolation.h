//
//  BilinearInterpolation.h
//  VVMetalKit
//
//  Created by testadmin on 4/25/22.
//

#ifndef BilinearInterpolation_h
#define BilinearInterpolation_h




//	the following constants and functions are only defined for metal!
#ifdef __METAL_VERSION__


static inline float Lerp(float a, float b, float mix);

//static inline float3 Lerp3(float3 a, float3 b, float mix);

static inline float4 Lerp4(float4 a, float4 b, float mix);

//	'topLeft', 'topRight', 'botLeft', 'botRight' are the vals that will be interpolated between and form four corners of a box
//	'mix' is assumed to be normalized (ranged 0-1) and describes the value we want to calculate via bilinear interpolation
float4 BilinearInterpolation(float4 topLeft, float4 topRight, float4 botLeft, float4 botRight, float2 mix);


#endif




#endif /* BilinearInterpolation_h */
