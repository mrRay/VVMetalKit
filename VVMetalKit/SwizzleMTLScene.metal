#include <metal_stdlib>
#include "SwizzleMTLSceneTypes.h"

using namespace metal;

#include "VVColorConversions.h"
#include "SizingTool_metal.h"




//	returns the normalized values of the channels from the passed src buffer/opInfo at the passed location
//	doesn't convert any colors- only converts ints (code point values) to normalized float vals, at most
//	doesn't do any interpolation- expects its location to be integral
float4 UnpackNormChannelValsAtLoc(constant void * srcBuffer, constant SwizzleShaderOpInfo * opInfo, uint2 loc);

//	populates the passed array of 'normRGB' values from the passed 'srcBuffer', using 'opInfo' (which describes the nature of 'srcBuffer')
void PopulateNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderOpInfo & opInfo, uint2 gid);
//	same as above, but there's a size mismatch between the src and dst images and we need to do some resampling!
void PopulateAndResampleNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderOpInfo & opInfo, uint2 gid);
//	populates the passed array of 'normRGB' values from the passed texture, using 'opInfo' (which describes the nature of 'srcTexture')
void PopulateAndResampleNormRGBFromSrcTex(thread float4 * normRGB, texture2d<float,access::sample> inTex, constant SwizzleShaderOpInfo & opInfo, uint2 gid);

