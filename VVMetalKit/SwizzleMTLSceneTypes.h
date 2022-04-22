//
//  SwizzleMTLSceneTypes.h
//  VVMetalKit
//
//  Created by testAdmin on 9/22/21.
//

#ifndef SwizzleMTLSceneTypes_h
#define SwizzleMTLSceneTypes_h

//#include <VVMetalKit/SizingToolTypes.h>
#import <TargetConditionals.h>
#if TARGET_OS_IOS
#include <VVMetalKitTouch/SizingToolTypes.h>
#else
#include <VVMetalKit/SizingToolTypes.h>
#endif
//#include "SizingToolTypes.h"




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
	SwizzlePF_YUYV_PK_422_UI_8 = 'yuvs',
	SwizzlePF_UYVY_PK_422_UI_10 = 'v210',
	
	SwizzlePF_UYVA_PKPL_422_UI_8 = 'UYVA',	//	semi-planar: basically a 2vuy data blob followed by a 1-channel, 8-bit alpha image
	SwizzlePF_UYVY_PKPL_422_UI_16 = 'p216',	//	semi-planar: first plane is 16 bit single-channel luminance, second plane is 16-bit single-channel Cb/Cr
	SwizzlePF_UYVA_PKPL_422_UI_16 = 'PA16',	//	'p216', with an additional (third) plane consisting of 16-bit single-channel alpha channel
	
	SwizzlePF_UYVY_PKPL_420_UI_8 = '420f',	//	bi-planar (2 planes, Y/CbCr) YCbCr 8-bit 4:2:0 full-range (luma=[0,255] chroma=[1,255]).
	
	SwizzlePF_UYVY_PL_420_UI_8 = 'y420',	//	planar (3 planes, Y/Cb/Cr) YCbCr 8-bit 4:2:0 full-range (luma=[0,255] chroma=[1,255]).
	
	//SwizzlePF_BGR_PKPL_FL_16 = 'APP0',	//	'Apple Proprietary Pixelformat 0'.  semi-planar, half-float per channel, three channels per pixel.  all the B values, followed by all the G values, followed by all the R values.
} SwizzlePF;

#ifdef __METAL_VERSION__
#else
	#if defined __cplusplus
	extern "C" {
	#endif
		
		NSString * NSStringFromSwizzlePF(SwizzlePF inPF);
		
	#if defined __cplusplus
	};
	#endif
#endif





//	the max # of pixels that we'll want to process in a single execution unit on the GPU (it makes sense to process "chunks" of pixels when outputting to some packed pixel formats)
#define MAX_PIXELS_TO_PROCESS_WIDTH 6
#define MAX_PIXELS_TO_PROCESS_HEIGHT 6
#define MAX_PIXELS_TO_PROCESS 6
#define MAX_NUM_PLANES 3
//#define MAX_NUM_CHANNELS 3




typedef struct	{
	unsigned int	offset;	//	the offset in bytes into the plane at which the image data starts.  may exist to align data, or to specify a plane in a single large MTLBuffer that contains multiple planes
	unsigned int	bytesPerRow;	//	the number of bytes per row of image data used for this plane.  used to accommodate data layouts that have padding.
} SwizzleShaderImagePlaneInfo;




//	this struct contains some basic properties we need when reading images from or writing images to memory
typedef struct	{
	SwizzlePF		pf;	//	the pixel format of the image as it is stored in memory
	unsigned int	res[2];
	
	unsigned int	planeCount;
	SwizzleShaderImagePlaneInfo		planes[MAX_NUM_PLANES];
	
} SwizzleShaderImageInfo;

#ifdef __METAL_VERSION__
#else
size_t SwizzleShaderImageInfoGetLength(SwizzleShaderImageInfo *inInfo);
SwizzleShaderImageInfo MakeSwizzleShaderImageInfo(SwizzlePF inPF, unsigned int inWidth, unsigned int inHeight);
SwizzleShaderImageInfo MakeSwizzleShaderImageInfoWithBytesPerRow(SwizzlePF inPF, unsigned int inWidth, unsigned int inHeight, unsigned int inBytesPerRow);
#endif




//	this struct is how we pass info about the images and operation to the swizzle shader
typedef struct	{
	SwizzleShaderImageInfo		srcImg;
	SwizzleShaderImageInfo		dstImg;
	
	GRect			srcImgFrame;	//	the src image is to be drawn within this rect.  may be bigger or smaller than the dst image.
	bool			flipH;	//	if true, this image's contents should be flipped horizontally on retrieval
	bool			flipV;	//	if true, this image's contents should be flipped vertically on retrieval
	float			fadeToBlack;	//	if 1.0, this image is faded to black.  if 0.0, the image is unaltered.
	
	//	-------	you should not have to populate the following vars (backend should handle them automatically)
	
	bool			readSrcImgFromBuffer;	//	populated automatically by the backend, but you'll want to read it in shaders.  if YES, we need to pull the src image out of the src image buffer.  if NO, we need to pull the src image out of the src img texture.  (we can no longer just pass a nil texture and check for that in the shader, as the metal debugger doesn't work unless all attachments are non-nil)
	unsigned int	dstPixelsToProcess[2];	//	populated automatically by the backend, but you'll want to read it in shaders.  must never exceed 'MAX_PIXELS_TO_PROCESS'! the # of pixels in the destination image to process per execution unit of the compute shader.  rgb is 1, 2vuy is probably 2, v210 is probably 6, etc
} SwizzleShaderOpInfo;

//	returned op info struct automatically attempts to draw 'srcImage' in the bounds of 'dstImg' (if they have different aspect ratios, this will result in distortion)
SwizzleShaderOpInfo MakeSwizzleShaderOpInfo(SwizzleShaderImageInfo inSrc, SwizzleShaderImageInfo inDst);




//	this enumerates the args that are passed to the swizzle compute shader
typedef enum SwizzleShaderArg	{
	SwizzleShaderArg_SrcBuffer,
	SwizzleShaderArg_SrcRGBTexture,
	SwizzleShaderArg_DstBuffer,
	SwizzleShaderArg_DstRGBTexture,
	SwizzleShaderArg_OpInfo,
	SwizzleShaderArg_WriteBuffer	//	boolean, whether or not to try and write to the output buffer
} SwizzleShaderArg;




#endif /* SwizzleMTLSceneTypes_h */
