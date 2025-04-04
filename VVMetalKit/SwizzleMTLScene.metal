#include <metal_stdlib>
#include "SwizzleMTLSceneTypes.h"

using namespace metal;

#include "VVColorConversions.h"
#include <VVMetalKit/SizingToolTypes.h>
//#include "SizingTool_metal.h"
#include "BilinearInterpolation.h"
#include "BicubicInterpolation.h"




#define SIZEOF_UINT8 1
#define SIZEOF_UINT16 2
#define SIZEOF_UINT32 4
#define SIZEOF_FLOAT 4
#define BICUBIC 0



//	just unpacks data from packed/planar pixel formats.
//	returns the normalized values of the channels from the passed src buffer/opInfo at the passed location
//	doesn't convert any colors- only converts ints (code point values) to normalized float vals, at most
//	doesn't do any interpolation- expects its location to be integral, and coords are relative to the srcBuffer.
float4 UnpackNormChannelValsAtLoc(constant void * srcBuffer, constant SwizzleShaderImageInfo & imgInfo, uint2 loc);


//	'dstLoc' is the location of the pixel in the SOURCE IMAGE- we want to retrieve the val of the pixel at this loc in the source image
void ReadNormRGBFromSrcBufferAtLoc(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderOpInfo & opInfo, uint2 dstLoc);


//	populates the passed array of 'normRGB' values from the passed 'srcBuffer', using 'opInfo' (which describes the nature of 'srcBuffer')
void PopulateNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderOpInfo & opInfo, uint2 gid);
//	same as above, but there's a size mismatch between the src and dst images and we need to do some resampling!
void PopulateAndResampleNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderOpInfo & opInfo, uint2 gid);


//	populates the passed array of 'normRGB' values from the passed texture, using 'opInfo' (which describes the nature of 'srcTexture')
void PopulateNormRGBFromSrcTex(thread float4 * normRGB, texture2d<float,access::sample> inTex, constant SwizzleShaderOpInfo & opInfo, uint2 gid);
//	populates the passed array of 'normRGB' values from the passed texture, using 'opInfo' (which describes the nature of 'srcTexture')
void PopulateAndResampleNormRGBFromSrcTex(thread float4 * normRGB, texture2d<float,access::sample> inTex, constant SwizzleShaderOpInfo & opInfo, uint2 gid);


//	last part of the process.  takes the normalized RGB color vals, and uses them to populate the dst image with them
void PopulateDstFromNormRGB(device void * dstBuffer, constant SwizzleShaderOpInfo & opInfo, thread float4 * normRGB, uint2 gid);




kernel void SwizzleMTLSceneFunc(
	constant void * srcBuffer [[ buffer(SwizzleShaderArg_SrcBuffer) ]],
	texture2d<float,access::sample> srcRGBTexture [[ texture(SwizzleShaderArg_SrcRGBTexture) ]],
	device void * dstBuffer [[ buffer(SwizzleShaderArg_DstBuffer) ]],
	texture2d<float,access::write> dstRGBTexture [[ texture(SwizzleShaderArg_DstRGBTexture) ]],
	constant SwizzleShaderOpInfo & opInfo [[ buffer(SwizzleShaderArg_OpInfo) ]],
	//constant SwizzleShaderProviderInfo & providerInfo [[ buffer(SwizzleShaderArg_ProviderInfo) ]],
	constant bool & writeToBuffer [[ buffer(SwizzleShaderArg_WriteBuffer) ]],
	uint2 gid [[ thread_position_in_grid ]])
{
	//	conceptually, this shader is processing pixels in the destination image
	//	because the shader has to render to packed pixel formats, there are times when it is necessary
	//	to process multiple pixels in the destination image "as a group"- for example, if the output 
	//	pixel format is 422 YCbCr, you want to process the output image in groups of two adjacent pixels...
	
	//	so, that's what we're going to do: first, assemble normalized RGB values for the pixels in the output image we need to output
	float4			normRGB[MAX_PIXELS_TO_PROCESS];
	bool			resMismatch = ( (opInfo.dstImg.res[0] != opInfo.srcImg.res[0] || opInfo.dstImg.res[1] != opInfo.srcImg.res[1])
	|| !GRectsEqual(opInfo.srcImgFrameInDst, MakeRect(0,0,opInfo.srcImg.res[0],opInfo.srcImg.res[1])) );
	
	//	if the src image is in a buffer
	if (opInfo.readSrcImgFromBuffer)	{
		if (resMismatch)	{
			PopulateAndResampleNormRGBFromSrcBuffer(normRGB, srcBuffer, opInfo, gid);
		}
		else	{
			PopulateNormRGBFromSrcBuffer(normRGB, srcBuffer, opInfo, gid);
		}
	}
	//	else the src image is in a texture
	else	{
		if (resMismatch)	{
			PopulateAndResampleNormRGBFromSrcTex(normRGB, srcRGBTexture, opInfo, gid);
			//for (int i=0; i<MAX_PIXELS_TO_PROCESS; ++i)	{
			//	normRGB[i] = float4(1,0,0,1);
			//}
		}
		else	{
			PopulateNormRGBFromSrcTex(normRGB, srcRGBTexture, opInfo, gid);
			//for (int i=0; i<MAX_PIXELS_TO_PROCESS; ++i)	{
			//	normRGB[i] = float4(0,0,1,1);
			//}
		}
	}
	
	//	this just makes everything red temporarily for debug purposes
	//{
	//	unsigned int		pixelIndex = 0;
	//	for (unsigned int yPixel=0; yPixel<opInfo.dstPixelsToProcess[1]; ++yPixel)	{
	//		for (unsigned int xPixel=0; xPixel<opInfo.dstPixelsToProcess[0]; ++xPixel)	{
	//			normRGB[pixelIndex] = float4(1,0,0,1);
	//			++pixelIndex;
	//		}
	//	}
	//}
	
	//	if there's a destination RGB texture attached, write the pixels to it now
	if (!is_null_texture(dstRGBTexture))	{
		unsigned int			pixelIndex = 0;
		for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
			for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
				uint2		dstLoc = uint2( xPixel + (gid.x * opInfo.dstPixelsToProcess[0]), yPixel + (gid.y * opInfo.dstPixelsToProcess[1]) );
				if (dstLoc.x < opInfo.dstImg.res[0] && dstLoc.y < opInfo.dstImg.res[1])
					dstRGBTexture.write(normRGB[pixelIndex], dstLoc);
				++pixelIndex;
			}
		}
		//for (unsigned int pixelIndex = 0; pixelIndex < opInfo.dstPixelsToProcess; ++pixelIndex)	{
		//	uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
		//	if (dstLoc.x < opInfo.dstImg.res[0] && dstLoc.y < opInfo.dstImg.res[1])
		//		dstRGBTexture.write(normRGB[pixelIndex], dstLoc);
		//}
	}
	
	//	if we're supposed to be writing to the buffer, and the dst buffer is non-nil, populate it now
	if (writeToBuffer && dstBuffer != nullptr)	{
		PopulateDstFromNormRGB(dstBuffer, opInfo, normRGB, gid);
	}
	
}




#pragma mark - extract single pixel to RGB




