//
//  BilinearInterpolation.metal
//  VVMetalKit
//
//  Created by testadmin on 4/25/22.
//

#include <metal_stdlib>
using namespace metal;

#include "BilinearInterpolation.h"



//#define LERP(a,b,mix) ((a * (1. - mix)) + (b * mix))

static inline float Lerp(float a, float b, float mix)	{
	return (a * (1. - mix)) + (b * mix);
}

//static inline float3 Lerp3(float3 a, float3 b, float mix)	{
//	return float3( Lerp(a.x, b.x, mix), Lerp(a.y, b.y, mix), Lerp(a.z, b.z, mix) );
//}

static inline float4 Lerp4(float4 a, float4 b, float mix)	{
	return float4( Lerp(a.x, b.x, mix), Lerp(a.y, b.y, mix), Lerp(a.z, b.z, mix), Lerp(a.w, b.w, mix) );
	//return float4( LERP(a.x, b.x, mix), LERP(a.y, b.y, mix), LERP(a.z, b.z, mix), LERP(a.w, b.w, mix) );
}

float4 BilinearInterpolation(float4 topLeft, float4 topRight, float4 botLeft, float4 botRight, float2 mix)	{
	float4			topVal = Lerp4(topLeft, topRight, mix.x);
	float4			botVal = Lerp4(botLeft, botRight, mix.x);
	return Lerp4(topVal, botVal, mix.y);
}

