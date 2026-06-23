//
//  SwizzleMTLSceneTypes.h
//  VVMetalKit
//
//  Created by testAdmin on 9/22/21.
//

#ifndef SwizzleMTLSceneTypes_h
#define SwizzleMTLSceneTypes_h

#include <VVMetalKit/SizingToolTypes.h>




///	Enumerates the swizzle pixel formats supported by ``SwizzleMTLScene``
typedef enum SwizzlePF	{
	SwizzlePF_Unknown = 0,
	
	SwizzlePF_Luma_PK_UI_8 = 'L008',	///	8 bit unsigned int per channel, one channel per pixel (8 bits per pixel)
	SwizzlePF_Luma_PK_FP_32 = 'L00f',	///	32-bit (4 byte) float per channel, one channel per pixel (32 bits per pixel)
	
	SwizzlePF_RGBA_PK_UI_8 = 'RGBA',	///	8 bit unsigned int per channel (32 bits per pixel), packed RGBA.
	SwizzlePF_RGBX_PK_UI_8 = 'RGBX',	///	8 bit unsigned int per channel (32 bits per pixel), packed RGB- no alpha, but padded.
	SwizzlePF_BGRA_PK_UI_8 = 'BGRA',	///	8 bit unsigned int per channel (32 bits per pixel), packed BGRA.
	SwizzlePF_BGRX_PK_UI_8 = 'BGRX',	///	8 bit unsigned int per channel (32 bits per pixel), packed BGR- no alpha, but padded.
	SwizzlePF_ARGB_PK_UI_8 = 32,	///	Same as SwizzlePF_RGBA_PK_UI_8.
	SwizzlePF_RGBA_PK_FP_32 = 'RGfA',	///	32 bit float per channel (128 bits per pixel), packed RGBA.
	
	SwizzlePF_HSVA_PK_UI_8 = 'HSV8',	///	8 bit unsigned int per channel (32 bits per pixel), packed HSVB
	SwizzlePF_CMYK_PK_UI_8 = 'CMY8',	///	8 bit unsigned int per channel (32 bits per pixel), packed CMYK
	
	SwizzlePF_UYVY_PK_422_UI_8 = '2vuy',	///	Also known as 'uyvy'- packed image data with 4:2:2 subsampling.  Effectively two channels per pixel, alternating "uy" and "vy".
	SwizzlePF_YUYV_PK_422_UI_8 = 'yuvs',	///	Packed image data with 4:2:2 subsampling.  Effectively two channels per pixel, alternating "yu" and "yv".
	SwizzlePF_UYVY_PK_422_UI_10 = 'v210',	///	Same layout as 'uyvy' (packed with 4:2:2 subsampling), but all values are 10-bit.
	
	SwizzlePF_UYVA_PKPL_422_UI_8 = 'UYVA',	//	Semi-planar: basically a 2vuy data blob followed by a 1-channel, 8-bit alpha image.
	SwizzlePF_UYVY_PKPL_422_UI_16 = 'p216',	//	Semi-planar: first plane is 16 bit single-channel luminance, second plane is 16-bit single-channel Cb/Cr.
	SwizzlePF_UYVA_PKPL_422_UI_16 = 'PA16',	//	'p216', with an additional (third) plane consisting of 16-bit single-channel alpha channel.
	
	SwizzlePF_UYVY_PKPL_420_UI_8 = '420f',	//	Bi-planar (2 planes, Y/CbCr) YCbCr 8-bit 4:2:0.  This value names the byte LAYOUT only; the luma/chroma range (video vs full) is selected by SwizzleShaderOpInfo.colorRange, not by this enum.

	SwizzlePF_UYVY_PL_420_UI_8 = 'y420',	//	Planar (3 planes, Y/Cb/Cr) YCbCr 8-bit 4:2:0.  Layout only; range is selected by SwizzleShaderOpInfo.colorRange (see SwizzlePF_UYVY_PKPL_420_UI_8).
	
	//SwizzlePF_RGB_PK_YCoCg = 'DYt5',	//	emitted by Hap ecosystem.  scaled YCoCg in S3TC RGBA DXT5.
	//SwizzlePF_RGB_PKPL_YCoCgA = 'DYtA',	//	emitted by Hap ecosystem.  two planes, first plane is 'DYt5', second plane is an alpha channel.
	//SwizzlePF_BGR_PKPL_FL_16 = 'APP0',	//	'Apple Proprietary Pixelformat 0'.  semi-planar, half-float per channel, three channels per pixel.  all the B values, followed by all the G values, followed by all the R values.
} SwizzlePF;