float4 UnpackNormChannelValsAtLoc(constant void * srcBuffer, constant SwizzleShaderImageInfo & imgInfo, uint2 loc)	{
	float4			returnMe = float4(0,0,0,1);
	if (loc.x < 0 || loc.y < 0 || loc.x >= imgInfo.res[0] || loc.y >= imgInfo.res[1])
		return returnMe;
	
	switch (imgInfo.pf)	{
	case SwizzlePF_Unknown:
		{
			returnMe = float4(0,1,0,1);
		}
		break;
	
	case SwizzlePF_Luma_PK_UI_8:
		{
			size_t		bytesPerPixel = 1;	//	8 bits per channel, 1 channel per pixel, 8 bits per byte
			size_t		offsetInBytes = (loc.y * imgInfo.planes[0].bytesPerRow) + (loc.x * bytesPerPixel);
			constant uint8_t		*rPtr = (constant uint8_t *)srcBuffer + (imgInfo.planes[0].offset/SIZEOF_UINT8) + (offsetInBytes/SIZEOF_UINT8);
			
			returnMe = float4( float3((float(*rPtr) / 255.)), 1. );
		}
		break;
	case SwizzlePF_Luma_PK_FP_32:
		{
			size_t		bytesPerPixel = 4;	//	32 bits per channel, 1 channel per pixel, 8 bits per byte
			size_t		offsetInBytes = (loc.y * imgInfo.planes[0].bytesPerRow) + (loc.x * bytesPerPixel);
			constant float		*rPtr = (constant float *)srcBuffer + (imgInfo.planes[0].offset/SIZEOF_FLOAT) + (offsetInBytes/SIZEOF_FLOAT);
			
			returnMe = float4( float3(float(*rPtr)), 1. );
		}
		break;
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBX_PK_UI_8:
	case SwizzlePF_BGRA_PK_UI_8:
	case SwizzlePF_BGRX_PK_UI_8:
	case SwizzlePF_ARGB_PK_UI_8:
	case SwizzlePF_HSVA_PK_UI_8:
	case SwizzlePF_CMYK_PK_UI_8:
		{
			size_t		bytesPerPixel = 4;	//	8 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (loc.y * imgInfo.planes[0].bytesPerRow) + (loc.x * bytesPerPixel);
			//uint8_t		*rPtr = (srcBuffer + offsetInBytes);
			constant uint8_t		*rPtr = (constant uint8_t *)srcBuffer + (imgInfo.planes[0].offset/SIZEOF_UINT8) + (offsetInBytes/SIZEOF_UINT8);
			
			for (int i=0; i<4; ++i)	{
				returnMe[i] = float(*rPtr) / 255.;
				++rPtr;
			}
		}
		break;
	case SwizzlePF_RGBA_PK_FP_32:
		{
			size_t		bytesPerPixel = 16;	//	32 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (loc.y * imgInfo.planes[0].bytesPerRow) + (loc.x * bytesPerPixel);
			//float		*rPtr = (srcBuffer + offsetInBytes);
			constant float		*rPtr = (constant float *)srcBuffer + (imgInfo.planes[0].offset/SIZEOF_FLOAT) + (offsetInBytes/SIZEOF_FLOAT);
			for (int i=0; i<4; ++i)	{
				returnMe[i] = *rPtr;
				++rPtr;
			}
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_8:
		{
			size_t		bytesPerPixel = 2;	//	8 bits per channel, 2 channels per pixel (Y + Cb/Cr), 8 bits per byte
			//size_t		bytesPerRow = bytesPerPixel * imgInfo.res[0];
			size_t		bytesPerRow = imgInfo.planes[0].bytesPerRow;
			
			uint2		basePairLoc = loc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			basePairLoc.x -= basePairLoc.x % 2;	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			
			//	in memory, the order is "Cb Y Cr Y"
			
			//	this is a packed pixel format- to decode one pixel of output, we have to read two pixels from the src buffer
			
			//	the "base pair location" is how we get Cb and Cr.  the location is how we get the Y value.
			
			size_t		locOffsetInBytes = (loc.y * bytesPerRow) + (loc.x * bytesPerPixel);
			size_t		basePairOffsetInBytes = (basePairLoc.y * bytesPerRow) + (basePairLoc.x * bytesPerPixel);
			
			constant uint8_t		*rPtr;
			
			//	get the Y value
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset/SIZEOF_UINT8) + (locOffsetInBytes/SIZEOF_UINT8);
			rPtr += 1;
			returnMe[0] = float(*rPtr) / 255.;
			
			//	Cb and Cr
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset/SIZEOF_UINT8) + (basePairOffsetInBytes/SIZEOF_UINT8);
			returnMe[1] = float(*rPtr) / 255.;
			rPtr += 2;
			returnMe[2] = float(*rPtr) / 255.;
			
		}
		break;
	case SwizzlePF_YUYV_PK_422_UI_8:
		{
			size_t		bytesPerPixel = 2;	//	8 bits per channel, 2 channels per pixel (Y + Cb/Cr), 8 bits per byte
			//size_t		bytesPerRow = bytesPerPixel * imgInfo.res[0];
			size_t		bytesPerRow = imgInfo.planes[0].bytesPerRow;
			
			uint2		basePairLoc = loc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			basePairLoc.x -= basePairLoc.x % 2;	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			
			//	in memory, the order is "Cb Y Cr Y"
			
			//	this is a packed pixel format- to decode one pixel of output, we have to read two pixels from the src buffer
			
			//	the "base pair location" is how we get Cb and Cr.  the location is how we get the Y value.
			
			size_t		locOffsetInBytes = (loc.y * bytesPerRow) + (loc.x * bytesPerPixel);
			size_t		basePairOffsetInBytes = (basePairLoc.y * bytesPerRow) + (basePairLoc.x * bytesPerPixel);
			
			constant uint8_t		*rPtr;
			
			//	get the Y value
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset/SIZEOF_UINT8) + (locOffsetInBytes/SIZEOF_UINT8);
			returnMe[0] = float(*rPtr) / 255.;
			
			//	get the Cb and Cr values
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset/SIZEOF_UINT8) + (basePairOffsetInBytes/SIZEOF_UINT8);
			rPtr += 1;
			returnMe[1] = float(*rPtr) / 255.;
			rPtr += 2;
			returnMe[2] = float(*rPtr) / 255.;
			
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_10:
		{
			//	this pixel format processes pixels in chunks that are 6 pixels wide.  locate the base of this "chunk".
			uint2		baseLoc = loc;
			//baseLoc.x /= 6;
			//baseLoc.x *= 6;
			baseLoc.x -= (baseLoc.x % 6);
			
			//	calculate the offset in bytes to the base location.  note that six pixels are crammed into four, 32-bit values.
			size_t					offsetInBytes = (imgInfo.planes[0].bytesPerRow * baseLoc.y) + (baseLoc.x / 6 * 4 * SIZEOF_UINT32);
			constant uint32_t		*rPtr = ((constant uint32_t *)srcBuffer) + (imgInfo.planes[0].offset/SIZEOF_UINT32) + (offsetInBytes/SIZEOF_UINT32);
			uint32_t				rVals[4];
			for (int i=0; i<4; ++i)
				rVals[i] = *(rPtr + i);
			
			//	break down the four 32-bit values into six YCbCr values...
			ushort4					intVals[6];
			//	note: 0x3FF is 1023- it is the largest possible 10-bit value
			
			//writeVals[0] = (intVals[0].g) | (intVals[0].r << 10) | (intVals[0].b << 20) | (0x3 << 30);
			intVals[0].g = (rVals[0]) & (0x3FF);
			intVals[0].r = (rVals[0] >> 10) & (0x3FF);
			intVals[0].b = (rVals[0] >> 20) & (0x3FF);
			
			//writeVals[1] = (intVals[1].r) | (intVals[2].g << 10) | (intVals[2].r << 20) | (0x3 << 30);
			intVals[1].r = (rVals[1]) & (0x3FF);
			intVals[2].g = (rVals[1] >> 10) & (0x3FF);
			intVals[2].r = (rVals[1] >> 20) & (0x3FF);
			
			//writeVals[2] = (intVals[2].b) | (intVals[3].r << 10) | (intVals[4].g << 20) | (0x3 << 30);
			intVals[2].b = (rVals[2]) & (0x3FF);
			intVals[3].r = (rVals[2] >> 10) & (0x3FF);
			intVals[4].g = (rVals[2] >> 20) & (0x3FF);
			
			//writeVals[3] = (intVals[4].r) | (intVals[4].b << 10) | (intVals[5].r << 20) | (0x3 << 30);
			intVals[4].r = (rVals[3]) & (0x3FF);
			intVals[4].b = (rVals[3] >> 10) & (0x3FF);
			intVals[5].r = (rVals[3] >> 20) & (0x3FF);
			
			//	fill in the cb/cr vals by copying them from the adjacent pixels
			intVals[1].g = intVals[0].g;
			intVals[1].b = intVals[0].b;
			intVals[3].g = intVals[2].g;
			intVals[3].b = intVals[2].b;
			intVals[5].g = intVals[4].g;
			intVals[5].b = intVals[4].b;
			
			returnMe.rgb = float3(intVals[loc.x-baseLoc.x].rgb) / float3(1023.);
			returnMe.a = 1.0;
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_8:
		{
			uint2		basePairLoc = loc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			basePairLoc.x -= basePairLoc.x % 2;	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			
			//	first plane is a 2vuy data blob- in memory, the order is "Cb Y Cr Y"
			//	second plane is an 8-bit per pixel alpha channel
			
			//	this is a packed pixel format- to decode one pixel of output, we have to read two pixels from the src buffer
			//	the "base pair location" is how we get Cb and Cr.  the location is how we get the Y value.
			
			constant uint8_t		*rPtr;
			
			size_t			offsetInBytes;
			
			//	Y
			offsetInBytes = (loc.y * imgInfo.planes[0].bytesPerRow) + (loc.x * SIZEOF_UINT8 * 2);
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset + offsetInBytes)/SIZEOF_UINT8;
			++rPtr;
			returnMe[0] = float(*rPtr) / 255.;
			
			//	Cb and Cr
			offsetInBytes = (basePairLoc.y * imgInfo.planes[0].bytesPerRow) + (basePairLoc.x * SIZEOF_UINT8 * 2);
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset + offsetInBytes)/SIZEOF_UINT8;
			returnMe[1] = float(*rPtr) / 255.;
			rPtr += 2;
			returnMe[2] = float(*rPtr) / 255.;
			
			//	A
			offsetInBytes = (loc.y * imgInfo.planes[1].bytesPerRow) + (loc.x * SIZEOF_UINT8);
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[1].offset + offsetInBytes)/SIZEOF_UINT8;
			returnMe[3] = float(*rPtr) / 255.;
			
			//returnMe[1] = 0.;
			//returnMe[2] = 0.;
			//returnMe[3] = 1.;
			
		}
		break;
	case SwizzlePF_UYVY_PKPL_422_UI_16:
		{
			
			uint2		basePairLoc = loc;
			basePairLoc.x -= (loc.x % 2);
			
			//	first plane is Y
			//	second plane is Cb/Cr
			
			constant uint16_t		*rPtr;
			
			size_t			offsetInBytes;
			
			//	Y
			offsetInBytes = (loc.y * imgInfo.planes[0].bytesPerRow) + (loc.x * SIZEOF_UINT16);
			rPtr = ((constant uint16_t *)srcBuffer) + ((imgInfo.planes[0].offset + offsetInBytes)/SIZEOF_UINT16);
			returnMe[0] = float(*rPtr)/65535.;
			
			//	Cb/Cr
			offsetInBytes = (basePairLoc.y * imgInfo.planes[1].bytesPerRow) + (basePairLoc.x * SIZEOF_UINT16);
			rPtr = ((constant uint16_t *)srcBuffer) + ((imgInfo.planes[1].offset + offsetInBytes)/SIZEOF_UINT16);
			returnMe[1] = float(*rPtr)/65535.;
			++rPtr;
			returnMe[2] = float(*rPtr)/65535.;
			
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		{
			uint2		basePairLoc = loc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			basePairLoc.x -= (basePairLoc.x % 2);	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			
			//	first plane is Y (16 bit val per pixel)
			//	second plane is Cb/Cr (pair of 16-bit Cb/Cr vals per pair of pixels)
			//	third plane is A
			
			constant uint16_t		*rPtr;
			
			size_t			offsetInBytes;
			
			//	Y
			offsetInBytes = (loc.y * imgInfo.planes[0].bytesPerRow) + (loc.x * SIZEOF_UINT16);
			rPtr = ((constant uint16_t *)srcBuffer) + (imgInfo.planes[0].offset + offsetInBytes)/SIZEOF_UINT16;
			returnMe[0] = float(*rPtr)/65535.;
			
			//	Cb/Cr
			offsetInBytes = (basePairLoc.y * imgInfo.planes[1].bytesPerRow) + (basePairLoc.x * SIZEOF_UINT16);
			rPtr = ((constant uint16_t *)srcBuffer) + (imgInfo.planes[1].offset + offsetInBytes)/SIZEOF_UINT16;
			returnMe[1] = float(*rPtr)/65535.;
			++rPtr;
			returnMe[2] = float(*rPtr)/65535.;
			
			//	A
			offsetInBytes = (loc.y * imgInfo.planes[2].bytesPerRow) + (loc.x * SIZEOF_UINT16);
			rPtr = ((constant uint16_t *)srcBuffer) + (imgInfo.planes[2].offset + offsetInBytes)/SIZEOF_UINT16;
			returnMe[3] = float(*rPtr)/65535.;
			
		}
		break;
	case SwizzlePF_UYVY_PKPL_420_UI_8:
		{
			uint2		basePairLoc = loc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			//basePairLoc.x -= (basePairLoc.x % 2);	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			//basePairLoc.y -= (basePairLoc.y % 2);	//	it's 4:2:0, so we need to calculate a base pair loc for Y, too!
			basePairLoc = uint2(loc.x/2,loc.y/2);
			
			//	first plane is Y
			//	second plane is Cb/Cr
			
			constant uint8_t		*rPtr;
			
			size_t			offsetInBytes;
			
			//	Y
			offsetInBytes = (loc.y * imgInfo.planes[0].bytesPerRow) + (loc.x * SIZEOF_UINT8);
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset + offsetInBytes)/SIZEOF_UINT8;
			returnMe[0] = float(*rPtr)/255.;
			
			//	Cb/Cr
			offsetInBytes = (basePairLoc.y * imgInfo.planes[1].bytesPerRow) + (basePairLoc.x * SIZEOF_UINT8 * 2);
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[1].offset + offsetInBytes)/SIZEOF_UINT8;
			returnMe[1] = float(*rPtr)/255.;
			++rPtr;
			returnMe[2] = float(*rPtr)/255.;
			
		}
		break;
	case SwizzlePF_UYVY_PL_420_UI_8:
		{
			uint2		basePairLoc = loc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			//basePairLoc.x -= (basePairLoc.x % 2);	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			//basePairLoc.y -= (basePairLoc.y % 2);	//	it's 4:2:0, so we need to calculate a base pair loc for Y, too!
			basePairLoc = uint2(loc.x/2,loc.y/2);
			
			//	first plane is Y
			//	second plane is Cb
			//	third plane is Cr
			
			constant uint8_t		*rPtr;
			
			size_t			offsetInBytes;
			
			//	Y
			offsetInBytes = (loc.y * imgInfo.planes[0].bytesPerRow) + (loc.x * SIZEOF_UINT8);
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset + offsetInBytes)/SIZEOF_UINT8;
			returnMe[0] = float(*rPtr)/255.;
			
			//	Cb
			offsetInBytes = (basePairLoc.y * imgInfo.planes[1].bytesPerRow) + (basePairLoc.x * SIZEOF_UINT8);
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[1].offset + offsetInBytes)/SIZEOF_UINT8;
			returnMe[1] = float(*rPtr)/255.;
			
			//	Cr
			offsetInBytes = (basePairLoc.y * imgInfo.planes[2].bytesPerRow) + (basePairLoc.x * SIZEOF_UINT8);
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[2].offset + offsetInBytes)/SIZEOF_UINT8;
			returnMe[2] = float(*rPtr)/255.;
			
		}
		break;
	}
	
	return returnMe;
}


