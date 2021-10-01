//
//  SwizzleMTLSceneTypes.h
//  VVMetalKit
//
//  Created by testAdmin on 9/22/21.
//

#ifndef SwizzleMTLSceneTypes_h
#define SwizzleMTLSceneTypes_h




//	these are the swizzle pixel formats supported by "SwizzleMTLScene"
typedef enum SwizzlePF	{
	SwizzlePF_Unknown = 0,
	SwizzlePF_RGBA_PK_UI_8 = 'RGBA',	//	8 bit unsigned int per channel (32 bits per pixel)
	SwizzlePF_RGBX_PK_UI_8 = 'RGBX',
	SwizzlePF_BGRA_PK_UI_8 = 'BGRA',
	SwizzlePF_BGRX_PK_UI_8 = 'BGRX',
	SwizzlePF_ARGB_PK_UI_8 = 32,
	SwizzlePF_RGBA_PK_FP_32 = 'RGfA',	//	32 bit float per channel (128 bits per pixel)
	SwizzlePF_UYVY_PK_422_UI_8 = '2vuy',
	SwizzlePF_UYVY_PK_422_UI_10 = 'v210',
	SwizzlePF_UYVA_PKPL_422_UI_8 = 'UYVA',	//	semi-planar: basically a 2vuy data blob followed by a 1-channel, 8-bit alpha image
	SwizzlePF_UYVY_PKPL_422_UI_16 = 'p216',	//	semi-planar: first plane is 16 bit single-channel luminance, second plane is 16-bit single-channel Cb/Cr
	SwizzlePF_UYVA_PKPL_422_UI_16 = 'PA16',	//	'p216', with an additional (third) plane consisting of 16-bit single-channel alpha channel
} SwizzlePF;




//	this struct contains some basic properties we need when reading images from or writing images to memory
typedef struct	{
	SwizzlePF		pf;
	unsigned int	res[2];
	unsigned int	bytesPerRow;
} SwizzleShaderImageInfo;




//	the max # of pixels that we'll want to process in a single execution unit on the GPU (it makes sense to process "chunks" of pixels when outputting to some packed pixel formats)
#define MAX_PIXELS_TO_PROCESS 6

//#define MAX_NUM_CHANNELS 3




//	this struct is how we pass info about the source and destination pixel formats to the shader
typedef struct	{
	SwizzleShaderImageInfo		srcImg;
	SwizzleShaderImageInfo		dstImg;
	
	//	must never exceed 'MAX_PIXELS_TO_PROCESS'! the # of pixels in the destination image to process per execution unit of the compute shader.  rgb is 1, 2vuy is probably 2, v210 is probably 6, etc
	unsigned int				dstPixelsToProcess;	//	populated automatically by the backend, but you'll want to read it in shaders
} SwizzleShaderInfo;




//	this enumerates the args that are passed to the swizzle compute shader
typedef enum SwizzleShaderArg	{
	SwizzleShaderArg_SrcBuffer,
	SwizzleShaderArg_SrcRGBTexture,
	SwizzleShaderArg_DstBuffer,
	SwizzleShaderArg_DstRGBTexture,
	SwizzleShaderArg_Info
} SwizzleShaderArg;




#endif /* SwizzleMTLSceneTypes_h */