///	Selects the YCbCr side's signal RANGE for a swizzle op- the SOURCE range when decoding YCbCr->RGB, the DESTINATION range when encoding RGB->YCbCr.  Orthogonal to ``SwizzlePF`` (which names only the byte layout) and to ``SwizzleColorPrimaries``.  A YCbCr->YCbCr swizzle shares one range for both ends.
typedef enum SwizzleColorRange	{
	///	The historical behavior: use the video-range coefficients/offset but do NOT clamp.  Same formula as the pre-colorRange shader (the matrices were since bumped to higher precision, so output can differ by up to ~1 code value).  This is the zero value so default/zero-initialized op-info keeps the legacy behavior.
	SwizzleColorRange_legacy = 0,
	///	Video-range (luma=[16,235], chroma=[16,240]), clamped to those limits.
	SwizzleColorRange_video,
	///	Full-range (luma=[0,255], chroma=[0,255]), clamped to [0,255].
	SwizzleColorRange_full,
} SwizzleColorRange;


///	Selects the YCbCr side's PRIMARIES (and thus the luma/chroma matrix family) for a swizzle op- the SOURCE primaries when decoding YCbCr->RGB, the DESTINATION primaries when encoding RGB->YCbCr.  Orthogonal to ``SwizzlePF`` and to ``SwizzleColorRange``.  A YCbCr->YCbCr swizzle shares one set of primaries for both ends.
typedef enum SwizzleColorPrimaries	{
	///	The historical behavior: BT.709 primaries.  This is the zero value so default/zero-initialized op-info keeps the legacy (709) output.
	SwizzleColorPrimaries_legacy = 0,	//	== 709
	///	BT.601 primaries (Kr=0.299, Kb=0.114).
	SwizzleColorPrimaries_601,
	///	BT.709 primaries (Kr=0.2126, Kb=0.0722).
	SwizzleColorPrimaries_709,
	///	BT.2020 (non-constant-luminance) primaries (Kr=0.2627, Kb=0.0593).
	SwizzleColorPrimaries_2020,
} SwizzleColorPrimaries;

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




///	Describes the arrangement of data in one plane of an image.
typedef struct	{
	unsigned int	offset;	///	The offset in bytes into the plane at which the image data starts.  May exist to align data, or to specify a plane in a single large MTLBuffer that contains multiple planes
	unsigned int	bytesPerRow;	///	The number of bytes per row of image data used for this plane.  Used to accommodate data layouts that have padding.
} SwizzleShaderImagePlaneInfo;




///	This struct describes how an image you want to swizzle is represented in memory.  The easiest way to generate it is by calling ``MakeSwizzleShaderImageInfo`` or ``MakeSwizzleShaderImageInfoWithBytesPerRow``.
typedef struct	{
	///	The pixel format of the image as it is stored in memory.
	SwizzlePF		pf;
	///	The resolution of the image.
	unsigned int	res[2];
	
	///	The number of planes in the image.
	unsigned int	planeCount;
	///	Describes how each image plane's data is represented in memory.  The number of planes is determined by `planeCount`.
	SwizzleShaderImagePlaneInfo		planes[MAX_NUM_PLANES];
	
} SwizzleShaderImageInfo;




#ifdef __METAL_VERSION__
#else