void ReadNormRGBFromSrcBufferAtLoc(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderOpInfo & opInfo, uint2 locInSrc)	{
	uint2			sampleLoc( clamp((int)locInSrc.x,(int)0,(int)opInfo.srcImg.res[0]-1), clamp((int)locInSrc.y,(int)0,(int)opInfo.srcImg.res[1]-1) );
	//GPoint		dstLoc = MakePoint(locInSrc.x, locInSrc.y);
	//	if the pixel we're populating is outside the bounds of the source image, it's solid black
	//if (!PixelInRect(dstLoc, opInfo.srcImgFrameInDst))	{
	//	*normRGB = float4(0., 0., 0., 1.);
	//	return;
	//}
	
	//				****** IMPORTANT *******
	//	this function assumes that the src and dst buffers have the same resolution!
	//	this function DOES NOT PERFORM ANY INTERPOLATION
	
	float4		fadeToBlackMultiplier = float4(1.-opInfo.fadeToBlack, 1.-opInfo.fadeToBlack, 1.-opInfo.fadeToBlack, 1);
	
	switch (opInfo.srcImg.pf)	{
	case SwizzlePF_Unknown:
		{
			*normRGB = float4(0,1,0,1);
		}
		break;
	case SwizzlePF_Luma_PK_UI_8:
	case SwizzlePF_Luma_PK_FP_32:
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBA_PK_FP_32:
		{
			float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, sampleLoc);
			//	in this case, the src image is RGB- we already have the normalized RGB vals, so we're basically done!
			*normRGB = rawVals.rgba * fadeToBlackMultiplier;
		}
		break;
	case SwizzlePF_RGBX_PK_UI_8:
		{
			float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, sampleLoc);
			
			float4		tmpVals = rawVals * fadeToBlackMultiplier;
			tmpVals.a = 1.0;
			*normRGB = tmpVals;
			
			//	in this case, the src image is RGB- we already have the normalized RGB vals, so we're basically done!
			//*normRGB.rgb = rawVals.rgb * fadeToBlackMultiplier;
		
			//	if it's a RGBX pixel format, set the alpha to 1!
			//*normRGB.a = 1.0;
		}
		break;
	case SwizzlePF_BGRA_PK_UI_8:
		{
			float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, sampleLoc);
		
			//	note: the image data in the src buffer is BGRA!
		
			//	image data is:			B	G	R	A
			//	code to access above:	R	G	B	A	=>	BGRA
			*normRGB = rawVals.bgra * fadeToBlackMultiplier;
		}
		break;
	case SwizzlePF_BGRX_PK_UI_8:
		{
			float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, sampleLoc);
		
			//	note: the image data in the src buffer is BGRA!
		
			//	image data is:			B	G	R	A
			//	code to access above:	R	G	B	A	=>	BGRA
			//*normRGB.rgb = rawVals.bgr * fadeToBlackMultiplier;
			float4		tmpVals = rawVals.bgra * fadeToBlackMultiplier;
			tmpVals.a = 1.0;
			*normRGB = tmpVals;
		
			//	if it's a BGRX pixel format, set the alpha to 1!
			//*normRGB.a = 1.0;
		}
		break;
	case SwizzlePF_ARGB_PK_UI_8:
		{
			float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, sampleLoc);
		
			//	note: the image data in the src buffer is ARGB!
		
			//	image data is:			A	R	G	B
			//	code to access above:	R	G	B	A	=>	GBAR
			*normRGB = rawVals.gbar * fadeToBlackMultiplier;
		}
		break;
	case SwizzlePF_HSVA_PK_UI_8:
		{
			float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, sampleLoc);
			
			float4			K = float4( 1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0 );
			float3			p = abs( fract(rawVals.xxx + K.xyz) * float3(6.0) - K.www);
			
			float3			rgbVals = float3(rawVals.z) * mix(K.xxx, clamp(p - K.xxx, float3(0.0), float3(1.0)), rawVals.y );
			
			(*normRGB).rgb = rgbVals * fadeToBlackMultiplier.rgb;
			(*normRGB).a = rawVals.a * fadeToBlackMultiplier.a;
		}
		break;
	case SwizzlePF_CMYK_PK_UI_8:
		{
			float4		rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, sampleLoc);
			
			float4		rgbVals;
			
			//rgbVals.rgb = (float3(1.0) - rawVals.xyz) * float3(1.0-rawVals.w);
			rgbVals.r = (1. - rawVals.x) * (1. - rawVals.w);
			rgbVals.g = (1. - rawVals.y) * (1. - rawVals.w);
			rgbVals.b = (1. - rawVals.z) * (1. - rawVals.w);
			
			rgbVals.a = 1.0;
			
			*normRGB = rgbVals * fadeToBlackMultiplier;
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_8:
	case SwizzlePF_YUYV_PK_422_UI_8:
	case SwizzlePF_UYVY_PK_422_UI_10:
	case SwizzlePF_UYVY_PKPL_422_UI_16:
	case SwizzlePF_UYVY_PKPL_420_UI_8:
	case SwizzlePF_UYVY_PL_420_UI_8:
		{
			float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, sampleLoc);
		
			//	in this case, the src img is YCbCr.  UnpackNormChannelValsAtLoc() has unpacked the buffer (and reordered YCbCr into YCbCr) and provided us with all three vals, we just have to convert them to RGB.
			
			float4		tmpVals;
			tmpVals.rgb = kTransMatrix_YCbCr_to_RGB_709 * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_709) * fadeToBlackMultiplier.rgb;
			tmpVals.a = 1.0;
			*normRGB = tmpVals;
		
			//normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_601 * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_601) * fadeToBlackMultiplier.rgb;
			//*normRGB.rgb = kTransMatrix_YCbCr_to_RGB_709 * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_709) * fadeToBlackMultiplier.rgb;
			//normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_Full * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_Full) * fadeToBlackMultiplier.rgb;
			//normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_SD * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_SD) * fadeToBlackMultiplier.rgb;
			//normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_HD * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_HD) * fadeToBlackMultiplier.rgb;
		
			//*normRGB.a = 1.0;
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_8:
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		{
			float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, sampleLoc);
			
			//	in this case, the src img is YCbCr.  UnpackNormChannelValsAtLoc() has unpacked the buffer and provided us with all three vals, we just have to convert them to RGB.
			
			float4		tmpVals;
			tmpVals.rgb = kTransMatrix_YCbCr_to_RGB_709 * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_709) * fadeToBlackMultiplier.rgb;
			//tmpVals.a = 1.0;
			tmpVals.a = rawVals.a * fadeToBlackMultiplier.a;
			*normRGB = tmpVals;
			
			//*normRGB.rgb = kTransMatrix_YCbCr_to_RGB_709 * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_709) * fadeToBlackMultiplier.rgb;
			
			//*normRGB.a = rawVals.a;
		}
		break;
	}
}