//	populates the passed dst buffer using the contents of the passed normalized RGB values
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
	
	
	
	//	if we're reading from a src texture...
	if (!opInfo.readSrcImgFromBuffer)	{
		//	populate the normalized RGB pixel values from the RGB texture....
		PopulateAndResampleNormRGBFromSrcTex(normRGB, srcRGBTexture, opInfo, gid);
	}
	//	else we're not reading from a src texture- we're reading from a src buffer...
	else	{
		//	if the dst and src image sizes differ or are otherwise not a 1:1 match...
		if ((opInfo.dstImg.res[0] != opInfo.srcImg.res[0] || opInfo.dstImg.res[1] != opInfo.srcImg.res[1])
		|| !GRectsEqual(opInfo.srcImgFrame, MakeRect(0,0,opInfo.srcImg.res[0],opInfo.srcImg.res[1])))
		{
			//	use a different function to calculate the normalized RGB vals- we'll do this part last, once we get everything else working!
			PopulateAndResampleNormRGBFromSrcBuffer(normRGB, srcBuffer, opInfo, gid);
		}
		//	else the dst and src images have the same size...
		else	{
			//	populate the normalized RGB vals from the src buffer
			PopulateNormRGBFromSrcBuffer(normRGB, srcBuffer, opInfo, gid);
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
	
	
	
	
	
	
	
	
	/*
	//	if we're reading from a src texture...
	if (!is_null_texture(srcRGBTexture))	{
		//	populate the normalized RGB pixel values from the RGB texture....
		PopulateAndResampleNormRGBFromSrcTex(normRGB, srcRGBTexture, opInfo, gid);
	}
	//	else we're not reading from a src texture- we're reading from a src buffer...
	else	{
		//	if the dst and src image sizes differ...
		if (opInfo.dstImg.res[0] != opInfo.srcImg.res[0] || opInfo.dstImg.res[1] != opInfo.srcImg.res[1])	{
			//	use a different function to calculate the normalized RGB vals- we'll do this part last, once we get everything else working!
			PopulateAndResampleNormRGBFromSrcBuffer(normRGB, srcBuffer, opInfo, gid);
		}
		//	else the dst and src images have the same size...
		else	{
			//	populate the normalized RGB vals from the src buffer
			PopulateNormRGBFromSrcBuffer(normRGB, srcBuffer, opInfo, gid);
		}
	}
	
	//	if there's a destination RGB texture attached, write the pixels to it now
	if (!is_null_texture(dstRGBTexture))	{
		for (unsigned int pixelIndex = 0; pixelIndex < opInfo.dstPixelsToProcess; ++pixelIndex)	{
			uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
			if (dstLoc.x < opInfo.dstImg.res[0] && dstLoc.y < opInfo.dstImg.res[1])
				dstRGBTexture.write(normRGB[pixelIndex], dstLoc);
		}
	}
	
	//	if there's a dst buffer, populate it from the RGB values!
	if (dstBuffer != nullptr)	{
		PopulateDstFromNormRGB(dstBuffer, opInfo, normRGB, gid);
	}
	*/
}




float4 UnpackNormChannelValsAtLoc(constant void * srcBuffer, constant SwizzleShaderImageInfo & imgInfo, uint2 loc)
{
	float4			returnMe = float4(0,0,0,1);
	if (loc.x < 0 || loc.y < 0 || loc.x >= imgInfo.res[0] || loc.y >= imgInfo.res[1])
		return returnMe;
	
	switch (imgInfo.pf)	{
	case SwizzlePF_Unknown:
		{
			returnMe = float4(0,1,0,1);
		}
		break;
	
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBX_PK_UI_8:
	case SwizzlePF_BGRA_PK_UI_8:
	case SwizzlePF_BGRX_PK_UI_8:
	case SwizzlePF_ARGB_PK_UI_8:
		{
			size_t		bytesPerPixel = 8 * 4 / 8;	//	8 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (loc.y * imgInfo.planes[0].bytesPerRow) + (loc.x * bytesPerPixel);
			//uint8_t		*rPtr = (srcBuffer + offsetInBytes);
			constant uint8_t		*rPtr = (constant uint8_t *)srcBuffer + (imgInfo.planes[0].offset/sizeof(uint8_t)) + (offsetInBytes/sizeof(uint8_t));
			
			for (int i=0; i<4; ++i)	{
				returnMe[i] = float(*rPtr) / 255.;
				++rPtr;
			}
		}
		break;
	case SwizzlePF_RGBA_PK_FP_32:
		{
			size_t		bytesPerPixel = 32 * 4 / 8;	//	32 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (loc.y * imgInfo.planes[0].bytesPerRow) + (loc.x * bytesPerPixel);
			//float		*rPtr = (srcBuffer + offsetInBytes);
			constant float		*rPtr = (constant float *)srcBuffer + (imgInfo.planes[0].offset/sizeof(float)) + (offsetInBytes/sizeof(float));
			for (int i=0; i<4; ++i)	{
				returnMe[i] = *rPtr;
				++rPtr;
			}
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_8:
		{
			size_t		bytesPerPixel = sizeof(uint8_t) * 2;	//	8 bits per channel, 2 channels per pixel (Y + Cb/Cr), 8 bits per byte
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
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint8_t)) + (locOffsetInBytes/sizeof(uint8_t));
			rPtr += 1;
			returnMe[0] = float(*rPtr) / 255.;
			
			//	Cb and Cr
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint8_t)) + (basePairOffsetInBytes/sizeof(uint8_t));
			returnMe[1] = float(*rPtr) / 255.;
			rPtr += 2;
			returnMe[2] = float(*rPtr) / 255.;
			
		}
		break;
	case SwizzlePF_YUYV_PK_422_UI_8:
		{
			size_t		bytesPerPixel = sizeof(uint8_t) * 2;	//	8 bits per channel, 2 channels per pixel (Y + Cb/Cr), 8 bits per byte
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
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint8_t)) + (locOffsetInBytes/sizeof(uint8_t));
			returnMe[0] = float(*rPtr) / 255.;
			
			//	get the Cb and Cr values
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint8_t)) + (basePairOffsetInBytes/sizeof(uint8_t));
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
			size_t					offsetInBytes = (imgInfo.planes[0].bytesPerRow * baseLoc.y) + (baseLoc.x / 6 * 4 * sizeof(uint32_t));
			constant uint32_t		*rPtr = ((constant uint32_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint32_t)) + (offsetInBytes/sizeof(uint32_t));
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
	case SwizzlePF_UYVY_PKPL_422_UI_16:
		{
			uint2		basePairLoc = loc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			basePairLoc.x -= (basePairLoc.x % 2);	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			
			constant uint16_t		*rPtr;
			
			//	in memory, first there's a luma plane...
			
			size_t		yPlaneOffsetInBytes = 0;
			size_t		yBytesPerRow = sizeof(uint16_t) * imgInfo.res[0];
			size_t		yOffsetInBytes = yPlaneOffsetInBytes + (loc.y * yBytesPerRow) + (loc.x * sizeof(uint16_t));
			rPtr = ((constant uint16_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint16_t)) + (yOffsetInBytes/sizeof(uint16_t));
			returnMe[0] = float(*rPtr) / 65535.;
			
			//	after the luma plane is another plane of interleaved (422 subsampling) Cb/Cr values
			
			size_t		cbcrPlaneOffsetInBytes = yPlaneOffsetInBytes + (yBytesPerRow * imgInfo.res[1]);
			size_t		cbcrPlaneBytesPerRow = sizeof(uint16_t) * imgInfo.res[0];
			size_t		basePairOffsetInBytes = cbcrPlaneOffsetInBytes + (basePairLoc.y * cbcrPlaneBytesPerRow) + (basePairLoc.x * sizeof(uint16_t));
			rPtr = ((constant uint16_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint16_t)) + (basePairOffsetInBytes/sizeof(uint16_t));
			returnMe[1] = float(*(rPtr+0)) / 65535.;
			returnMe[2] = float(*(rPtr+1)) / 65535.;
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_8:
		{
			size_t		bytesPerPixel = sizeof(uint8_t) * 2;	//	8 bits per channel, 2 channels per pixel (Y + Cb/Cr), 8 bits per byte
			size_t		bytesPerRow = bytesPerPixel * imgInfo.res[0];
			
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
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint8_t)) + (locOffsetInBytes/sizeof(uint8_t));
			rPtr += 1;
			returnMe[0] = float(*rPtr) / 255.;
			
			//	Cb and Cr
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint8_t)) + (basePairOffsetInBytes/sizeof(uint8_t));
			returnMe[1] = float(*rPtr) / 255.;
			rPtr += 2;
			returnMe[2] = float(*rPtr) / 255.;
			
			//	get the A value
			size_t		alphaPlaneOffsetInBytes = bytesPerRow * imgInfo.res[1];
			size_t		alphaPlaneBytesPerPixel = sizeof(uint8_t);
			size_t		alphaPlaneBytesPerRow = alphaPlaneBytesPerPixel * imgInfo.res[0];
			size_t		alphaLocOffsetInBytes = alphaPlaneOffsetInBytes + (loc.y * alphaPlaneBytesPerRow) + (loc.x * alphaPlaneBytesPerPixel);
			
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint8_t)) + (alphaLocOffsetInBytes/sizeof(uint8_t));
			returnMe[3] = float(*rPtr) / 255.;
			//returnMe[3] = 1.0;
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		{
			uint2		basePairLoc = loc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			basePairLoc.x -= (basePairLoc.x % 2);	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			
			constant uint16_t		*rPtr;
			
			//	in memory, first there's a luma plane...
			
			size_t		yPlaneOffsetInBytes = 0;
			size_t		yBytesPerRow = sizeof(uint16_t) * imgInfo.res[0];
			size_t		yOffsetInBytes = yPlaneOffsetInBytes + (loc.y * yBytesPerRow) + (loc.x * sizeof(uint16_t));
			rPtr = ((constant uint16_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint16_t)) + (yOffsetInBytes/sizeof(uint16_t));
			returnMe[0] = float(*rPtr) / 65535.;
			
			//	after the luma plane is another plane of interleaved (422 subsampling) Cb/Cr values
			
			size_t		cbcrPlaneOffsetInBytes = yPlaneOffsetInBytes + (yBytesPerRow * imgInfo.res[1]);
			size_t		cbcrPlaneBytesPerRow = sizeof(uint16_t) * imgInfo.res[0];
			size_t		basePairOffsetInBytes = cbcrPlaneOffsetInBytes + (basePairLoc.y * cbcrPlaneBytesPerRow) + (basePairLoc.x * sizeof(uint16_t));
			rPtr = ((constant uint16_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint16_t)) + (basePairOffsetInBytes/sizeof(uint16_t));
			returnMe[1] = float(*(rPtr+0)) / 65535.;
			returnMe[2] = float(*(rPtr+1)) / 65535.;
			
			//	after the Cb/Cr plane is an alpha plane
			
			size_t		aPlaneOffsetInBytes = cbcrPlaneOffsetInBytes + (cbcrPlaneBytesPerRow * imgInfo.res[1]);
			size_t		aBytesPerRow = yBytesPerRow;
			size_t		aOffsetInBytes = aPlaneOffsetInBytes + (aBytesPerRow * loc.y) + (sizeof(uint16_t) * loc.x);
			rPtr = (constant uint16_t *)srcBuffer + (imgInfo.planes[0].offset/sizeof(uint16_t)) + (aOffsetInBytes/sizeof(uint16_t));
			returnMe[3] = float(*rPtr) / 65535.;
		}
		break;
	case SwizzlePF_UYVY_PKPL_420_UI_8:
		{
			constant uint8_t		*rPtr;
			size_t			bytesPerPixel;
			size_t			bytesPerRow;
			
			//	first pull the Y value from the first plane using the location
			bytesPerPixel = 1;
			bytesPerRow = imgInfo.planes[0].bytesPerRow;
			size_t			locOffsetInBytes = (loc.y * bytesPerRow) + (loc.x * bytesPerPixel);
			
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint8_t)) + (locOffsetInBytes/sizeof(uint8_t));
			returnMe[0] = float(*rPtr) / 255.;
			
			//	now pull the Cb and Cr values from the second plane
			uint2			basePairLoc = loc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			basePairLoc.x -= basePairLoc.x % 2;	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			basePairLoc.y -= basePairLoc.y % 2;
			//	it's 4:2:0, so divide the "basePairLoc" by 2 in both dimensions
			basePairLoc.x /= 2;
			basePairLoc.y /= 2;
			
			bytesPerPixel = sizeof(uint8_t) * 2;
			bytesPerRow = imgInfo.planes[1].bytesPerRow;
			size_t			basePairOffsetInBytes = (basePairLoc.y * bytesPerRow) + (basePairLoc.x * bytesPerPixel);
			
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[1].offset/sizeof(uint8_t)) + (basePairOffsetInBytes/sizeof(uint8_t));
			returnMe[1] = float(*rPtr) / 255.;
			++rPtr;
			returnMe[2] = float(*rPtr) / 255.;
		}
		break;
	case SwizzlePF_UYVY_PL_420_UI_8:
		{
			constant uint8_t		*rPtr;
			size_t			bytesPerPixel;
			size_t			bytesPerRow;
			
			//	first pull the Y value from the first plane using the location
			bytesPerPixel = 1;
			bytesPerRow = imgInfo.planes[0].bytesPerRow;
			size_t			locOffsetInBytes = (loc.y * bytesPerRow) + (loc.x * bytesPerPixel);
			
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[0].offset/sizeof(uint8_t)) + (locOffsetInBytes/sizeof(uint8_t));
			returnMe[0] = float(*rPtr) / 255.;
			
			//	now pull the Cb value from the second plane (and the Cr value from the third plane)
			uint2			chromaLoc = loc;
			size_t			chromaOffsetInBytes = 0;
			//if (chromaLoc.x % 2 != 0)
			//	chromaLoc.x = chromaLoc.x - 1;
			chromaLoc.x -= chromaLoc.x % 2;	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			chromaLoc.y -= chromaLoc.y % 2;
			//	it's 4:2:0, so divide the "chromaLoc" by 2 in both dimensions
			chromaLoc.x /= 2;
			chromaLoc.y /= 2;
			
			bytesPerPixel = sizeof(uint8_t);
			bytesPerRow = imgInfo.planes[1].bytesPerRow;
			chromaOffsetInBytes = (chromaLoc.y * bytesPerRow) + (chromaLoc.x * bytesPerPixel);
			
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[1].offset/sizeof(uint8_t)) + (chromaOffsetInBytes/sizeof(uint8_t));
			returnMe[1] = float(*rPtr) / 255.;
			rPtr = ((constant uint8_t *)srcBuffer) + (imgInfo.planes[2].offset/sizeof(uint8_t)) + (chromaOffsetInBytes/sizeof(uint8_t));
			returnMe[2] = float(*rPtr) / 255.;
		}
		break;
	}
	
	return returnMe;
}

void PopulateNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderOpInfo & opInfo, uint2 gid)	{
	
	//				****** IMPORTANT *******
	//	this function assumes that the src and dst buffers have the same resolution!
	//	this function DOES NOT PERFORM ANY INTERPOLATION
	
	float4		fadeToBlackMultiplier = float4(1.-opInfo.fadeToBlack, 1.-opInfo.fadeToBlack, 1.-opInfo.fadeToBlack, 1);
	
	switch (opInfo.srcImg.pf)	{
	case SwizzlePF_Unknown:
		{
			unsigned int			pixelIndex = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					normRGB[pixelIndex] = float4(0,1,0,1);
					
					++pixelIndex;
				}
			}
		}
		break;
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBA_PK_FP_32:
		{
			//	for each of the pixels we need to process in the dst image...
			unsigned int			pixelIndex = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					//	determine the location of the pixel we're populating in the destination
					GPoint		dstLoc = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel);
					//	if the pixel we're populating is outside the bounds of the source image, it's solid black
					if (!PointInRect(dstLoc, opInfo.srcImgFrame))	{
						normRGB[pixelIndex] = float4(0., 0., 0., 1.);
						++pixelIndex;
						continue;
					}
					
					float4			rawVals;
					//	if we have to do any flipping...
					if (opInfo.flipH || opInfo.flipV)	{
						//	convert the pixel coords to normalized coords within the src img frame
						GPoint		normSamplePointInSrc = NormCoordsOfPixelInRect(dstLoc, opInfo.srcImgFrame);
						if (opInfo.flipH)
							normSamplePointInSrc.x = 1. - normSamplePointInSrc.x;
						if (opInfo.flipV)
							normSamplePointInSrc.y = 1. - normSamplePointInSrc.y;
						//	convert the normalized coords back to pixel coords within the src img frame- since the src & dst buffers have the same resolution, this is what we're sampling
						GPoint		samplePointInSrc = PixelForNormCoordsInRect(normSamplePointInSrc, opInfo.srcImgFrame);
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(samplePointInSrc.x, samplePointInSrc.y));
					}
					//	else we didn't have to do any flipping- we're sampling the same location in the src that we're populating in the dst
					else	{
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(dstLoc.x, dstLoc.y));
					}
				
					//	calculate the location of the pixel we're processing in the dst image, get its value
					//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
					//	get the normalized channel values at that location
					//float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, dstLoc);
				
					//	in this case, the src image is RGB- we already have the normalized RGB vals, so we're basically done!
					normRGB[pixelIndex] = rawVals.rgba * fadeToBlackMultiplier;
					
					++pixelIndex;
				}
			}
		}
		break;
	case SwizzlePF_RGBX_PK_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			unsigned int			pixelIndex = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					//	determine the location of the pixel we're populating in the destination
					GPoint		dstLoc = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel);
					//	if the pixel we're populating is outside the bounds of the source image, it's solid black
					if (!PointInRect(dstLoc, opInfo.srcImgFrame))	{
						normRGB[pixelIndex] = float4(0., 0., 0., 1.);
						++pixelIndex;
						continue;
					}
					float4			rawVals;
					//	if we have to do any flipping...
					if (opInfo.flipH || opInfo.flipV)	{
						//	convert the pixel coords to normalized coords within the src img frame
						GPoint		normSamplePointInSrc = NormCoordsOfPixelInRect(dstLoc, opInfo.srcImgFrame);
						if (opInfo.flipH)
							normSamplePointInSrc.x = 1. - normSamplePointInSrc.x;
						if (opInfo.flipV)
							normSamplePointInSrc.y = 1. - normSamplePointInSrc.y;
						//	convert the normalized coords back to pixel coords within the src img frame- since the src & dst buffers have the same resolution, this is what we're sampling
						GPoint		samplePointInSrc = PixelForNormCoordsInRect(normSamplePointInSrc, opInfo.srcImgFrame);
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(samplePointInSrc.x, samplePointInSrc.y));
					}
					//	else we didn't have to do any flipping- we're sampling the same location in the src that we're populating in the dst
					else	{
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(dstLoc.x, dstLoc.y));
					}
				
					//	calculate the location of the pixel we're processing in the dst image, get its value
					//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
					//	get the normalized channel values at that location
					//float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, dstLoc);
				
					//	in this case, the src image is RGB- we already have the normalized RGB vals, so we're basically done!
					normRGB[pixelIndex] = rawVals.rgba * fadeToBlackMultiplier;
				
					//	if it's a RGBX pixel format, set the alpha to 1!
					normRGB[pixelIndex].a = 1.0;
					
					++pixelIndex;
				}
			}
		}
		break;
	case SwizzlePF_BGRA_PK_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			unsigned int			pixelIndex = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					//	determine the location of the pixel we're populating in the destination
					GPoint		dstLoc = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel);
					//	if the pixel we're populating is outside the bounds of the source image, it's solid black
					if (!PointInRect(dstLoc, opInfo.srcImgFrame))	{
						normRGB[pixelIndex] = float4(0., 0., 0., 1.);
						++pixelIndex;
						continue;
					}
					float4			rawVals;
					//	if we have to do any flipping...
					if (opInfo.flipH || opInfo.flipV)	{
						//	convert the pixel coords to normalized coords within the src img frame
						GPoint		normSamplePointInSrc = NormCoordsOfPixelInRect(dstLoc, opInfo.srcImgFrame);
						if (opInfo.flipH)
							normSamplePointInSrc.x = 1. - normSamplePointInSrc.x;
						if (opInfo.flipV)
							normSamplePointInSrc.y = 1. - normSamplePointInSrc.y;
						//	convert the normalized coords back to pixel coords within the src img frame- since the src & dst buffers have the same resolution, this is what we're sampling
						GPoint		samplePointInSrc = PixelForNormCoordsInRect(normSamplePointInSrc, opInfo.srcImgFrame);
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(samplePointInSrc.x, samplePointInSrc.y));
					}
					//	else we didn't have to do any flipping- we're sampling the same location in the src that we're populating in the dst
					else	{
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(dstLoc.x, dstLoc.y));
					}
				
					//	calculate the location of the pixel we're processing in the dst image, get its value
					//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
					//	get the normalized channel values at that location
					//float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, dstLoc);
				
					//	note: the image data in the src buffer is BGRA!
				
					//	image data is:			B	G	R	A
					//	code to access above:	R	G	B	A	=>	BGRA
					normRGB[pixelIndex] = rawVals.bgra * fadeToBlackMultiplier;
					
					++pixelIndex;
				}
			}
		}
		break;
	case SwizzlePF_BGRX_PK_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			unsigned int			pixelIndex = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					//	determine the location of the pixel we're populating in the destination
					GPoint		dstLoc = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel);
					//	if the pixel we're populating is outside the bounds of the source image, it's solid black
					if (!PointInRect(dstLoc, opInfo.srcImgFrame))	{
						normRGB[pixelIndex] = float4(0., 0., 0., 1.);
						++pixelIndex;
						continue;
					}
					float4			rawVals;
					//	if we have to do any flipping...
					if (opInfo.flipH || opInfo.flipV)	{
						//	convert the pixel coords to normalized coords within the src img frame
						GPoint		normSamplePointInSrc = NormCoordsOfPixelInRect(dstLoc, opInfo.srcImgFrame);
						if (opInfo.flipH)
							normSamplePointInSrc.x = 1. - normSamplePointInSrc.x;
						if (opInfo.flipV)
							normSamplePointInSrc.y = 1. - normSamplePointInSrc.y;
						//	convert the normalized coords back to pixel coords within the src img frame- since the src & dst buffers have the same resolution, this is what we're sampling
						GPoint		samplePointInSrc = PixelForNormCoordsInRect(normSamplePointInSrc, opInfo.srcImgFrame);
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(samplePointInSrc.x, samplePointInSrc.y));
					}
					//	else we didn't have to do any flipping- we're sampling the same location in the src that we're populating in the dst
					else	{
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(dstLoc.x, dstLoc.y));
					}
				
					//	calculate the location of the pixel we're processing in the dst image, get its value
					//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
					//	get the normalized channel values at that location
					//float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, dstLoc);
				
					//	note: the image data in the src buffer is BGRA!
				
					//	image data is:			B	G	R	A
					//	code to access above:	R	G	B	A	=>	BGRA
					normRGB[pixelIndex] = rawVals.bgra * fadeToBlackMultiplier;
				
					//	if it's a BGRX pixel format, set the alpha to 1!
					normRGB[pixelIndex].a = 1.0;
					
					++pixelIndex;
				}
			}
		}
		break;
	case SwizzlePF_ARGB_PK_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			unsigned int			pixelIndex = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					//	determine the location of the pixel we're populating in the destination
					GPoint		dstLoc = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel);
					//	if the pixel we're populating is outside the bounds of the source image, it's solid black
					if (!PointInRect(dstLoc, opInfo.srcImgFrame))	{
						normRGB[pixelIndex] = float4(0., 0., 0., 1.);
						++pixelIndex;
						continue;
					}
					float4			rawVals;
					//	if we have to do any flipping...
					if (opInfo.flipH || opInfo.flipV)	{
						//	convert the pixel coords to normalized coords within the src img frame
						GPoint		normSamplePointInSrc = NormCoordsOfPixelInRect(dstLoc, opInfo.srcImgFrame);
						if (opInfo.flipH)
							normSamplePointInSrc.x = 1. - normSamplePointInSrc.x;
						if (opInfo.flipV)
							normSamplePointInSrc.y = 1. - normSamplePointInSrc.y;
						//	convert the normalized coords back to pixel coords within the src img frame- since the src & dst buffers have the same resolution, this is what we're sampling
						GPoint		samplePointInSrc = PixelForNormCoordsInRect(normSamplePointInSrc, opInfo.srcImgFrame);
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(samplePointInSrc.x, samplePointInSrc.y));
					}
					//	else we didn't have to do any flipping- we're sampling the same location in the src that we're populating in the dst
					else	{
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(dstLoc.x, dstLoc.y));
					}
				
					//	calculate the location of the pixel we're processing in the dst image, get its value
					//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
					//	get the normalized channel values at that location
					//float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, dstLoc);
				
					//	note: the image data in the src buffer is ARGB!
				
					//	image data is:			A	R	G	B
					//	code to access above:	R	G	B	A	=>	GBAR
					normRGB[pixelIndex] = rawVals.gbar * fadeToBlackMultiplier;
					
					++pixelIndex;
				}
			}
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_8:
	case SwizzlePF_YUYV_PK_422_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			unsigned int			pixelIndex = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					//	determine the location of the pixel we're populating in the destination
					GPoint		dstLoc = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel);
					//	if the pixel we're populating is outside the bounds of the source image, it's solid black
					if (!PointInRect(dstLoc, opInfo.srcImgFrame))	{
						normRGB[pixelIndex] = float4(0., 0., 0., 1.);
						++pixelIndex;
						continue;
					}
					float4			rawVals;
					//	if we have to do any flipping...
					if (opInfo.flipH || opInfo.flipV)	{
						//	convert the pixel coords to normalized coords within the src img frame
						GPoint		normSamplePointInSrc = NormCoordsOfPixelInRect(dstLoc, opInfo.srcImgFrame);
						if (opInfo.flipH)
							normSamplePointInSrc.x = 1. - normSamplePointInSrc.x;
						if (opInfo.flipV)
							normSamplePointInSrc.y = 1. - normSamplePointInSrc.y;
						//	convert the normalized coords back to pixel coords within the src img frame- since the src & dst buffers have the same resolution, this is what we're sampling
						GPoint		samplePointInSrc = PixelForNormCoordsInRect(normSamplePointInSrc, opInfo.srcImgFrame);
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(samplePointInSrc.x, samplePointInSrc.y));
					}
					//	else we didn't have to do any flipping- we're sampling the same location in the src that we're populating in the dst
					else	{
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(dstLoc.x, dstLoc.y));
					}
				
					//	calculate the location of the pixel we're processing in the dst image, get its value
					//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
					//	get the normalized channel values at that location
					//float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, dstLoc);
				
					//	in this case, the src img is YCbCr.  UnpackNormChannelValsAtLoc() has unpacked the buffer (and reordered YCbCr into YCbCr) and provided us with all three vals, we just have to convert them to RGB.
				
					//normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_601 * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_601) * fadeToBlackMultiplier.rgb;
					normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_709 * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_709) * fadeToBlackMultiplier.rgb;
					//normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_Full * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_Full) * fadeToBlackMultiplier.rgb;
					//normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_SD * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_SD) * fadeToBlackMultiplier.rgb;
					//normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_HD * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_HD) * fadeToBlackMultiplier.rgb;
				
					normRGB[pixelIndex].a = 1.0;
					
					++pixelIndex;
				}
			}
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_10:
		{
			//	for each of the pixels we need to process in the dst image...
			unsigned int			pixelIndex = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					//	determine the location of the pixel we're populating in the destination
					GPoint		dstLoc = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel);
					//	if the pixel we're populating is outside the bounds of the source image, it's solid black
					if (!PointInRect(dstLoc, opInfo.srcImgFrame))	{
						normRGB[pixelIndex] = float4(0., 0., 0., 1.);
						++pixelIndex;
						continue;
					}
					float4			rawVals;
					//	if we have to do any flipping...
					if (opInfo.flipH || opInfo.flipV)	{
						//	convert the pixel coords to normalized coords within the src img frame
						GPoint		normSamplePointInSrc = NormCoordsOfPixelInRect(dstLoc, opInfo.srcImgFrame);
						if (opInfo.flipH)
							normSamplePointInSrc.x = 1. - normSamplePointInSrc.x;
						if (opInfo.flipV)
							normSamplePointInSrc.y = 1. - normSamplePointInSrc.y;
						//	convert the normalized coords back to pixel coords within the src img frame- since the src & dst buffers have the same resolution, this is what we're sampling
						GPoint		samplePointInSrc = PixelForNormCoordsInRect(normSamplePointInSrc, opInfo.srcImgFrame);
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(samplePointInSrc.x, samplePointInSrc.y));
					}
					//	else we didn't have to do any flipping- we're sampling the same location in the src that we're populating in the dst
					else	{
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(dstLoc.x, dstLoc.y));
					}
				
					//	calculate the location of the pixel we're processing in the dst image, get its value
					//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
					//	get the normalized channel values at that location
					//float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, dstLoc);
				
					//	in this case, the src img is YCbCr.  UnpackNormChannelValsAtLoc() has unpacked the buffer and provided us with all three vals, we just have to convert them to RGB.
				
					normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_709 * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_709) * fadeToBlackMultiplier.rgb;
				
					normRGB[pixelIndex].a = 1.0;
					
					++pixelIndex;
				}
			}
		}
		break;
	case SwizzlePF_UYVY_PKPL_422_UI_16:
		{
			//	for each of the pixels we need to process in the dst image...
			unsigned int			pixelIndex = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					//	determine the location of the pixel we're populating in the destination
					GPoint		dstLoc = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel);
					//	if the pixel we're populating is outside the bounds of the source image, it's solid black
					if (!PointInRect(dstLoc, opInfo.srcImgFrame))	{
						normRGB[pixelIndex] = float4(0., 0., 0., 1.);
						++pixelIndex;
						continue;
					}
					float4			rawVals;
					//	if we have to do any flipping...
					if (opInfo.flipH || opInfo.flipV)	{
						//	convert the pixel coords to normalized coords within the src img frame
						GPoint		normSamplePointInSrc = NormCoordsOfPixelInRect(dstLoc, opInfo.srcImgFrame);
						if (opInfo.flipH)
							normSamplePointInSrc.x = 1. - normSamplePointInSrc.x;
						if (opInfo.flipV)
							normSamplePointInSrc.y = 1. - normSamplePointInSrc.y;
						//	convert the normalized coords back to pixel coords within the src img frame- since the src & dst buffers have the same resolution, this is what we're sampling
						GPoint		samplePointInSrc = PixelForNormCoordsInRect(normSamplePointInSrc, opInfo.srcImgFrame);
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(samplePointInSrc.x, samplePointInSrc.y));
					}
					//	else we didn't have to do any flipping- we're sampling the same location in the src that we're populating in the dst
					else	{
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(dstLoc.x, dstLoc.y));
					}
				
					//	calculate the location of the pixel we're processing in the dst image, get its value
					//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
					//	get the normalized channel values at that location
					//float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, dstLoc);
				
					//	in this case, the src img is YCbCr.  UnpackNormChannelValsAtLoc() has unpacked the buffer and provided us with all three vals, we just have to convert them to RGB.
				
					normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_709 * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_709) * fadeToBlackMultiplier.rgb;
				
					normRGB[pixelIndex].a = 1.0;
					
					++pixelIndex;
				}
			}
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			unsigned int			pixelIndex = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					//	determine the location of the pixel we're populating in the destination
					GPoint		dstLoc = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel);
					//	if the pixel we're populating is outside the bounds of the source image, it's solid black
					if (!PointInRect(dstLoc, opInfo.srcImgFrame))	{
						normRGB[pixelIndex] = float4(0., 0., 0., 1.);
						++pixelIndex;
						continue;
					}
					float4			rawVals;
					//	if we have to do any flipping...
					if (opInfo.flipH || opInfo.flipV)	{
						//	convert the pixel coords to normalized coords within the src img frame
						GPoint		normSamplePointInSrc = NormCoordsOfPixelInRect(dstLoc, opInfo.srcImgFrame);
						if (opInfo.flipH)
							normSamplePointInSrc.x = 1. - normSamplePointInSrc.x;
						if (opInfo.flipV)
							normSamplePointInSrc.y = 1. - normSamplePointInSrc.y;
						//	convert the normalized coords back to pixel coords within the src img frame- since the src & dst buffers have the same resolution, this is what we're sampling
						GPoint		samplePointInSrc = PixelForNormCoordsInRect(normSamplePointInSrc, opInfo.srcImgFrame);
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(samplePointInSrc.x, samplePointInSrc.y));
					}
					//	else we didn't have to do any flipping- we're sampling the same location in the src that we're populating in the dst
					else	{
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(dstLoc.x, dstLoc.y));
					}
				
					//	calculate the location of the pixel we're processing in the dst image, get its value
					//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
					//	get the normalized channel values at that location
					//float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, dstLoc);
				
					//	in this case, the src img is YCbCr.  UnpackNormChannelValsAtLoc() has unpacked the buffer and provided us with all three vals, we just have to convert them to RGB.
				
					normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_709 * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_709) * fadeToBlackMultiplier.rgb;
				
					normRGB[pixelIndex].a = rawVals.a;
					
					++pixelIndex;
				}
			}
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		{
			//	for each of the pixels we need to process in the dst image...
			unsigned int			pixelIndex = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					//	determine the location of the pixel we're populating in the destination
					GPoint		dstLoc = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel);
					//	if the pixel we're populating is outside the bounds of the source image, it's solid black
					if (!PointInRect(dstLoc, opInfo.srcImgFrame))	{
						normRGB[pixelIndex] = float4(0., 0., 0., 1.);
						++pixelIndex;
						continue;
					}
					float4			rawVals;
					//	if we have to do any flipping...
					if (opInfo.flipH || opInfo.flipV)	{
						//	convert the pixel coords to normalized coords within the src img frame
						GPoint		normSamplePointInSrc = NormCoordsOfPixelInRect(dstLoc, opInfo.srcImgFrame);
						if (opInfo.flipH)
							normSamplePointInSrc.x = 1. - normSamplePointInSrc.x;
						if (opInfo.flipV)
							normSamplePointInSrc.y = 1. - normSamplePointInSrc.y;
						//	convert the normalized coords back to pixel coords within the src img frame- since the src & dst buffers have the same resolution, this is what we're sampling
						GPoint		samplePointInSrc = PixelForNormCoordsInRect(normSamplePointInSrc, opInfo.srcImgFrame);
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(samplePointInSrc.x, samplePointInSrc.y));
					}
					//	else we didn't have to do any flipping- we're sampling the same location in the src that we're populating in the dst
					else	{
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(dstLoc.x, dstLoc.y));
					}
				
					//	calculate the location of the pixel we're processing in the dst image, get its value
					//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
					//	get the normalized channel values at that location
					//float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, dstLoc);
				
					//	in this case, the src img is YCbCr.  UnpackNormChannelValsAtLoc() has unpacked the buffer and provided us with all three vals, we just have to convert them to RGB.
				
					normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_709 * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_709) * fadeToBlackMultiplier.rgb;
				
					normRGB[pixelIndex].a = rawVals.a;
					
					++pixelIndex;
				}
			}
		}
		break;
	case SwizzlePF_UYVY_PKPL_420_UI_8:
	case SwizzlePF_UYVY_PL_420_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			unsigned int			pixelIndex = 0;
			for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
				for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
					//	determine the location of the pixel we're populating in the destination
					GPoint		dstLoc = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel);
					//	if the pixel we're populating is outside the bounds of the source image, it's solid black
					if (!PointInRect(dstLoc, opInfo.srcImgFrame))	{
						normRGB[pixelIndex] = float4(0., 0., 0., 1.);
						++pixelIndex;
						continue;
					}
					float4			rawVals;
					//	if we have to do any flipping...
					if (opInfo.flipH || opInfo.flipV)	{
						//	convert the pixel coords to normalized coords within the src img frame
						GPoint		normSamplePointInSrc = NormCoordsOfPixelInRect(dstLoc, opInfo.srcImgFrame);
						if (opInfo.flipH)
							normSamplePointInSrc.x = 1. - normSamplePointInSrc.x;
						if (opInfo.flipV)
							normSamplePointInSrc.y = 1. - normSamplePointInSrc.y;
						//	convert the normalized coords back to pixel coords within the src img frame- since the src & dst buffers have the same resolution, this is what we're sampling
						GPoint		samplePointInSrc = PixelForNormCoordsInRect(normSamplePointInSrc, opInfo.srcImgFrame);
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(samplePointInSrc.x, samplePointInSrc.y));
					}
					//	else we didn't have to do any flipping- we're sampling the same location in the src that we're populating in the dst
					else	{
						rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, uint2(dstLoc.x, dstLoc.y));
					}
				
					//	calculate the location of the pixel we're processing in the dst image, get its value
					//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
					//	get the normalized channel values at that location
					//float4			rawVals = UnpackNormChannelValsAtLoc(srcBuffer, opInfo.srcImg, dstLoc);
				
					//	in this case, the src img is YCbCr.  UnpackNormChannelValsAtLoc() has unpacked the buffer (and reordered YCbCr into YCbCr) and provided us with all three vals, we just have to convert them to RGB.
				
					//normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_601 * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_601) * fadeToBlackMultiplier.rgb;
					normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_709 * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_709) * fadeToBlackMultiplier.rgb;
					//normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_Full * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_Full) * fadeToBlackMultiplier.rgb;
					//normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_SD * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_SD) * fadeToBlackMultiplier.rgb;
					//normRGB[pixelIndex].rgb = kTransMatrix_YCbCr_to_RGB_HD * (rawVals.rgb - kTransOffset_YCbCr_to_RGB_HD) * fadeToBlackMultiplier.rgb;
				
					normRGB[pixelIndex].a = 1.0;
					
					++pixelIndex;
				}
			}
		}
		break;
	}
}


void PopulateAndResampleNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderOpInfo & opInfo, uint2 gid)	{
	float4		fadeToBlackMultiplier = float4(1.-opInfo.fadeToBlack, 1.-opInfo.fadeToBlack, 1.-opInfo.fadeToBlack, 1);
	//	INCOMPLETE- let's get the basic pixel format conversions finished before we take this on, hmm?
	unsigned int			pixelIndex = 0;
	for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
		for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
			normRGB[pixelIndex] = float4(1,0,0,1) * fadeToBlackMultiplier;	//	just make everything red for now...
			++pixelIndex;
		}
	}
}
void PopulateAndResampleNormRGBFromSrcTex(thread float4 * normRGB, texture2d<float,access::sample> inTex, constant SwizzleShaderOpInfo & opInfo, uint2 gid)	{
	
	constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::normalized);
	float4					fadeToBlackMultiplier = float4(1.-opInfo.fadeToBlack, 1.-opInfo.fadeToBlack, 1.-opInfo.fadeToBlack, 1);
	
	unsigned int			pixelIndex = 0;
	for (unsigned int yPixel = 0; yPixel < opInfo.dstPixelsToProcess[1]; ++yPixel)	{
		for (unsigned int xPixel = 0; xPixel < opInfo.dstPixelsToProcess[0]; ++xPixel)	{
			//	determine the location of the pixel we're populating in the destination
			GPoint		dstLoc = MakePoint( (gid.x * opInfo.dstPixelsToProcess[0]) + xPixel, (gid.y * opInfo.dstPixelsToProcess[1]) + yPixel);
			
			//	if the pixel we're populating is outside the bounds of the source image, it's solid black
			if (!PointInRect(dstLoc, opInfo.srcImgFrame))	{
				normRGB[pixelIndex] = float4(0., 0., 0., 1.);
				++pixelIndex;
				continue;
			}
		
			//	...if we're here, the pixel we're populating in the destination is within the source frame, so we have to sample the input texture
		
			//	convert the pixel coords to the normalized location within the source image's frame
			GPoint			normSamplePointInSrc = NormCoordsOfPixelInRect(dstLoc, opInfo.srcImgFrame);
			//	compensate for horizontal or vertical flippedness
			if (opInfo.flipH)
				normSamplePointInSrc.x = 1. - normSamplePointInSrc.x;
			if (opInfo.flipV)
				normSamplePointInSrc.y = 1. - normSamplePointInSrc.y;
		
			//	sample the input texture
			float4			srcColor = inTex.sample(sampler, float2(normSamplePointInSrc.x, normSamplePointInSrc.y));
			//	populate the normalized RGB value
			normRGB[pixelIndex] = srcColor * fadeToBlackMultiplier;
			
			++pixelIndex;
		}
	}
	
	
	//constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::normalized);
	//for (unsigned int pixelIndex = 0; pixelIndex < opInfo.dstPixelsToProcess; ++pixelIndex)	{
	//	uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
	//	float2			normDstLoc = float2( float(dstLoc.x)/float(opInfo.dstImg.res[0]-1), float(dstLoc.y)/float(opInfo.dstImg.res[1]-1) );
	//	float4			srcColor = inTex.sample(sampler, normDstLoc);
	//	normRGB[pixelIndex] = srcColor;
	//}
}


