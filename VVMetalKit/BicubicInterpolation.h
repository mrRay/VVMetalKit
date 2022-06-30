//
//  BicubicInterpolation.h
//  VVMetalKit
//
//  Created by testadmin on 4/25/22.
//

#ifndef BicubicInterpolation_h
#define BicubicInterpolation_h



//	the following constants and functions are only defined for metal!
#ifdef __METAL_VERSION__



/*	
	cubic hermite interpolation
	- linear interpolation's easy, you can calculate the value at interpolation time "t" between values "B" and "C" linearly
	- downside to linear interpolation: sharp inflections from pixel to pixel if the slope of the line interpolating between the values changes sharply
	- example: interpolating linearly from 0 to 1 to 0 again would result in a sawtooth.  sawtooths have lots of grey- but if the goal is to interpolate smoothly between input values, and your input values are 0 and 1, and the majority of your output values are neither 0 nor 1, things could be better.
	- this problem can be eliminated if you instead try to draw a spline through your values
	- a "lagrange polynomial" is the lowest-order polynomial that interpolates a given data set.
	- hermite interpolation is a method of calculating interpolation values of the lagrange polynomial for a given dataset
	- this function interpolates value "t", which is asserted to be somewhere between the values "B" and "C"
	- as "t" approaches 0 (and becomes closer to value "B"), we need value "A" (which occurs before "B") to inform its interpolation
	- as "t" approaches 1 (and becomes closer to value "C"), we need value "D" (which occurs after "C") to inform its interpolation
	- ...so we need to sample a 4x4 matrix of pixels around the point we want to sample.  linear interpolation: sample 4.  bicubic interpolation: sample 16.
*/
static inline float CubicHermite(float a, float b, float c, float d, float t);

float4 BicubicInterpolation(thread float4 * rowA, thread float4 * rowB, thread float4 * rowC, thread float4 * rowD, thread float2 & interp);




#endif


#endif /* BicubicInterpolation_h */