#pragma mark - src -> normalized RGB




void PopulateNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderOpInfo & opInfo, uint2 gid)	{
	
	//				****** IMPORTANT *******
	//	this function assumes that the src and dst buffers have the same resolution!
	//	this function DOES NOT PERFORM ANY INTERPOLATION
	
	unsigned int			pixelIndex = 0;
	for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
		for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
			//	calculate the coords of the pixel in the destination buffer we're calculating the color for
			GPoint		dstPixel = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel );
			//	if the pixel we're populating is outside the bounds of the source image in the dst image, it's solid black
			if (!PixelInRect(dstPixel, opInfo.srcImgFrameInDst))	{
				normRGB[pixelIndex] = float4(0., 0., 0., 1.);
				++pixelIndex;
				continue;
			}
			//	convert this to the normalized coords of the src img, using the frame the src image draws within for the op
			GPoint		srcNorm = NormCoordsOfPixelInRect(dstPixel, opInfo.srcImgFrameInDst);
			//	apply any flippedness
			if (opInfo.flipH)
				srcNorm.x = 1. - srcNorm.x;
			if (opInfo.flipV)
				srcNorm.y = 1. - srcNorm.y;
			//	convert the normalized src img coords to pixel src img coords
			GPoint		srcPixel = MakePoint( srcNorm.x * opInfo.srcImg.res[0], srcNorm.y * opInfo.srcImg.res[1] );
			ReadNormRGBFromSrcBufferAtLoc(normRGB + pixelIndex, srcBuffer, opInfo, uint2(srcPixel.x, srcPixel.y));
			
			++pixelIndex;
		}
	}
}
void PopulateAndResampleNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderOpInfo & opInfo, uint2 gid)	{
	
	unsigned int			pixelIndex = 0;
	for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
		for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
			//	calculate the coords of the pixel in the destination buffer we're calculating the color for
			GPoint		dstPixel = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel );
			//	if the pixel we're populating is outside the bounds of the source image in the dst image, it's solid black
			if (!PixelInRect(dstPixel, opInfo.srcImgFrameInDst))	{
				normRGB[pixelIndex] = float4(0., 0., 0., 1.);
				++pixelIndex;
				continue;
			}
			//	convert this to the normalized coords of the src img, using the frame the src image draws within for the op
			GPoint		srcNorm = NormCoordsOfPixelInRect(dstPixel, opInfo.srcImgFrameInDst);
			//	apply any flippedness
			if (opInfo.flipH)
				srcNorm.x = 1. - srcNorm.x;
			if (opInfo.flipV)
				srcNorm.y = 1. - srcNorm.y;
			//	convert the normalized src img coords to pixel src img coords
			GPoint		srcPixel = MakePoint( srcNorm.x * opInfo.srcImg.res[0], srcNorm.y * opInfo.srcImg.res[1] );
#if BICUBIC
			uint2			minCoords( floor(srcPixel.x), floor(srcPixel.y) );
			//uint2			maxCoords( ceil(srcPixel.x), ceil(srcPixel.y) );
			float2			mixVals = float2( srcPixel.x - minCoords.x, srcPixel.y - minCoords.y );
			uint2			startCoords(minCoords.x-1, minCoords.y-1);
			float4			row0[4];
			float4			row1[4];
			float4			row2[4];
			float4			row3[4];
			for (int i=0; i<4; ++i)	{
				ReadNormRGBFromSrcBufferAtLoc( &row0[i], srcBuffer, opInfo, uint2(startCoords.x+i, startCoords.y+0) );
				ReadNormRGBFromSrcBufferAtLoc( &row1[i], srcBuffer, opInfo, uint2(startCoords.x+i, startCoords.y+1) );
				ReadNormRGBFromSrcBufferAtLoc( &row2[i], srcBuffer, opInfo, uint2(startCoords.x+i, startCoords.y+2) );
				ReadNormRGBFromSrcBufferAtLoc( &row3[i], srcBuffer, opInfo, uint2(startCoords.x+i, startCoords.y+3) );
			}
			normRGB[pixelIndex] = BicubicInterpolation(&row0[0], &row1[0], &row2[0], &row3[0], mixVals);
#else
			uint2			minVals( floor(srcPixel.x), floor(srcPixel.y) );
			uint2			maxVals( ceil(srcPixel.x), ceil(srcPixel.y) );
			float2			mixVals = float2( srcPixel.x - minVals.x, maxVals.y - srcPixel.y );
			
			float4			topLeft;
			float4			topRight;
			float4			botLeft;
			float4			botRight;
			
			ReadNormRGBFromSrcBufferAtLoc(&topLeft, srcBuffer, opInfo, uint2(minVals.x, maxVals.y));
			ReadNormRGBFromSrcBufferAtLoc(&topRight, srcBuffer, opInfo, uint2(maxVals.x, maxVals.y));
			ReadNormRGBFromSrcBufferAtLoc(&botLeft, srcBuffer, opInfo, uint2(minVals.x, minVals.y));
			ReadNormRGBFromSrcBufferAtLoc(&botRight, srcBuffer, opInfo, uint2(maxVals.x, minVals.y));
			
			normRGB[pixelIndex] = BilinearInterpolation(topLeft, topRight, botLeft, botRight, mixVals);
#endif
			
			++pixelIndex;
		}
	}
	
	
}


void PopulateNormRGBFromSrcTex(thread float4 * normRGB, texture2d<float,access::sample> inTex, constant SwizzleShaderOpInfo & opInfo, uint2 gid)	{
	
	//	...technically this does a linear interpolation, but since the function is only called in situations where there's no res change, it should result in a direct copy?
	
	//constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::normalized);
	float4					fadeToBlackMultiplier = float4(1.-opInfo.fadeToBlack, 1.-opInfo.fadeToBlack, 1.-opInfo.fadeToBlack, 1);
	
	unsigned int			pixelIndex = 0;
	for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
		for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
			//	calculate the coords of the pixel in the destination buffer we're calculating the color for
			GPoint		dstPixel = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel );
			//	if the pixel we're populating is outside the bounds of the source image in the dst image, it's solid black
			if (!PixelInRect(dstPixel, opInfo.srcImgFrameInDst))	{
				normRGB[pixelIndex] = float4(0., 0., 0., 1.);
				++pixelIndex;
				continue;
			}
			//	convert this to the normalized coords of the src img, using the frame the src image draws within for the op
			GPoint		srcNorm = NormCoordsOfPixelInRect(dstPixel, opInfo.srcImgFrameInDst);
			//	apply any flippedness
			if (opInfo.flipH)
				srcNorm.x = 1. - srcNorm.x;
			if (opInfo.flipV)
				srcNorm.y = 1. - srcNorm.y;
			//	sample/read the input texture
			//float4			srcColor = inTex.sample(sampler, float2(srcNorm.x, srcNorm.y));
			GPoint			srcPixel = PixelForNormCoordsInRect(srcNorm, opInfo.srcImgFrameInDst);
			float4			srcColor = inTex.read(uint2( round(srcPixel.x), round(srcPixel.y) ));
			
			//	populate the normalized RGB value
			normRGB[pixelIndex] = srcColor * fadeToBlackMultiplier;
			
			++pixelIndex;
		}
	}
}
void PopulateAndResampleNormRGBFromSrcTex(thread float4 * normRGB, texture2d<float,access::sample> inTex, constant SwizzleShaderOpInfo & opInfo, uint2 gid)	{
	
	constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::normalized);
	float4					fadeToBlackMultiplier = float4(1.-opInfo.fadeToBlack, 1.-opInfo.fadeToBlack, 1.-opInfo.fadeToBlack, 1);