void PopulateDstFromNormRGB(device void * dstBuffer, constant SwizzleShaderOpInfo & opInfo, thread float4 * normRGB, uint2 gid)	{
	//uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess) + pixelIndex, gid.y);
	uint2			dstLoc = uint2( (gid.x * opInfo.dstPixelsToProcess[0]), (gid.y * opInfo.dstPixelsToProcess[1]));
	if (dstLoc.x >= opInfo.dstImg.res[0] || dstLoc.y >= opInfo.dstImg.res[1])
		return;
	
	switch (opInfo.dstImg.pf)	{
	case SwizzlePF_Unknown:
		return;
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBX_PK_UI_8:
		{
			//float4		normCodeVals[MAX_PIXELS_TO_PROCESS];
			//char4		codeVals[MAX_PIXELS_TO_PROCESS];
			
			size_t		bytesPerPixel = 8 * 4 / 8;	//	8 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(uint8_t)) + (offsetInBytes/sizeof(uint8_t));
			
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
			
			size_t		bytesPerPixel = 8 * 4 / 8;	//	8 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(uint8_t)) + (offsetInBytes/sizeof(uint8_t));
			
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
			
			size_t		bytesPerPixel = 8 * 4 / 8;	//	8 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(uint8_t)) + (offsetInBytes/sizeof(uint8_t));
			
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
			
			size_t		bytesPerPixel = 8 * 4 / 8;	//	8 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * opInfo.dstPixelsToProcess[1] * opInfo.dstImg.planes[0].bytesPerRow) + (gid.x * opInfo.dstPixelsToProcess[0] * bytesPerPixel);
			device float		*wPtr = (device float *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(float)) + (offsetInBytes/sizeof(float));
			
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
	case SwizzlePF_UYVY_PK_422_UI_8:
		{
			//	we were passed normalized RGB color vals- convert 'em to the dst color format (YCbCr in this case)
			uchar4		dstVals[MAX_PIXELS_TO_PROCESS];
			
			//	rec709
			//const float3x3		mat = float3x3(
			//	float3(0.183, -0.101, 0.439),
			//	float3(0.614, -0.339, -0.399),
			//	float3(0.062, 0.439, -0.040)
			//);
			//const float3		offsets = float3(16./255., 128./255., 128./255.);
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
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(uint8_t)) + (offsetInBytes/sizeof(uint8_t));
			
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
			
			//	rec709
			//const float3x3		mat = float3x3(
			//	float3(0.183, -0.101, 0.439),
			//	float3(0.614, -0.339, -0.399),
			//	float3(0.062, 0.439, -0.040)
			//);
			//const float3		offsets = float3(16./255., 128./255., 128./255.);
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
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(uint8_t)) + (offsetInBytes/sizeof(uint8_t));
			
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
			
			//	rec709
			//const float3x3		mat = float3x3(
			//	float3(0.183, -0.101, 0.439),
			//	float3(0.614, -0.339, -0.399),
			//	float3(0.062, 0.439, -0.040)
			//);
			//const float3		offsets = float3(16./255., 128./255., 128./255.);
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
			//size_t				bytesPerRow = imgInfo.res[0] / 6 * 4 * sizeof(uint32_t);
			size_t				offsetInBytes = (opInfo.dstImg.planes[0].bytesPerRow * gid.y) + (gid.x * 4 * sizeof(uint32_t));
			device uint32_t		*wPtr = (device uint32_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(uint32_t)) + (offsetInBytes/sizeof(uint32_t));
			for (int i=0; i<4; ++i)	{
				*(wPtr+i) = writeVals[i];
			}
		}
		break;
	case SwizzlePF_UYVY_PKPL_422_UI_16:
		{
			//	we were passed normalized RGB color vals- convert 'em to the dst color format (YCbCr in this case)
			ushort4		dstVals[MAX_PIXELS_TO_PROCESS];
			
			//	rec709
			//const float3x3		mat = float3x3(
			//	float3(0.183, -0.101, 0.439),
			//	float3(0.614, -0.339, -0.399),
			//	float3(0.062, 0.439, -0.040)
			//);
			//const float3		offsets = float3(16./255., 128./255., 128./255.);
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
			size_t		yBytesPerRow = sizeof(uint16_t) * opInfo.dstImg.res[0];
			size_t		yOffsetInBytes = yPlaneOffsetInBytes + (dstLoc.y * yBytesPerRow) + (dstLoc.x * sizeof(uint16_t));
			wPtr = ((device uint16_t *)dstBuffer) + (opInfo.dstImg.planes[0].offset/sizeof(uint16_t)) + (yOffsetInBytes/sizeof(uint16_t));
			*wPtr = dstVals[0].r;
			++wPtr;
			*wPtr = dstVals[1].r;
			
			//	after the y plane there's another plane of interleaved (422 subsampling) Cb/Cr values
			size_t		cbcrPlaneOffsetInBytes = yPlaneOffsetInBytes + (yBytesPerRow * opInfo.dstImg.res[1]);
			size_t		cbcrPlaneBytesPerRow = sizeof(uint16_t) * opInfo.dstImg.res[0];
			size_t		basePairOffsetInBytes = cbcrPlaneOffsetInBytes + (basePairLoc.y * cbcrPlaneBytesPerRow) + (basePairLoc.x * sizeof(uint16_t));
			wPtr = (device uint16_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(uint16_t)) + (basePairOffsetInBytes/sizeof(uint16_t));
			*wPtr = (dstVals[0].g + dstVals[1].g) / 2;
			++wPtr;
			*wPtr = (dstVals[0].b + dstVals[1].b) / 2;
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_8:
		{
			//	we were passed normalized RGB color vals- convert 'em to the dst color format (YCbCr in this case)
			uchar4		dstVals[MAX_PIXELS_TO_PROCESS];
			
			//	rec709
			//const float3x3		mat = float3x3(
			//	float3(0.183, -0.101, 0.439),
			//	float3(0.614, -0.339, -0.399),
			//	float3(0.062, 0.439, -0.040)
			//);
			//const float3		offsets = float3(16./255., 128./255., 128./255.);
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
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(uint8_t)) + (offsetInBytes/sizeof(uint8_t));
			
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
			size_t		alphaPlaneOffsetInBytes = opInfo.dstImg.planes[0].bytesPerRow * opInfo.dstImg.res[1];
			size_t		alphaPlaneBytesPerPixel = sizeof(uint8_t);
			size_t		alphaPlaneBytesPerRow = alphaPlaneBytesPerPixel * opInfo.dstImg.res[0];
			size_t		alphaLocOffsetInBytes = alphaPlaneOffsetInBytes + (dstLoc.y * alphaPlaneBytesPerRow) + (dstLoc.x * alphaPlaneBytesPerPixel);
			
			wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(uint8_t)) + (alphaLocOffsetInBytes/sizeof(uint8_t));
			*wPtr = dstVals[0].a;
			++wPtr;
			*wPtr = dstVals[1].a;
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		{
			
			//	we were passed normalized RGB color vals- convert 'em to the dst color format (YCbCr in this case)
			ushort4		dstVals[MAX_PIXELS_TO_PROCESS];
			
			//	rec709
			//const float3x3		mat = float3x3(
			//	float3(0.183, -0.101, 0.439),
			//	float3(0.614, -0.339, -0.399),
			//	float3(0.062, 0.439, -0.040)
			//);
			//const float3		offsets = float3(16./255., 128./255., 128./255.);
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
			size_t		yBytesPerRow = sizeof(uint16_t) * opInfo.dstImg.res[0];
			size_t		yOffsetInBytes = yPlaneOffsetInBytes + (dstLoc.y * yBytesPerRow) + (dstLoc.x * sizeof(uint16_t));
			wPtr = ((device uint16_t *)dstBuffer) + (yOffsetInBytes/sizeof(uint16_t));
			*wPtr = dstVals[0].r;
			++wPtr;
			*wPtr = dstVals[1].r;
			
			//	after the y plane there's another plane of interleaved (422 subsampling) Cb/Cr values
			size_t		cbcrPlaneOffsetInBytes = yPlaneOffsetInBytes + (yBytesPerRow * opInfo.dstImg.res[1]);
			size_t		cbcrPlaneBytesPerRow = sizeof(uint16_t) * opInfo.dstImg.res[0];
			size_t		basePairOffsetInBytes = cbcrPlaneOffsetInBytes + (basePairLoc.y * cbcrPlaneBytesPerRow) + (basePairLoc.x * sizeof(uint16_t));
			wPtr = (device uint16_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(uint8_t)) + (basePairOffsetInBytes/sizeof(uint16_t));
			*wPtr = (dstVals[0].g + dstVals[1].g) / 2;
			++wPtr;
			*wPtr = (dstVals[0].b + dstVals[1].b) / 2;
			
			//	after the Cb/Cr plane there is an alpha plane
			
			size_t		aPlaneOffsetInBytes = cbcrPlaneOffsetInBytes + (cbcrPlaneBytesPerRow * opInfo.dstImg.res[1]);
			size_t		aBytesPerRow = yBytesPerRow;
			size_t		aOffsetInBytes = aPlaneOffsetInBytes + (aBytesPerRow * dstLoc.y) + (sizeof(uint16_t) * dstLoc.x);
			wPtr = (device uint16_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(uint8_t)) + (aOffsetInBytes/sizeof(uint16_t));
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
					wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(uint8_t)) + (offsetInBytes/sizeof(uint8_t));
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
			wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[1].offset/sizeof(uint8_t)) + (offsetInBytes/sizeof(uint8_t));
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
					wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[0].offset/sizeof(uint8_t)) + (offsetInBytes/sizeof(uint8_t));
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
			wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[1].offset/sizeof(uint8_t)) + (offsetInBytes/sizeof(uint8_t));
			*wPtr = (uint8_t)cb;
			wPtr = (device uint8_t *)dstBuffer + (opInfo.dstImg.planes[2].offset/sizeof(uint8_t)) + (offsetInBytes/sizeof(uint8_t));
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



















