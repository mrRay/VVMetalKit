//
//  VVColorConversions.metal
//  VVMetalKit
//
//  Created by testadmin on 1/24/22.
//

#include <metal_stdlib>
using namespace metal;

#include "VVColorConversions.h"






#ifdef __METAL_VERSION__


#pragma mark - inverse compounding (nonlinear -> linear)




static inline float GammaConvert_BT709_nonLinearToLinear(float nonlinear)	{
	const float		xIntercept = 0.081;
	float			linear;
	if (nonlinear <= xIntercept)	{
		linear = nonlinear * (1. / 4.5);
	}
	else	{
		const float		a = 0.099;
		const float		gamma = 1. / 0.45;	// 2.2
		linear = (nonlinear + a) * (1. / (1. + a));
		linear = pow(linear, gamma);
	}
	return linear;
}
static inline float GammaConvert_Apple196_nonLinearToLinear(float nonlinear)	{
	const float		xIntercept = 0.05583828;
	float			linear;
	if (nonlinear < xIntercept)	{
		linear = nonlinear * (1. / 16.0);
	}
	else	{
		const float		gamma = APPLE_GAMMA_196;
		linear = pow(nonlinear, gamma);
	}
	return linear;
}
static inline float GammaConvert_sRGB_nonLinearToLinear(float nonlinear)	{
	const float		xIntercept = 0.0405;
	float			linear;
	if (nonlinear <= xIntercept)	{
		linear = nonlinear / 12.92;
	}
	else	{
		linear = pow((nonlinear + 0.055) / 1.055, 2.4);
	}
	return linear;
}
static inline float GammaConvert_sRGB_nonLinearToLinearCustomGamma(float nonlinear, float gamma)	{
	const float		xIntercept = 0.0405;
	float			linear;
	if (nonlinear <= xIntercept)	{
		linear = nonlinear / 12.92;
	}
	else	{
		linear = pow((nonlinear + 0.055) / 1.055, gamma);
	}
	return linear;
}


float3 GammaConvert_BT709_nonLinearToLinear(float3 nonlinear)	{
	return float3(
		GammaConvert_BT709_nonLinearToLinear(nonlinear.r),
		GammaConvert_BT709_nonLinearToLinear(nonlinear.g),
		GammaConvert_BT709_nonLinearToLinear(nonlinear.b)
	);
}
float3 GammaConvert_Apple196_nonLinearToLinear(float3 nonlinear)	{
	return float3(
		GammaConvert_Apple196_nonLinearToLinear(nonlinear.r),
		GammaConvert_Apple196_nonLinearToLinear(nonlinear.g),
		GammaConvert_Apple196_nonLinearToLinear(nonlinear.b)
	);
}
float3 GammaConvert_sRGB_nonLinearToLinear(float3 nonlinear)	{
	return float3(
		GammaConvert_sRGB_nonLinearToLinear(nonlinear.r),
		GammaConvert_sRGB_nonLinearToLinear(nonlinear.g),
		GammaConvert_sRGB_nonLinearToLinear(nonlinear.b)
	);
}
float3 GammaConvert_sRGB_nonLinearToLinearCustomGamma(float3 nonlinear, float gamma)	{
	return float3(
		GammaConvert_sRGB_nonLinearToLinearCustomGamma(nonlinear.r, gamma),
		GammaConvert_sRGB_nonLinearToLinearCustomGamma(nonlinear.g, gamma),
		GammaConvert_sRGB_nonLinearToLinearCustomGamma(nonlinear.b, gamma)
	);
}




#pragma mark - compounding (linear -> nonlinear)




static inline float GammaConvert_BT709_linearToNonlinear(float linear)	{
	const float		xIntercept = 0.018;
	float			nonlinear;
	if (linear <= xIntercept)	{
		nonlinear = linear * 4.5;
	}
	else	{
		const float		a = 0.099;
		const float		gamma = 1. / 0.45;	//	2.2
		nonlinear = a + ( pow(linear, 1./gamma) * (1. + a) );
	}
	return nonlinear;
}
static inline float GammaConvert_Apple196_linearToNonlinear(float linear)	{
	if (linear <= 0.0034898925)	{
		return 16. * linear;
	}
	else	{
		const float		gamma = APPLE_GAMMA_196;
		return pow(linear, 1.0/gamma);
	}
}
static inline float GammaConvert_sRGB_linearToNonlinear(float linear)	{
	if (linear <= 0.0031308)	{
		return 12.92 * linear;
	}
	else	{
		return 1.055 * pow(linear, 1./2.4) - 0.055;
	}
}
static inline float GammaConvert_sRGB_linearToNonlinearCustomGamma(float linear, float gamma)	{
	float		nonlinear;
	if (linear <= 0.0031308)	{
		nonlinear = 12.92 * linear;
	}
	else	{
		nonlinear = 1.055 * pow(linear, 1./gamma) - 0.055;
	}
	return nonlinear;
}


float3 GammaConvert_BT709_linearToNonlinear(float3 linear)	{
	return float3(
		GammaConvert_BT709_linearToNonlinear(linear.r),
		GammaConvert_BT709_linearToNonlinear(linear.g),
		GammaConvert_BT709_linearToNonlinear(linear.b)
	);
}
float3 GammaConvert_Apple196_linearToNonlinear(float3 linear)	{
	return float3(
		GammaConvert_Apple196_linearToNonlinear(linear.r),
		GammaConvert_Apple196_linearToNonlinear(linear.g),
		GammaConvert_Apple196_linearToNonlinear(linear.b)
	);
}
float3 GammaConvert_sRGB_linearToNonlinear(float3 linear)	{
	return float3(
		GammaConvert_sRGB_linearToNonlinear(linear.r),
		GammaConvert_sRGB_linearToNonlinear(linear.g),
		GammaConvert_sRGB_linearToNonlinear(linear.b)
	);
}
float3 GammaConvert_sRGB_linearToNonlinearCustomGamma(float3 linear, float gamma)	{
	return float3(
		GammaConvert_sRGB_linearToNonlinearCustomGamma(linear.r, gamma),
		GammaConvert_sRGB_linearToNonlinearCustomGamma(linear.g, gamma),
		GammaConvert_sRGB_linearToNonlinearCustomGamma(linear.b, gamma)
	);
}



#endif