#if BICUBIC
	GRect					srcImgRect = MakeRect(0, 0, opInfo.srcImg.res[0], opInfo.srcImg.res[1]);
#endif
	
	unsigned int			pixelIndex = 0;
	for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
		for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
			//	calculate the coords of the pixel in the destination buffer we're calculating the color for
			GPoint		dstPixel = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel );
			//	if the pixel we're populating is outside the bounds of the source image in the dst image, it's solid black
			if (!PixelInRect(dstPixel, opInfo.srcImgFrameInDst))	{
				normRGB[pixelIndex] = float4(0., 0., 0., 1.);
				++pixelIndex;
				continue;
			}
			//	convert this to the normalized coords of the src img, using the frame the src image draws within for the op
			GPoint		srcNorm = NormCoordsOfPixelInRect(dstPixel, opInfo.srcImgFrameInDst);
			//	apply any flippedness
			if (opInfo.flipH)
				srcNorm.x = 1. - srcNorm.x;
			if (opInfo.flipV)
				srcNorm.y = 1. - srcNorm.y;
			
#if BICUBIC
			GPoint			srcPixel = MakePoint( srcNorm.x * opInfo.srcImg.res[0], srcNorm.y * opInfo.srcImg.res[1] );
			uint2			minCoords( floor(srcPixel.x), floor(srcPixel.y) );
			//uint2			maxCoords( ceil(srcPixel.x), ceil(srcPixel.y) );
			float2			mixVals = float2( srcPixel.x - minCoords.x, srcPixel.y - minCoords.y );
			uint2			startCoords(minCoords.x-1, minCoords.y-1);
			float4			row0[4];
			float4			row1[4];
			float4			row2[4];
			float4			row3[4];
			for (int i=0; i<4; ++i)	{
				GPoint			sample0 = NormCoordsOfPixelInRect( MakePoint(startCoords.x + i, startCoords.y + 0), srcImgRect );
				GPoint			sample1 = NormCoordsOfPixelInRect( MakePoint(startCoords.x + i, startCoords.y + 1), srcImgRect );
				GPoint			sample2 = NormCoordsOfPixelInRect( MakePoint(startCoords.x + i, startCoords.y + 2), srcImgRect );
				GPoint			sample3 = NormCoordsOfPixelInRect( MakePoint(startCoords.x + i, startCoords.y + 3), srcImgRect );
				
				row0[i] = inTex.sample(sampler, float2( sample0.x, sample0.y ));
				row1[i] = inTex.sample(sampler, float2( sample1.x, sample1.y ));
				row2[i] = inTex.sample(sampler, float2( sample2.x, sample2.y ));
				row3[i] = inTex.sample(sampler, float2( sample3.x, sample3.y ));
				
			}
			normRGB[pixelIndex] = fadeToBlackMultiplier * BicubicInterpolation(&row0[0], &row1[0], &row2[0], &row3[0], mixVals);
#else
			//	sample the input texture
			float4			srcColor = inTex.sample(sampler, float2(srcNorm.x, srcNorm.y));
			//	populate the normalized RGB value
			normRGB[pixelIndex] = srcColor * fadeToBlackMultiplier;
#endif
			
			++pixelIndex;
		}
	}
	
	
}




#pragma mark - normalized RGB -> dst