#if defined __cplusplus
extern "C" {
#endif
	///	Calculates the bytes per row of the passed info object.  The returned value assumes that there isn't any padding.
	unsigned int SwizzleShaderImageInfoGetBytesPerRow(SwizzleShaderImageInfo *inInfo);
	///	Calculates the amount of memory required to represent an image described by the passed struct.
	unsigned int SwizzleShaderImageInfoGetLength(SwizzleShaderImageInfo *inInfo);
	///	Generates a ``SwizzleShaderImageInfo`` struct using the passed values.
	SwizzleShaderImageInfo MakeSwizzleShaderImageInfo(SwizzlePF inPF, unsigned int inWidth, unsigned int inHeight);
	///	Generates a ``SwizzleShaderImageInfo`` struct using the passed values.
	SwizzleShaderImageInfo MakeSwizzleShaderImageInfoWithBytesPerRow(SwizzlePF inPF, unsigned int inWidth, unsigned int inHeight, unsigned int inBytesPerRow);
	///	Generates a ``SwizzleShaderImageInfo`` struct, copying each plane's `offset` and `bytesPerRow` verbatim from the passed array.  Use this (instead of the functions above) when the planes have alignment/padding that the layout-derived offsets wouldn't match- e.g. an IOSurface whose plane offsets come from `IOSurfaceGetBaseAddressOfPlane`.  `inPlaneCount` must not exceed `MAX_NUM_PLANES`.
	SwizzleShaderImageInfo MakeSwizzleShaderImageInfoWithPlanes(SwizzlePF inPF, unsigned int inWidth, unsigned int inHeight, unsigned int inPlaneCount, const SwizzleShaderImagePlaneInfo * inPlanes);
	///	Compares the passed image info structs to determine if their properties are identical.
	BOOL SwizzleShaderImageInfoEquality(SwizzleShaderImageInfo *a, SwizzleShaderImageInfo *b);
	///	Compares the passed image info structs to determine if their pixel formats are identical.
	BOOL SwizzleShaderImageInfoFormatMatch(SwizzleShaderImageInfo *a, SwizzleShaderImageInfo *b);
#if defined __cplusplus
};
#endif


#endif




///	This struct describes a swizzle op- it contains sufficient information about the layout of both images to perform the conversion.  It's generated by calling ``MakeSwizzleShaderOpInfo``.
typedef struct	{
	///	The layout of the source image in memory.
	SwizzleShaderImageInfo		srcImg;
	///	The layout of the destination image in memory.
	SwizzleShaderImageInfo		dstImg;
	
	///	The src image is to be drawn within this rect.  It may be bigger or smaller than the dst image.  We calculate this on the CPU ahead of time because it makes the math easier in the shader.
	GRect			srcImgFrameInDst;
	///	If true, this image's contents should be flipped horizontally on retrieval
	bool			flipH;
	///	If true, this image's contents should be flipped vertically on retrieval
	bool			flipV;
	///	If 1.0, this image is faded to black.  if 0.0, the image is unaltered.
	float			fadeToBlack;
	///	The YCbCr side's signal RANGE- SOURCE range when decoding YCbCr->RGB, DESTINATION range when encoding RGB->YCbCr (a YCbCr->YCbCr swizzle shares one range for both ends).  Defaults to `SwizzleColorRange_legacy` (0) via the `MakeSwizzleShaderOpInfo` builder, preserving the pre-colorRange behavior (see `SwizzleColorRange_legacy`).
	SwizzleColorRange		colorRange;
	///	The YCbCr side's PRIMARIES (matrix family)- SOURCE primaries when decoding YCbCr->RGB, DESTINATION primaries when encoding RGB->YCbCr (a YCbCr->YCbCr swizzle shares one set of primaries for both ends).  Defaults to `SwizzleColorPrimaries_legacy` (0, == 709) via the `MakeSwizzleShaderOpInfo` builder, matching the historical behavior.
	SwizzleColorPrimaries	colorPrimaries;

	//	-------	you should NOT have to populate the following vars (backend should handle them automatically)
	
	//	populated automatically by the backend, but you'll want to read it in shaders.  if YES, we need to pull the src image out of the src image buffer.  if NO, we need to pull the src image out of the src img texture.  (we can no longer just pass a nil texture and check for that in the shader, as the metal debugger doesn't work unless all attachments are non-nil)
	bool			readSrcImgFromBuffer;
	//	populated automatically by the backend, but you'll want to read it in shaders.  must never exceed 'MAX_PIXELS_TO_PROCESS'! the # of pixels in the destination image to process per execution unit of the compute shader.  rgb is 1, 2vuy is probably 2, v210 is probably 6, etc
	unsigned int	dstPixelsToProcess[2];
} SwizzleShaderOpInfo;

#if defined __cplusplus
extern "C" {
#endif
	///	Generates a ``SwizzleShaderOpInfo`` struct that attempts to draw 'inSrc' within the bounds of 'inDest' (if they have different aspect ratios, this will result in distortion)
	SwizzleShaderOpInfo MakeSwizzleShaderOpInfo(SwizzleShaderImageInfo inSrc, SwizzleShaderImageInfo inDst);
#if defined __cplusplus
};
#endif



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
