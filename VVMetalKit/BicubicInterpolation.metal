//
//  BicubicInterpolation.metal
//  VVMetalKit
//
//  Created by testadmin on 4/25/22.
//

#include <metal_stdlib>
using namespace metal;

#include "BicubicInterpolation.h"




static inline float CubicHermite(float a, float b, float c, float d, float t)	{
	float		a1 = -a / 2. + (3. * b) / 2. - (3. * c) / 2. + d / 2.;
	float		b1 = a - (5. * b) / 2. + 2. * c - d / 2.;
	float		c1 = -a / 2. + c / 2.;
	float		d1 = b;
	
	return (a1 * t * t * t) + (b1 * t * t) + (c1 * t) + d1;
}


float4 BicubicInterpolation(thread float4 * rowA, thread float4 * rowB, thread float4 * rowC, thread float4 * rowD, thread float2 & interp)
{
	float4		returnMe;
	for (int i=0; i<4; ++i)	{
		float		colA = CubicHermite( (*(rowA+0))[i], (*(rowA+1))[i], (*(rowA+2))[i], (*(rowA+3))[i], interp.x );
		float		colB = CubicHermite( (*(rowB+0))[i], (*(rowB+1))[i], (*(rowB+2))[i], (*(rowB+3))[i], interp.x );
		float		colC = CubicHermite( (*(rowC+0))[i], (*(rowC+1))[i], (*(rowC+2))[i], (*(rowC+3))[i], interp.x );
		float		colD = CubicHermite( (*(rowD+0))[i], (*(rowD+1))[i], (*(rowD+2))[i], (*(rowD+3))[i], interp.x );
		
		float		val = clamp(CubicHermite(colA, colB, colC, colD, interp.y), 0., 1.);
		
		returnMe[i] = val;
	}
	return returnMe;
}