void PopulateDstFromNormRGB(device void * dstBuffer, constant SwizzleShaderOpInfo & opInfo, thread float4 * normRGB, uint2 gid)	{
	//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
	uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess[0]), (gid.y * opInfo.dstPixelsToProcess[1]));
	if (dstLoc.x >= opInfo.dstImg.res[0] || dstLoc.y >= opInfo.dstImg.res[1])
		return;
	
	switch (opInfo.dstImg.pf)	{
	case SwizzlePF_Unknown:
		return;
	case SwizzlePF_Luma_PK_UI_8:
		{
			size_t		bytesPerPixel = 1;	//	8 bits per channel, 1 channel per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset) + (offsetInBytes/SIZEOF_UINT8);
			float		tmpVal = round(RGBtoLuma((*normRGB).rgb) * 255.);
			*(wPtr + 0) = (uint8_t)tmpVal;
		}
		break;
	case SwizzlePF_Luma_PK_FP_32:
		{
			size_t		bytesPerPixel = 4;	//	32 bits per channel, 1 channel per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device float		*wPtr = (device float *)dstBuffer + (opInfo.dstImg.planes[0].offset) + (offsetInBytes/SIZEOF_FLOAT);
			*(wPtr + 0) = RGBtoLuma((*normRGB).rgb);
		}
		break;
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBX_PK_UI_8:
		{
			//float4		normCodeVals[MAX_PIXELS_TO_PROCESS];
			//char4		codeVals[MAX_PIXELS_TO_PROCESS];
			
			size_t		bytesPerPixel = 4;	//	8 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/SIZEOF_UINT8) + (offsetInBytes/SIZEOF_UINT8);
			
			//for (int pixelIndex = 0; pixelIndex < opInfo.dstPixelsToProcess; ++pixelIndex)	{
				//normCodeVals[pixelIndex] = normRGB[pixelIndex];
				//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				
				*(wPtr + 0) = round(normRGB[0].r * 255.);
				*(wPtr + 1) = round(normRGB[0].g * 255.);
				*(wPtr + 2) = round(normRGB[0].b * 255.);
				*(wPtr + 3) = round(normRGB[0].a * 255.);
				//wPtr += 4;
				
				//for (int i=0; i<4; ++i)	{
				//	*wPtr = normRGB[pixelIndex][i] * 255.;
				//	++wPtr;
				//}
			//}
		}
		break;
	case SwizzlePF_BGRA_PK_UI_8:
	case SwizzlePF_BGRX_PK_UI_8:
		{
			//float4		normCodeVals[MAX_PIXELS_TO_PROCESS];
			//char4		codeVals[MAX_PIXELS_TO_PROCESS];
			
			size_t		bytesPerPixel = 4;	//	8 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/SIZEOF_UINT8) + (offsetInBytes/SIZEOF_UINT8);
			
			//for (int pixelIndex = 0; pixelIndex < opInfo.dstPixelsToProcess; ++pixelIndex)	{
				//normCodeVals[pixelIndex] = normRGB[pixelIndex];
				//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				
				*(wPtr + 0) = round(normRGB[0].b * 255.);
				*(wPtr + 1) = round(normRGB[0].g * 255.);
				*(wPtr + 2) = round(normRGB[0].r * 255.);
				*(wPtr + 3) = round(normRGB[0].a * 255.);
				//wPtr += 4;
				
				//for (int i=0; i<4; ++i)	{
				//	*wPtr = normRGB[pixelIndex][i] * 255.;
				//	++wPtr;
				//}
			//}
		}
		break;
	case SwizzlePF_ARGB_PK_UI_8:
		{
			//float4		normCodeVals[MAX_PIXELS_TO_PROCESS];
			//char4		codeVals[MAX_PIXELS_TO_PROCESS];
			
			size_t		bytesPerPixel = 4;	//	8 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/SIZEOF_UINT8) + (offsetInBytes/SIZEOF_UINT8);
			
			//for (int pixelIndex = 0; pixelIndex < opInfo.dstPixelsToProcess; ++pixelIndex)	{
				//normCodeVals[pixelIndex] = normRGB[pixelIndex];
				//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				
				*(wPtr + 0) = round(normRGB[0].a * 255.);
				*(wPtr + 1) = round(normRGB[0].r * 255.);
				*(wPtr + 2) = round(normRGB[0].g * 255.);
				*(wPtr + 3) = round(normRGB[0].b * 255.);
				//wPtr += 4;
				
				//for (int i=0; i<4; ++i)	{
				//	*wPtr = normRGB[pixelIndex][i] * 255.;
				//	++wPtr;
				//}
			//}
		}
		break;
	case SwizzlePF_RGBA_PK_FP_32:
		{
			//float4		normCodeVals[MAX_PIXELS_TO_PROCESS];
			//char4		codeVals[MAX_PIXELS_TO_PROCESS];
			
			size_t		bytesPerPixel = 16;	//	32 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device float		*wPtr = (device float *)dstBuffer + (opInfo.dstImg.planes[0].offset/SIZEOF_FLOAT) + (offsetInBytes/SIZEOF_FLOAT);
			
			//for (int pixelIndex = 0; pixelIndex < opInfo.dstPixelsToProcess; ++pixelIndex)	{
				//normCodeVals[pixelIndex] = normRGB[pixelIndex];
				//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				
				*(wPtr + 0) = normRGB[0].r;
				*(wPtr + 1) = normRGB[0].g;
				*(wPtr + 2) = normRGB[0].b;
				*(wPtr + 3) = normRGB[0].a;
				//wPtr += 4;
				
				//for (int i=0; i<4; ++i)	{
				//	*wPtr = normRGB[pixelIndex][i] * 255.;
				//	++wPtr;
				//}
			//}
		}
		break;
	case SwizzlePF_HSVA_PK_UI_8:
		{
			float4		K = float4( 0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0 );
			//vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
			//vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
			float4		p = (normRGB[0].g < normRGB[0].b) ? float4( normRGB[0].bg, K.wz ) : float4( normRGB[0].gb, K.xy );
			float4		q = (normRGB[0].r < p.x) ? float4( p.xyw, normRGB[0].r ) : float4( normRGB[0].r, p.yzx );
			
			float		d = q.x - min(q.w, q.y);
			float		e = 1.0e-10;
			
			float3		rgbVals = float3( abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
			
			size_t		bytesPerPixel = 8 * 4 / 8;	//	8 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/SIZEOF_UINT8) + (offsetInBytes/SIZEOF_UINT8);
			
			*(wPtr + 0) = (uint8_t)round(rgbVals.r * 255.);
			*(wPtr + 1) = (uint8_t)round(rgbVals.g * 255.);
			*(wPtr + 2) = (uint8_t)round(rgbVals.b * 255.);
			*(wPtr + 3) = (uint8_t)round(normRGB[0].a * 255.);
		}
		break;
	case SwizzlePF_CMYK_PK_UI_8:
		{
			float4		cmyk;
			cmyk.w = 1.0 - max(max(normRGB[0].x, normRGB[0].y), normRGB[0].z);
			cmyk.x = (1.0 - normRGB[0].x - cmyk.w) / (1.0 - cmyk.w);
			cmyk.y = (1.0 - normRGB[0].y - cmyk.w) / (1.0 - cmyk.w);
			cmyk.z = (1.0 - normRGB[0].z - cmyk.w) / (1.0 - cmyk.w);
			
			size_t		bytesPerPixel = 8 * 4 / 8;	//	8 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/SIZEOF_UINT8) + (offsetInBytes/SIZEOF_UINT8);
			
			*(wPtr + 0) = (uint8_t)round(cmyk.x * 255.);
			*(wPtr + 1) = (uint8_t)round(cmyk.y * 255.);
			*(wPtr + 2) = (uint8_t)round(cmyk.z * 255.);
			*(wPtr + 3) = (uint8_t)round(cmyk.w * 255.);
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_8:
		{
			//	we were passed normalized RGB color vals- convert 'em to the dst color format (YCbCr in this case)
			uchar4		dstVals[MAX_PIXELS_TO_PROCESS];
			
			const float3x3		mat = kTransMatrix_RGB_to_YCbCr_709;
			const float3		offsets = kTransOffset_RGB_to_YCbCr_709;
			
			for (unsigned int pixelIndex = 0; pixelIndex < (opInfo.dstPixelsToProcess[0]*opInfo.dstPixelsToProcess[1]); ++pixelIndex)	{
				//	convert normalized RGB to normalized YCbCr
				float4		normDstVal;
				normDstVal.rgb = (mat * normRGB[pixelIndex].rgb) + offsets;
				normDstVal.a = normRGB[pixelIndex].a;
				
				//	convert normalized YCbCr to the code point vals we'll want to (combine and) write (8-bit vals in this case)
				dstVals[pixelIndex] = uchar4(round(normDstVal * 255.));
			}
			
			//	figure out the base address at which we need to start writing pixels
			size_t		bytesPerPixel = 8 * 2 / 8;	//	8 bits per channel, 2 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + ((opInfo.dstImg.planes[0].offset + offsetInBytes)/SIZEOF_UINT8);
			
			//	(combine and) write the pixels (this is where we go from 444 to 422)
			*wPtr = (dstVals[0].g + dstVals[1].g) / 2;	//	Cb, adds chroma subsampling
			++wPtr;
			*wPtr = dstVals[0].r;	//	Y from the first pixel
			++wPtr;
			*wPtr = (dstVals[0].b + dstVals[1].b) / 2;	//	Cr, adds chroma subsampling
			++wPtr;
			*wPtr = dstVals[1].r;	//	Y from the second pixel
			++wPtr;
		}
		break;
	case SwizzlePF_YUYV_PK_422_UI_8:
		{
			//	we were passed normalized RGB color vals- convert 'em to the dst color format (YCbCr in this case)
			uchar4		dstVals[MAX_PIXELS_TO_PROCESS];
			
			const float3x3		mat = kTransMatrix_RGB_to_YCbCr_709;
			const float3		offsets = kTransOffset_RGB_to_YCbCr_709;
			
			for (unsigned int pixelIndex = 0; pixelIndex < (opInfo.dstPixelsToProcess[0]*opInfo.dstPixelsToProcess[1]); ++pixelIndex)	{
				//	convert normalized RGB to normalized YCbCr
				float4		normDstVal;
				normDstVal.rgb = (mat * normRGB[pixelIndex].rgb) + offsets;
				normDstVal.a = normRGB[pixelIndex].a;
				
				//	convert normalized YCbCr to the code point vals we'll want to (combine and) write (8-bit vals in this case)
				dstVals[pixelIndex] = uchar4(round(normDstVal * 255.));
			}
			
			//	figure out the base address at which we need to start writing pixels
			size_t		bytesPerPixel = 8 * 2 / 8;	//	8 bits per channel, 2 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/SIZEOF_UINT8) + (offsetInBytes/SIZEOF_UINT8);
			
			//	(combine and) write the pixels (this is where we go from 444 to 422)
			*wPtr = dstVals[0].r;	//	Y from the first pixel
			++wPtr;
			*wPtr = (dstVals[0].g + dstVals[1].g) / 2;	//	Cb, adds chroma subsampling
			++wPtr;
			*wPtr = dstVals[1].r;	//	Y from the second pixel
			++wPtr;
			*wPtr = (dstVals[0].b + dstVals[1].b) / 2;	//	Cr, adds chroma subsampling
			++wPtr;
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_10:
		{
			//	we were passed normalized RGB color vals- convert 'em to the dst color format (YCbCr in this case)
			float4		dstVals[MAX_PIXELS_TO_PROCESS];
			
			const float3x3		mat = kTransMatrix_RGB_to_YCbCr_709;
			const float3		offsets = kTransOffset_RGB_to_YCbCr_709;
			
			for (unsigned int pixelIndex = 0; pixelIndex < (opInfo.dstPixelsToProcess[0]*opInfo.dstPixelsToProcess[1]); ++pixelIndex)	{
				//	convert normalized RGB to normalized YCbCr
				float4		normDstVal;
				normDstVal.rgb = (mat * normRGB[pixelIndex].rgb) + offsets;
				normDstVal.a = normRGB[pixelIndex].a;
				
				//	convert normalized YCbCr to the code point vals we'll want to (combine and) write (10-bit vals in this case)
				dstVals[pixelIndex] = round(normDstVal * 1023.);
			}
			
			//	ycbcr0, ycbcr2, and ycbcr4 all have their "Cb" and "Cr" components output.  this adds chroma subsampling...
			dstVals[0].gb = (dstVals[0].gb + dstVals[1].gb)/2.0;
			dstVals[2].gb = (dstVals[2].gb + dstVals[3].gb)/2.0;
			dstVals[4].gb = (dstVals[4].gb + dstVals[5].gb)/2.0;
			
			//	'dstVals' are floating-point vals ranged 0-1023.  convert them to integer values (by rounding)
			ushort4			intVals[MAX_PIXELS_TO_PROCESS];
			for (unsigned int pixelIndex = 0; pixelIndex < (opInfo.dstPixelsToProcess[0]*opInfo.dstPixelsToProcess[1]); ++pixelIndex)	{
				intVals[pixelIndex] = ushort4( round(dstVals[pixelIndex]) );
			}
			
			//	combine the six YCbCr values into four thirty-two bit words (each of which contains three ten-bit values, so 12 values- 6 Y values, and then 6 Cb/Cr values)
			uint32_t			writeVals[4];
			writeVals[0] = (intVals[0].g) | (intVals[0].r << 10) | (intVals[0].b << 20) | (0x3 << 30);
			writeVals[1] = (intVals[1].r) | (intVals[2].g << 10) | (intVals[2].r << 20) | (0x3 << 30);
			writeVals[2] = (intVals[2].b) | (intVals[3].r << 10) | (intVals[4].g << 20) | (0x3 << 30);
			writeVals[3] = (intVals[4].r) | (intVals[4].b << 10) | (intVals[5].r << 20) | (0x3 << 30);
			//	six YCbCr values are packed into four 32-bit values
			//size_t				bytesPerRow = imgInfo.res[0] / 6 * 4 * SIZEOF_UINT32;
			size_t				offsetInBytes = (opInfo.dstImg.planes[0].bytesPerRow * gid.y) + (gid.x * 4 * SIZEOF_UINT32);
			device uint32_t		*wPtr = (device uint32_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/SIZEOF_UINT32) + (offsetInBytes/SIZEOF_UINT32);
			for (int i=0; i<4; ++i)	{
				*(wPtr+i) = writeVals[i];
			}
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_8:
		{
			//	we were passed normalized RGB color vals- convert 'em to the dst color format (YCbCr in this case)
			uchar4		dstVals[MAX_PIXELS_TO_PROCESS];
			
			const float3x3		mat = kTransMatrix_RGB_to_YCbCr_709;
			const float3		offsets = kTransOffset_RGB_to_YCbCr_709;
			
			for (unsigned int pixelIndex = 0; pixelIndex < (opInfo.dstPixelsToProcess[0]*opInfo.dstPixelsToProcess[1]); ++pixelIndex)	{
				//	convert normalized RGB to normalized YCbCr
				float4		normDstVal;
				normDstVal.rgb = (mat * normRGB[pixelIndex].rgb) + offsets;
				normDstVal.a = normRGB[pixelIndex].a;
				
				//	convert normalized YCbCr to the code point vals we'll want to (combine and) write (8-bit vals in this case)
				dstVals[pixelIndex] = uchar4(round(normDstVal * 255.));
			}
			
			//	figure out the base address at which we need to start writing pixels
			size_t		bytesPerPixel = 8 * 2 / 8;	//	8 bits per channel, 2 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + ((opInfo.dstImg.planes[0].offset + offsetInBytes)/SIZEOF_UINT8);
			
			//	(combine and) write the pixels (this is where we go from 444 to 422)
			*wPtr = (dstVals[0].g + dstVals[1].g) / 2;	//	Cb, adds chroma subsampling
			++wPtr;
			*wPtr = dstVals[0].r;	//	Y from the first pixel
			++wPtr;
			*wPtr = (dstVals[0].b + dstVals[1].b) / 2;	//	Cr, adds chroma subsampling
			++wPtr;
			*wPtr = dstVals[1].r;	//	Y from the second pixel
			++wPtr;
			
			//	get the A value
			size_t		alphaPlaneOffsetInBytes = opInfo.dstImg.planes[1].offset;
			size_t		alphaPlaneBytesPerPixel = SIZEOF_UINT8;
			size_t		alphaLocOffsetInBytes = alphaPlaneOffsetInBytes + (dstLoc.y * opInfo.dstImg.planes[1].bytesPerRow) + (dstLoc.x * alphaPlaneBytesPerPixel);
			
			wPtr = (device uint8_t *)dstBuffer + (alphaLocOffsetInBytes/SIZEOF_UINT8);
			*wPtr = dstVals[0].a;
			++wPtr;
			*wPtr = dstVals[1].a;
			
		}
		break;
	case SwizzlePF_UYVY_PKPL_422_UI_16:
		{
			//	we were passed normalized RGB color vals- convert 'em to the dst color format (YCbCr in this case)
			ushort4		dstVals[MAX_PIXELS_TO_PROCESS];
			
			const float3x3		mat = kTransMatrix_RGB_to_YCbCr_709;
			const float3		offsets = kTransOffset_RGB_to_YCbCr_709;
			
			for (unsigned int pixelIndex = 0; pixelIndex < (opInfo.dstPixelsToProcess[0]*opInfo.dstPixelsToProcess[1]); ++pixelIndex)	{
				//	convert normalized RGB to normalized YCbCr
				float4		normDstVal;
				normDstVal.rgb = (mat * normRGB[pixelIndex].rgb) + offsets;
				normDstVal.a = normRGB[pixelIndex].a;
				
				//	convert normalized YCbCr to the code point vals we'll want to (combine and) write (16-bit vals in this case)
				dstVals[pixelIndex] = ushort4(round(normDstVal * 65535.));
			}
			
			uint2		basePairLoc = dstLoc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			basePairLoc.x -= basePairLoc.x % 2;	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			
			device uint16_t		*wPtr;
			
			//	first there's a plane of Y values
			size_t		yPlaneOffsetInBytes = 0;
			size_t		yBytesPerRow = SIZEOF_UINT16 * opInfo.dstImg.res[0];
			size_t		yOffsetInBytes = yPlaneOffsetInBytes + (dstLoc.y * yBytesPerRow) + (dstLoc.x * SIZEOF_UINT16);
			wPtr = ((device uint16_t *)dstBuffer) + (yOffsetInBytes/SIZEOF_UINT16);
			*wPtr = dstVals[0].r;
			++wPtr;
			*wPtr = dstVals[1].r;
			
			//	after the y plane there's another plane of interleaved (422 subsampling) Cb/Cr values
			size_t		cbcrPlaneOffsetInBytes = yPlaneOffsetInBytes + (yBytesPerRow * opInfo.dstImg.res[1]);
			size_t		cbcrPlaneBytesPerRow = SIZEOF_UINT16 * opInfo.dstImg.res[0];
			size_t		basePairOffsetInBytes = cbcrPlaneOffsetInBytes + (basePairLoc.y * cbcrPlaneBytesPerRow) + (basePairLoc.x * SIZEOF_UINT16);
			wPtr = (device uint16_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/SIZEOF_UINT16) + (basePairOffsetInBytes/SIZEOF_UINT16);
			*wPtr = (dstVals[0].g + dstVals[1].g) / 2;
			++wPtr;
			*wPtr = (dstVals[0].b + dstVals[1].b) / 2;
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		{
			
			//	we were passed normalized RGB color vals- convert 'em to the dst color format (YCbCr in this case)
			ushort4		dstVals[MAX_PIXELS_TO_PROCESS];
			
			const float3x3		mat = kTransMatrix_RGB_to_YCbCr_709;
			const float3		offsets = kTransOffset_RGB_to_YCbCr_709;
			
			for (unsigned int pixelIndex = 0; pixelIndex < (opInfo.dstPixelsToProcess[0]*opInfo.dstPixelsToProcess[1]); ++pixelIndex)	{
				//	convert normalized RGB to normalized YCbCr
				float4		normDstVal;
				normDstVal.rgb = (mat * normRGB[pixelIndex].rgb) + offsets;
				normDstVal.a = normRGB[pixelIndex].a;
				
				//	convert normalized YCbCr to the code point vals we'll want to (combine and) write (16-bit vals in this case)
				dstVals[pixelIndex] = ushort4(round(normDstVal * 65535.));
			}
			
			uint2		basePairLoc = dstLoc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			basePairLoc.x -= basePairLoc.x % 2;	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			
			device uint16_t		*wPtr;
			
			//	first there's a plane of Y values
			size_t		yPlaneOffsetInBytes = 0;
			size_t		yBytesPerRow = SIZEOF_UINT16 * opInfo.dstImg.res[0];
			size_t		yOffsetInBytes = yPlaneOffsetInBytes + (dstLoc.y * yBytesPerRow) + (dstLoc.x * SIZEOF_UINT16);
			wPtr = ((device uint16_t *)dstBuffer) + (yOffsetInBytes/SIZEOF_UINT16);
			*wPtr = dstVals[0].r;
			++wPtr;
			*wPtr = dstVals[1].r;
			
			//	after the y plane there's another plane of interleaved (422 subsampling) Cb/Cr values
			size_t		cbcrPlaneOffsetInBytes = yPlaneOffsetInBytes + (yBytesPerRow * opInfo.dstImg.res[1]);
			size_t		cbcrPlaneBytesPerRow = SIZEOF_UINT16 * opInfo.dstImg.res[0];
			size_t		basePairOffsetInBytes = cbcrPlaneOffsetInBytes + (basePairLoc.y * cbcrPlaneBytesPerRow) + (basePairLoc.x * SIZEOF_UINT16);
			wPtr = (device uint16_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/SIZEOF_UINT8) + (basePairOffsetInBytes/SIZEOF_UINT16);
			*wPtr = (dstVals[0].g + dstVals[1].g) / 2;
			++wPtr;
			*wPtr = (dstVals[0].b + dstVals[1].b) / 2;
			
			//	after the Cb/Cr plane there is an alpha plane
			
			size_t		aPlaneOffsetInBytes = cbcrPlaneOffsetInBytes + (cbcrPlaneBytesPerRow * opInfo.dstImg.res[1]);
			size_t		aBytesPerRow = yBytesPerRow;
			size_t		aOffsetInBytes = aPlaneOffsetInBytes + (aBytesPerRow * dstLoc.y) + (SIZEOF_UINT16 * dstLoc.x);
			wPtr = (device uint16_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/SIZEOF_UINT8) + (aOffsetInBytes/SIZEOF_UINT16);
			*wPtr = dstVals[0].a;
			++wPtr;
			*wPtr = dstVals[1].a;
			
		}
		break;
	case SwizzlePF_UYVY_PKPL_420_UI_8:
		{
			uint2			loc = uint2( gid.x * opInfo.dstPixelsToProcess[0], gid.y * opInfo.dstPixelsToProcess[1] );
			
			size_t				bytesPerPixel;
			size_t				offsetInBytes;
			device uint8_t		*wPtr;
			
			bytesPerPixel = 1;
			unsigned int		pixelIndex = 0;
			unsigned int		cb = 0;
			unsigned int		cr = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					//	we were passed normalized RGB color vals- convert 'em to the dst color format (YCbCr in this case)
					uchar4		ycbcr;
					float4		normDstVal;
					normDstVal.rgb = (kTransMatrix_RGB_to_YCbCr_709 * normRGB[pixelIndex].rgb) + kTransOffset_RGB_to_YCbCr_709;
					normDstVal.a = normRGB[pixelIndex].a;
					//	convert normalized YCbCr to the code point vals we'll want to (combine and) write (8-bit vals in this case)
					ycbcr = uchar4(round(normDstVal * 255.));
					
					//	write the Y value to the Y plane
					offsetInBytes = ((loc.y + yPixel) * opInfo.dstImg.planes[0].bytesPerRow) + ((loc.x + xPixel) * bytesPerPixel);
					wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/SIZEOF_UINT8) + (offsetInBytes/SIZEOF_UINT8);
					*wPtr = ycbcr.r;
					
					//	add the Cb and Cr values to the local cb and cr vars- we're going to average these vals across all 4 pixels (chroma sumbsampling)
					cb += ycbcr.g;
					cr += ycbcr.b;
					
					++pixelIndex;
				}
			}
			
			//	finish subsampling the Cb and Cr vals, then write them to the output buffer
			cb /= 4;
			cr /= 4;
			
			uint2			basePairLoc = loc;
			basePairLoc.x -= basePairLoc.x % 2;
			basePairLoc.y -= basePairLoc.y % 2;
			basePairLoc.x /= 2;
			basePairLoc.y /= 2;
			
			bytesPerPixel = 2;
			offsetInBytes = (gid.y * opInfo.dstImg.planes[1].bytesPerRow) + (gid.x * bytesPerPixel);
			wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[1].offset/SIZEOF_UINT8) + (offsetInBytes/SIZEOF_UINT8);
			*wPtr = (uint8_t)cb;
			++wPtr;
			*wPtr = (uint8_t)cr;
		}
		break;
	case SwizzlePF_UYVY_PL_420_UI_8:
		{
			uint2			loc = uint2( gid.x * opInfo.dstPixelsToProcess[0], gid.y * opInfo.dstPixelsToProcess[1] );
			
			size_t				bytesPerPixel;
			size_t				offsetInBytes;
			device uint8_t		*wPtr;
			
			bytesPerPixel = 1;
			unsigned int		pixelIndex = 0;
			unsigned int		cb = 0;
			unsigned int		cr = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					//	we were passed normalized RGB color vals- convert 'em to the dst color format (YCbCr in this case)
					uchar4		ycbcr;
					float4		normDstVal;
					normDstVal.rgb = (kTransMatrix_RGB_to_YCbCr_709 * normRGB[pixelIndex].rgb) + kTransOffset_RGB_to_YCbCr_709;
					normDstVal.a = normRGB[pixelIndex].a;
					//	convert normalized YCbCr to the code point vals we'll want to (combine and) write (8-bit vals in this case)
					ycbcr = uchar4(round(normDstVal * 255.));
					
					//	write the Y value to the Y plane
					offsetInBytes = ((loc.y + yPixel) * opInfo.dstImg.planes[0].bytesPerRow) + ((loc.x + xPixel) * bytesPerPixel);
					wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/SIZEOF_UINT8) + (offsetInBytes/SIZEOF_UINT8);
					*wPtr = ycbcr.r;
					
					//	add the Cb and Cr values to the local cb and cr vars- we're going to average these vals across all 4 pixels (chroma sumbsampling)
					cb += ycbcr.g;
					cr += ycbcr.b;
					
					++pixelIndex;
				}
			}
			
			//	finish subsampling the Cb and Cr vals, then write them to the output buffer
			cb /= 4;
			cr /= 4;
			
			uint2			basePairLoc = loc;
			basePairLoc.x -= basePairLoc.x % 2;
			basePairLoc.y -= basePairLoc.y % 2;
			basePairLoc.x /= 2;
			basePairLoc.y /= 2;
			
			bytesPerPixel = 1;
			offsetInBytes = (gid.y * opInfo.dstImg.planes[1].bytesPerRow) + (gid.x * bytesPerPixel);
			wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[1].offset/SIZEOF_UINT8) + (offsetInBytes/SIZEOF_UINT8);
			*wPtr = (uint8_t)cb;
			wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[2].offset/SIZEOF_UINT8) + (offsetInBytes/SIZEOF_UINT8);
			*wPtr = (uint8_t)cr;
		}
		break;
	}
}
















