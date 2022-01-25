//
//  VVColorConversions.h
//  VVMetalKit
//
//  Created by testadmin on 1/24/22.
//

#ifndef VVColorConversions_h
#define VVColorConversions_h




#define APPLE_GAMMA_196 (1.960938f)




//	the following constants and functions are only defined for metal!
#ifdef __METAL_VERSION__


constant float3x3 kTransMatrix_YCbCr_to_RGB_601{
	{ 1.164, 1.164, 1.164 },
	{ 0.0, -0.392, 2.017 },
	{ 1.596, -0.813, 0.0 }
};
constant float3x3 kTransMatrix_YCbCr_to_RGB_709{
	{ 1.1644, 1.1644, 1.1644 },
	{ 0.0, -0.2132, 2.1124 },
	{ 1.7927, -0.5329, 0.0 }
};
constant float3x3 kTransMatrix_YCbCr_to_RGB_Full{
	{ 1.0, 1.0, 1.0 },
	{ 0.0, -0.344, 1.773 },
	{ 1.403, -0.714, 0.0 }
};
constant float3x3 kTransMatrix_YCbCr_to_RGB_SD{
	{ 1.0, 1.0, 1.0 },
	{ 0.0, -0.344, 1.772 },
	{ 1.402, -0.714, 0. }
};
constant float3x3 kTransMatrix_YCbCr_to_RGB_HD{
	{ 1.0, 1.0, 1.0 },
	{ 0.0, -0.187, 1.856 },
	{ 1.575, -0.468, 0.0 }
};


constant float3x3 kTransMatrix_RGB_to_YCbCr_601{
	{ 0.257, -0.148, 0.439 },
	{ 0.504, -0.291, -0.368 },
	{ 0.098, 0.439, -0.071 }
};
constant float3x3 kTransMatrix_RGB_to_YCbCr_709{
	{ 0.183, -0.101, 0.439 },
	{ 0.614, -0.339, -0.399 },
	{ 0.062, 0.439, -0.040 }
};
constant float3x3 kTransMatrix_RGB_to_YCbCr_Full{
	{ 0.299, -0.168736, 0.5 },
	{ 0.587, -0.331264, -0.418688 },
	{ 0.114, 0.5, -0.081312 }
};
constant float3x3 kTransMatrix_RGB_to_YCbCr_SD{
	{ 0.299, -0.169, 0.5 },
	{ 0.587, -0.331, -0.419 },
	{ 0.114, 0.5, -0.081 }
};
constant float3x3 kTransMatrix_RGB_to_YCbCr_HD{
	{ 0.213, -0.115, 0.5 },
	{ 0.715, -0.385, -0.454 },
	{ 0.072, 0.5, -0.046 }
};


constexpr constant float3 kTransOffset_YCbCr_to_RGB_601{ 16./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_YCbCr_to_RGB_709{ 16./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_YCbCr_to_RGB_Full{ 0./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_YCbCr_to_RGB_SD{ 0./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_YCbCr_to_RGB_HD{ 0./255., 128./255., 128./255. };

constexpr constant float3 kTransOffset_RGB_to_YCbCr_601{ 16./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_RGB_to_YCbCr_709{ 16./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_RGB_to_YCbCr_Full{ 0./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_RGB_to_YCbCr_SD{ 0./255., 128./255., 128./255. };
constexpr constant float3 kTransOffset_RGB_to_YCbCr_HD{ 0./255., 128./255., 128./255. };


float3 GammaConvert_BT709_nonLinearToLinear(float3 nonlinear);
float3 GammaConvert_Apple196_nonLinearToLinear(float3 nonlinear);
float3 GammaConvert_sRGB_nonLinearToLinear(float3 nonlinear);
float3 GammaConvert_sRGB_nonLinearToLinearCustomGamma(float3 nonlinear, float gamma);

float3 GammaConvert_BT709_linearToNonlinear(float3 linear);
float3 GammaConvert_Apple196_linearToNonlinear(float3 linear);
float3 GammaConvert_sRGB_linearToNonlinear(float3 linear);
float3 GammaConvert_sRGB_linearToNonlinearCustomGamma(float3 linear, float gamma);


#endif




#endif /* VVColorConversions_h */
