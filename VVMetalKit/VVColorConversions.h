//
//  VVColorConversions.h
//  VVMetalKit
//
//  Created by testadmin on 1/24/22.
//

#ifndef VVColorConversions_h
#define VVColorConversions_h




//	the following constants and functions are only defined for metal!
#ifdef __METAL_VERSION__

#include <metal_stdlib>

using namespace metal;

#define APPLE_GAMMA_196 (1.960938f)




//	---------------------------------------------------------------------------
//	Primaries/range reference for the RGB<->YCbCr constants below. Every matrix is derived to 6 decimal 
//	places from its BT primaries with the standard non-constant-luminance (NCL) formulas 
//	(video-range = luma x 219/255, chroma x 224/255; full-range = no scaling).  Forward (RGB->YCbCr) and 
//	inverse (YCbCr->RGB) for each colorimetry are exact mathematical inverses at this precision.  The 
//	historical names encode the RANGE implicitly, which has caused confusion- consult this table rather 
//	than guessing from the suffix.  Names are retained for backward compatibility; same-colorimetry 
//	names (e.g. _SD and _Full) hold IDENTICAL values.
//	
//	  constant       | primaries | range  | luma coeff sum  | offset.r
//	  ---------------+-----------+--------+-----------------+---------
//	  _601           | 601       | video  | 0.858824(219/255)| 16/255
//	  _709           | 709       | video  | 0.858824(219/255)| 16/255
//	  _BT2020Video   | 2020      | video  | 0.858824(219/255)| 16/255
//	  _SD / _Full    | 601       | full   | 1.0   (255/255) | 0
//	  _HD            | 709       | full   | 1.0   (255/255) | 0
//	  _BT2020        | 2020      | full   | 1.0   (255/255) | 0
//	
//	Note _HD is BT.709 FULL-range (the historically confusing name), and _SD is BT.601 full-range, 
//	identical to _Full.  The primaries x range grid is now complete: the BT.2020 VIDEO-range cell was 
//	the one missing combination and is added below as _BT2020Video.
//	---------------------------------------------------------------------------
//
//the {..} groups are COLUMNS (Metal float3x3 is column-major).  for the forward (RGB->YCbCr) matrices the columns are the R, G, B contributions to {Y,Cb,Cr}; for the inverse (YCbCr->RGB) matrices the columns are the Y, Cb, Cr contributions to {R,G,B}.

constant float3x3 kTransMatrix_YCbCr_to_RGB_601{
	{ 1.164384, 1.164384, 1.164384 },
	{ 0.0, -0.391762, 2.017232 },
	{ 1.596027, -0.812968, 0.0 }
};
constant float3x3 kTransMatrix_YCbCr_to_RGB_709{
	{ 1.164384, 1.164384, 1.164384 },
	{ 0.0, -0.213249, 2.112402 },
	{ 1.792741, -0.532909, 0.0 }
};
//	BT.601 full-range.  FIXES the prior _Full inverse, which had 1.773/1.403 where
//	the correct BT.601 full-range values are 1.772/1.402 (== _SD, same colorimetry).
constant float3x3 kTransMatrix_YCbCr_to_RGB_Full{
	{ 1.0, 1.0, 1.0 },
	{ 0.0, -0.344136, 1.772 },
	{ 1.402, -0.714136, 0.0 }
};
//	BT.601 full-range, identical to _Full (same colorimetry, different historical name).
constant float3x3 kTransMatrix_YCbCr_to_RGB_SD{
	{ 1.0, 1.0, 1.0 },
	{ 0.0, -0.344136, 1.772 },
	{ 1.402, -0.714136, 0.0 }
};
constant float3x3 kTransMatrix_YCbCr_to_RGB_HD{
	{ 1.0, 1.0, 1.0 },
	{ 0.0, -0.187324, 1.8556 },
	{ 1.5748, -0.468124, 0.0 }
};
constant float3x3 kTransMatrix_YCbCr_to_RGB_BT2020{
	{ 1.0, 1.0, 1.0 },
	{ 0.0, -0.164553, 1.8814 },
	{ 1.4746, -0.571353, 0.0 }
};
//	BT.2020 video-range (the previously-missing grid cell- NOT a duplicate).
constant float3x3 kTransMatrix_YCbCr_to_RGB_BT2020Video{
	{ 1.164384, 1.164384, 1.164384 },
	{ 0.0, -0.187326, 2.141772 },
	{ 1.678674, -0.650424, 0.0 }
};