/*

this is a diagram of the bitwise layout of a v210 frame.  importantly:
- this is four 32-bit words (16 bytes)
- you can fit six 10-bit YCbCr pixels into every 16 bytes.  (6 pixels / 16 bytes)
- i'm going to say that again, it's important: for every FOUR RGB pixels in the OUTPUT image texture, we can pack in SIX YCbCr values
- this is why the OUTPUT image texture is 2/3s the width of the INPUT image texture.
- the BM SDK requires the image width to be rounded up to the nearest 48-pixel boundary ((width + 47)/48)

examples:
	input width:		48 pixels
	rounded width:		48 pixels
	bytes per row:		48 pixels / 6 pixel * 16 bytes = 128 bytes
	bytes per row:		((width + 47) / 48) * 128 = 128
	
	input width:		53 pixels
	rounded width:		96 pixels
	bytes per row:		96 pixels / 6 pixel * 16 bytes = 256 bytes
	bytes per row:		((width + 47) / 48) * 128 = 256

- this shader converts RGB -> YUV, and renders to an RGB texture (RGB10A2, so each R/G/B channel of the output pixel is 10 bits to make things easier)
	- if the input RGB texture's width is 48 pixels....
		- the YUV texture's rounded width is 48 pixels, or 128 bytes
		- the RGB texture we render to has a width of 128 bytes, or 32 pixels
	- if the input RGB texture's width is 53 pixels...
		- the YUV texture's rounded width is 96 pixels, or 256 bytes
		- the RGB texture we render to has a width of 256 bytes, or 64 pixels
	- if the input RGB texture's width is 96 pixels....
		- the YUV texture's rounded width is 96 pixels, or 256 bytes
		- the RGB texture we render to has a width of 256 bytes, or 64 pixels


map of PIXELS WE RENDER TO:

     byte 0    |     byte 1    |     byte 2    |     byte 3    |     byte 0    |     byte 1    |     byte 2    |     byte 3    |     byte 0    |     byte 1    |     byte 2    |     byte 3    |     byte 0    |     byte 1    |     byte 2    |     byte 3    |
0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|0 1 2 3 4 5 6 7|
---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|---------------|


                        32-bit word                            |                        32-bit word                            |                        32-bit word                            |                        32-bit word                            |
0 1 2 3 4 5 6 7 8 9|0 1 2 3 4 5 6 7 8 9|0 1 2 3 4 5 6 7 8 9|X X|0 1 2 3 4 5 6 7 8 9|0 1 2 3 4 5 6 7 8 9|0 1 2 3 4 5 6 7 8 9|X X|0 1 2 3 4 5 6 7 8 9|0 1 2 3 4 5 6 7 8 9|0 1 2 3 4 5 6 7 8 9|X X|0 1 2 3 4 5 6 7 8 9|0 1 2 3 4 5 6 7 8 9|0 1 2 3 4 5 6 7 8 9|X X|
-------------------|-------------------|-------------------|X X|-------------------|-------------------|-------------------|X X|-------------------|-------------------|-------------------|X X|-------------------|-------------------|-------------------|X X|
        Cb 0       |        Y 0        |        Cr 0       |X X|        Y 1        |       Cb 2        |        Y 2        |X X|        Cr 2       |        Y 3        |        Cb 4       |X X|        Y 4        |       Cr 4        |        Y 5        |X X|
        (Y0)       |                   |        (Y0)       |X X|                   |       (Y2)        |                   |X X|        (Y2)       |                   |        (Y4)       |X X|                   |       (Y4)        |                   |X X|
-------------------|-------------------|-------------------|X X|-------------------|-------------------|-------------------|X X|-------------------|-------------------|-------------------|X X|-------------------|-------------------|-------------------|X X|
                         word "A"                          |X X|                         word "B"                          |X X|                         word "C"                          |X X|                         word "D"                          |X X|
-------------------|-------------------|-------------------|X X|-------------------|-------------------|-------------------|X X|-------------------|-------------------|-------------------|X X|-------------------|-------------------|-------------------|X X|

for each four-pixel block in the OUTPUT image...
	get the output pixel location in the OUTPUT image of the LAST pixel in this block
	
	if the x location of the LAST pixel in this block is > (INPUT_image_width / 3 * 2)
		this block in the OUTPUT image is padding, and can be ignored
	
	figure out the location of the six pixels in the INPUT image that correspond to the six YCbCr values we need to calculate
	
	get the RGB color values of the six pixels in the INPUT image
	
	convert the RGB color values to YCbCr colors (use chroma subsampling)
	
	write the YCbCr color values to the OUTPUT image


*/



