constant float3x3 kTransMatrix_RGB_to_YCbCr_601{
	{ 0.256788, -0.148223, 0.439216 },
	{ 0.504129, -0.290993, -0.367788 },
	{ 0.097906, 0.439216, -0.071427 }
};
constant float3x3 kTransMatrix_RGB_to_YCbCr_709{
	{ 0.182586, -0.100644, 0.439216 },
	{ 0.614231, -0.338572, -0.398942 },
	{ 0.062007, 0.439216, -0.040274 }
};
constant float3x3 kTransMatrix_RGB_to_YCbCr_Full{
	{ 0.299, -0.168736, 0.5 },
	{ 0.587, -0.331264, -0.418688 },
	{ 0.114, 0.5, -0.081312 }
};
//	BT.601 full-range, identical to _Full (was a 3-decimal rounding of it; now brought into exact agreement).
constant float3x3 kTransMatrix_RGB_to_YCbCr_SD{
	{ 0.299, -0.168736, 0.5 },
	{ 0.587, -0.331264, -0.418688 },
	{ 0.114, 0.5, -0.081312 }
};
constant float3x3 kTransMatrix_RGB_to_YCbCr_HD{
	{ 0.2126, -0.114572, 0.5 },
	{ 0.7152, -0.385428, -0.454153 },
	{ 0.0722, 0.5, -0.045847 }
};
constant float3x3 kTransMatrix_RGB_to_YCbCr_BT2020{
	{ 0.2627, -0.13963, 0.5 },
	{ 0.678, -0.36037, -0.459786 },
	{ 0.0593, 0.5, -0.040214 }
};
//	BT.2020 video-range (the previously-missing grid cell- NOT a duplicate).
constant float3x3 kTransMatrix_RGB_to_YCbCr_BT2020Video{
	{ 0.225613, -0.122655, 0.439216 },
	{ 0.582282, -0.316560, -0.403890 },
	{ 0.050928, 0.439216, -0.035325 }
};


constexpr constant float3 kTransOffset_YCbCr_to_RGB_601{ 16./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_YCbCr_to_RGB_709{ 16./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_YCbCr_to_RGB_Full{ 0./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_YCbCr_to_RGB_SD{ 0./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_YCbCr_to_RGB_HD{ 0./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_YCbCr_to_RGB_BT2020{ 0./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_YCbCr_to_RGB_BT2020Video{ 16./255., 128./255., 128./255. };

constexpr constant float3 kTransOffset_RGB_to_YCbCr_601{ 16./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_RGB_to_YCbCr_709{ 16./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_RGB_to_YCbCr_Full{ 0./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_RGB_to_YCbCr_SD{ 0./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_RGB_to_YCbCr_HD{ 0./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_RGB_to_YCbCr_BT2020{ 0./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_RGB_to_YCbCr_BT2020Video{ 16./255., 128./255., 128./255. };


//	normalized RGB->YCbCr clamp limits for the swizzle encode.  there are only ever three cases:
//	legacy (no clamp- the historical default), video-range, and full-range.  defined here as constant
//	globals so the shader can reference them (by pointer) instead of materializing them per call.
constexpr constant float3 kSwizzleYCbCrClampLo_Video{ 16./255., 16./255., 16./255. };
constexpr constant float3 kSwizzleYCbCrClampHi_Video{ 235./255., 240./255., 240./255. };
constexpr constant float3 kSwizzleYCbCrClampLo_Full { 0., 0., 0. };
constexpr constant float3 kSwizzleYCbCrClampHi_Full { 1., 1., 1. };


static inline float3 GammaConvert_BT709_nonLinearToLinear(float3 nonlinear);
static inline float3 GammaConvert_Apple196_nonLinearToLinear(float3 nonlinear);
static inline float3 GammaConvert_sRGB_nonLinearToLinear(float3 nonlinear);
static inline float3 GammaConvert_sRGB_nonLinearToLinearCustomGamma(float3 nonlinear, float gamma);

static inline float3 GammaConvert_BT709_linearToNonlinear(float3 linear);
static inline float3 GammaConvert_Apple196_linearToNonlinear(float3 linear);
static inline float3 GammaConvert_sRGB_linearToNonlinear(float3 linear);
static inline float3 GammaConvert_sRGB_linearToNonlinearCustomGamma(float3 linear, float gamma);


//	range is 0.-1. for all of these RGB/HSV conversions
static inline float3 RGBtoHSV(float3 inRGB);
static inline float3 HSVtoRGB(float3 inHSV);

static inline float3 RGBtoHSL(float3 inRGB);
static inline float3 HSLtoRGB(float3 inHSL);

static inline float Hue_2_RGB( float v1, float v2, float vH );	//	backend method

//	range is 0.-1. for this conversion
static inline float RGBtoLuma(float3 inRGB);




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


static inline float3 GammaConvert_BT709_nonLinearToLinear(float3 nonlinear)	{
	return float3(
		GammaConvert_BT709_nonLinearToLinear(nonlinear.r),
		GammaConvert_BT709_nonLinearToLinear(nonlinear.g),
		GammaConvert_BT709_nonLinearToLinear(nonlinear.b)
	);
}
static inline float3 GammaConvert_Apple196_nonLinearToLinear(float3 nonlinear)	{
	return float3(
		GammaConvert_Apple196_nonLinearToLinear(nonlinear.r),
		GammaConvert_Apple196_nonLinearToLinear(nonlinear.g),
		GammaConvert_Apple196_nonLinearToLinear(nonlinear.b)
	);
}
static inline float3 GammaConvert_sRGB_nonLinearToLinear(float3 nonlinear)	{
	return float3(
		GammaConvert_sRGB_nonLinearToLinear(nonlinear.r),
		GammaConvert_sRGB_nonLinearToLinear(nonlinear.g),
		GammaConvert_sRGB_nonLinearToLinear(nonlinear.b)
	);
}
static inline float3 GammaConvert_sRGB_nonLinearToLinearCustomGamma(float3 nonlinear, float gamma)	{
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


static inline float3 GammaConvert_BT709_linearToNonlinear(float3 linear)	{
	return float3(
		GammaConvert_BT709_linearToNonlinear(linear.r),
		GammaConvert_BT709_linearToNonlinear(linear.g),
		GammaConvert_BT709_linearToNonlinear(linear.b)
	);
}
static inline float3 GammaConvert_Apple196_linearToNonlinear(float3 linear)	{
	return float3(
		GammaConvert_Apple196_linearToNonlinear(linear.r),
		GammaConvert_Apple196_linearToNonlinear(linear.g),
		GammaConvert_Apple196_linearToNonlinear(linear.b)
	);
}
static inline float3 GammaConvert_sRGB_linearToNonlinear(float3 linear)	{
	return float3(
		GammaConvert_sRGB_linearToNonlinear(linear.r),
		GammaConvert_sRGB_linearToNonlinear(linear.g),
		GammaConvert_sRGB_linearToNonlinear(linear.b)
	);
}
static inline float3 GammaConvert_sRGB_linearToNonlinearCustomGamma(float3 linear, float gamma)	{
	return float3(
		GammaConvert_sRGB_linearToNonlinearCustomGamma(linear.r, gamma),
		GammaConvert_sRGB_linearToNonlinearCustomGamma(linear.g, gamma),
		GammaConvert_sRGB_linearToNonlinearCustomGamma(linear.b, gamma)
	);
}


#pragma mark - HSV/HSL


static inline float3 RGBtoHSV(float3 inRGB)	{
	//float		h,s,v;
	float3		returnMe;
	
	float		var_Min = fmin( inRGB.r, fmin(inRGB.g, inRGB.b) );	// Min. value of RGB
	float		var_Max = fmax( inRGB.r, fmax(inRGB.g, inRGB.b) );	// Max. value of RGB
	float		del_Max = var_Max - var_Min;	// Delta RGB value 
	
	returnMe.b = var_Max;
	
	if ( del_Max == 0 )	// This is a gray, no chroma...
	{
		returnMe.r = 0;	// HSV results from 0 to 1
		returnMe.g = 0;
	}
	else	// Chromatic data...
	{
		returnMe.g = del_Max / var_Max;
		
		float		del_R = ( ( ( var_Max - inRGB.r ) / 6. ) + ( del_Max / 2. ) ) / del_Max;
		float		del_G = ( ( ( var_Max - inRGB.g ) / 6. ) + ( del_Max / 2. ) ) / del_Max;
		float		del_B = ( ( ( var_Max - inRGB.b ) / 6. ) + ( del_Max / 2. ) ) / del_Max;
		
		if ( inRGB.r == var_Max )
			returnMe.r = del_B - del_G;
		else if ( inRGB.g == var_Max )
			returnMe.r = ( 1. / 3. ) + del_R - del_B;
		//else if ( inRGB.b == var_Max )
		else
			returnMe.r = ( 2. / 3. ) + del_G - del_R;
		
		if ( returnMe.r < 0. )
			returnMe.r += 1;
		if ( returnMe.r > 1. )
			returnMe.r -= 1.;
	}
	
	return returnMe;
}
static inline float3 HSVtoRGB(float3 inHSV)	{
	
	float3		returnMe;
	
	if ( inHSV.g == 0. )	// HSV from 0 to 1
	{
		returnMe.r = inHSV.b;
		returnMe.g = inHSV.b;
		returnMe.b = inHSV.b;
	}
	else
	{
		float		var_h = inHSV.r * 6.;
		if ( var_h == 6 )
			var_h = 0;	// H must be < 1
		int		var_i = (int)var_h;	// Or ... var_i = floor( var_h )
		float		var_1 = inHSV.b * ( 1. - inHSV.g );
		float		var_2 = inHSV.b * ( 1. - inHSV.g * ( var_h - var_i ) );
		float		var_3 = inHSV.b * ( 1. - inHSV.g * ( 1. - ( var_h - var_i ) ) );
		
		if ( var_i == 0 ) {
			returnMe.r = inHSV.b;
			returnMe.g = var_3;
			returnMe.b = var_1;
		}
		else if ( var_i == 1 ) {
			returnMe.r = var_2;
			returnMe.g = inHSV.b;
			returnMe.b = var_1;
		}
		else if ( var_i == 2 ) {
			returnMe.r = var_1;
			returnMe.g = inHSV.b;
			returnMe.b = var_3;
		}
		else if ( var_i == 3 ) {
			returnMe.r = var_1;
			returnMe.g = var_2;
			returnMe.b = inHSV.b;
		}
		else if ( var_i == 4 ) {
			returnMe.r = var_3;
			returnMe.g = var_1;
			returnMe.b = inHSV.b;
		}
		else {
			returnMe.r = inHSV.b;
			returnMe.g = var_1;
			returnMe.b = var_2;
		}
	}
	
	return returnMe;
}


static inline float3 RGBtoHSL(float3 inRGB)	{
	
	float3		returnMe;

	float		var_Min = fmin( inRGB.r, fmin(inRGB.g, inRGB.b) );	// Min. value of RGB
	float		var_Max = fmax( inRGB.r, fmax(inRGB.g, inRGB.b) );	// Max. value of RGB
	float		del_Max = var_Max - var_Min;	// Delta RGB value
	
	returnMe.b = ( var_Max + var_Min ) / 2.;
	
	if ( del_Max == 0. )            // This is a gray, no chroma...
	{
		returnMe.r = 0;	// HSL results from 0 to 1
		returnMe.g = 0;
	}
	else	// Chromatic data...
	{
		if ( returnMe.b < 0.5 )
			returnMe.g = del_Max / ( var_Max + var_Min );
		else
			returnMe.g = del_Max / ( 2. - var_Max - var_Min );
		
		float		del_R = ( ( ( var_Max - inRGB.r ) / 6. ) + ( del_Max / 2. ) ) / del_Max;
		float		del_G = ( ( ( var_Max - inRGB.g ) / 6. ) + ( del_Max / 2. ) ) / del_Max;
		float		del_B = ( ( ( var_Max - inRGB.b ) / 6. ) + ( del_Max / 2. ) ) / del_Max;
		
		if ( inRGB.r == var_Max )
			returnMe.r = del_B - del_G;
		else if ( inRGB.g == var_Max )
			returnMe.r = ( 1. / 3. ) + del_R - del_B;
		//else if ( inRGB.b == var_Max )
		else
			returnMe.r = ( 2. / 3. ) + del_G - del_R;
		
		if ( returnMe.r < 0. )
			returnMe.r += 1.;
		if ( returnMe.r > 1. )
			returnMe.r -= 1.;
	}
	
	return returnMe;
}
static inline float3 HSLtoRGB(float3 inHSL)	{
	
	//float		r,g,b;
	float3		returnMe;
	
	if ( inHSL.g == 0. )
	{
		returnMe.r = inHSL.b;
		returnMe.g = inHSL.b;
		returnMe.b = inHSL.b;
	}
	else
	{
		float		var_1, var_2;
		
		if ( inHSL.b < 0.5 )
			var_2 = inHSL.b * ( 1. + inHSL.g );
		else
			var_2 = ( inHSL.b + inHSL.g ) - ( inHSL.g * inHSL.b );
		
		var_1 = 2. * inHSL.b - var_2;
		
		
		
		
		returnMe.r = Hue_2_RGB( var_1, var_2, inHSL.r + ( 1. / 3. ) ) ;
		returnMe.g = Hue_2_RGB( var_1, var_2, inHSL.r );
		returnMe.b = Hue_2_RGB( var_1, var_2, inHSL.r - ( 1. / 3. ) );
	}
	
	return returnMe;
}


static inline float Hue_2_RGB( float v1, float v2, float vH )	{
	float		var_vH = vH;
	if ( var_vH < 0. )
		var_vH += 1.;
	if ( var_vH > 1. )
		var_vH -= 1.;
	if ( ( 6. * var_vH ) < 1. )
		return ( v1 + ( v2 - v1 ) * 6. * var_vH );
	if ( ( 2. * var_vH ) < 1. )
		return ( v2 );
	if ( ( 3. * var_vH ) < 2. )
		return ( v1 + ( v2 - v1 ) * ( ( 2. / 3. ) - var_vH ) * 6. );
	return ( v1 );
};


static inline float RGBtoLuma(float3 inRGB)	{
	float		returnMe;

	//float		var_Min = fmin( inRGB.r, fmin(inRGB.g, inRGB.b) );	// Min. value of RGB
	//float		var_Max = fmax( inRGB.r, fmax(inRGB.g, inRGB.b) );	// Max. value of RGB
	//returnMe = ( var_Max + var_Min ) / 2.;
	
	returnMe = 0.2126*inRGB.r + 0.7152*inRGB.g + 0.0722*inRGB.b;
	
	return returnMe;
}


static inline float RGBtoSaturation(float3 inRGB) {
	float		var_Min = fmin( inRGB.r, fmin(inRGB.g, inRGB.b) );	// Min. value of RGB
	float		var_Max = fmax( inRGB.r, fmax(inRGB.g, inRGB.b) );	// Max. value of RGB
	
	return ( var_Max + var_Min ) / 2.;
}


#endif		//	__METAL_VERSION__




#endif /* VVColorConversions_h */
