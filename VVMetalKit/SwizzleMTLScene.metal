#include <metal_stdlib>
#include "SwizzleMTLSceneTypes.h"

using namespace metal;




//	returns the normalized values of the channels from the passed src buffer/imageInfo at the passed location
//	doesn't convert any colors- only converts ints (code point values) to normalized float vals, at most
//	doesn't do any interpolation- 
float4 NormChannelValsAtLoc(constant void * srcBuffer, constant SwizzleShaderInfo * imageInfo, uint2 loc);

//	populates the passed array of 'normRGB' values from the passed 'srcBuffer', using 'imageInfo' (which describes the nature of 'srcBuffer')
void PopulateNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderInfo & imageInfo, uint2 gid);
//	same as above, but there's a size mismatch between the src and dst images and we need to do some resampling!
void PopulateAndResampleNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderInfo & imageInfo, uint2 gid);
//	populates the passed array of 'normRGB' values from the passed texture, using 'imageInfo' (which describes the nature of 'srcTexture')
void PopulateAndResampleNormRGBFromSrcTex(thread float4 * normRGB, texture2d<float,access::sample> inTex, constant SwizzleShaderInfo & imageInfo, uint2 gid);

//	populates the passed dst buffer using the contents of the passed normalized RGB values
void PopulateDstFromNormRGB(device void * dstBuffer, constant SwizzleShaderInfo & imageInfo, thread float4 * normRGB, uint2 gid);




kernel void SwizzleMTLSceneFunc(
	constant void * srcBuffer [[ buffer(SwizzleShaderArg_SrcBuffer) ]],
	texture2d<float,access::sample> srcRGBTexture [[ texture(SwizzleShaderArg_SrcRGBTexture) ]],
	device void * dstBuffer [[ buffer(SwizzleShaderArg_DstBuffer) ]],
	texture2d<float,access::write> dstRGBTexture [[ texture(SwizzleShaderArg_DstRGBTexture) ]],
	constant SwizzleShaderInfo & imageInfo [[ buffer(SwizzleShaderArg_ImgInfo) ]],
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
	if (!is_null_texture(srcRGBTexture))	{
		//	populate the normalized RGB pixel values from the RGB texture....
		PopulateAndResampleNormRGBFromSrcTex(normRGB, srcRGBTexture, imageInfo, gid);
	}
	//	else we're not reading from a src texture- we're reading from a src buffer...
	else	{
		//	if the dst and src image sizes differ...
		if (imageInfo.dstImg.res[0] != imageInfo.srcImg.res[0] || imageInfo.dstImg.res[1] != imageInfo.srcImg.res[1])	{
			//	use a different function to calculate the normalized RGB vals- we'll do this part last, once we get everything else working!
			PopulateAndResampleNormRGBFromSrcBuffer(normRGB, srcBuffer, imageInfo, gid);
		}
		//	else the dst and src images have the same size...
		else	{
			//	populate the normalized RGB vals from the src buffer
			PopulateNormRGBFromSrcBuffer(normRGB, srcBuffer, imageInfo, gid);
		}
	}
	
	//	if there's a destination RGB texture attached, write the pixels to it now
	if (!is_null_texture(dstRGBTexture))	{
		for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
			uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
			if (dstLoc.x < imageInfo.dstImg.res[0] && dstLoc.y < imageInfo.dstImg.res[1])
				dstRGBTexture.write(normRGB[pixelIndex], dstLoc);
		}
	}
	
	//	if we're supposed to be writing to the buffer, and the dst buffer is non-nil, populate it now
	if (writeToBuffer && dstBuffer != nullptr)	{
		PopulateDstFromNormRGB(dstBuffer, imageInfo, normRGB, gid);
	}
	
	
	
	
	
	
	
	
	
	/*
	//	if we're reading from a src texture...
	if (!is_null_texture(srcRGBTexture))	{
		//	populate the normalized RGB pixel values from the RGB texture....
		PopulateAndResampleNormRGBFromSrcTex(normRGB, srcRGBTexture, imageInfo, gid);
	}
	//	else we're not reading from a src texture- we're reading from a src buffer...
	else	{
		//	if the dst and src image sizes differ...
		if (imageInfo.dstImg.res[0] != imageInfo.srcImg.res[0] || imageInfo.dstImg.res[1] != imageInfo.srcImg.res[1])	{
			//	use a different function to calculate the normalized RGB vals- we'll do this part last, once we get everything else working!
			PopulateAndResampleNormRGBFromSrcBuffer(normRGB, srcBuffer, imageInfo, gid);
		}
		//	else the dst and src images have the same size...
		else	{
			//	populate the normalized RGB vals from the src buffer
			PopulateNormRGBFromSrcBuffer(normRGB, srcBuffer, imageInfo, gid);
		}
	}
	
	//	if there's a destination RGB texture attached, write the pixels to it now
	if (!is_null_texture(dstRGBTexture))	{
		for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
			uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
			if (dstLoc.x < imageInfo.dstImg.res[0] && dstLoc.y < imageInfo.dstImg.res[1])
				dstRGBTexture.write(normRGB[pixelIndex], dstLoc);
		}
	}
	
	//	if there's a dst buffer, populate it from the RGB values!
	if (dstBuffer != nullptr)	{
		PopulateDstFromNormRGB(dstBuffer, imageInfo, normRGB, gid);
	}
	*/
}




float4 NormChannelValsAtLoc(constant void * srcBuffer, constant SwizzleShaderImageInfo & imgInfo, uint2 loc)
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
			size_t		offsetInBytes = (loc.y * imgInfo.bytesPerRow) + (loc.x * bytesPerPixel);
			//uint8_t		*rPtr = (srcBuffer + offsetInBytes);
			constant uint8_t		*rPtr = (constant uint8_t *)srcBuffer + (offsetInBytes/sizeof(uint8_t));
			
			for (int i=0; i<4; ++i)	{
				returnMe[i] = float(*rPtr) / 255.;
				++rPtr;
			}
		}
		break;
	case SwizzlePF_RGBA_PK_FP_32:
		{
			size_t		bytesPerPixel = 32 * 4 / 8;	//	32 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (loc.y * imgInfo.bytesPerRow) + (loc.x * bytesPerPixel);
			//float		*rPtr = (srcBuffer + offsetInBytes);
			constant float		*rPtr = (constant float *)srcBuffer + (offsetInBytes/sizeof(float));
			for (int i=0; i<4; ++i)	{
				returnMe[i] = *rPtr;
				++rPtr;
			}
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_8:
		{
			size_t		bytesPerPixel = 8 * 2 / 8;	//	8 bits per channel, 2 channels per pixel (Y + Cb/Cr), 8 bits per byte
			
			uint2		basePairLoc = loc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			basePairLoc.x -= basePairLoc.x % 2;	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			
			//	in memory, the order is "Cb Y Cr Y"
			
			//	this is a packed pixel format- to decode one pixel of output, we have to read two pixels from the src buffer
			
			//	the "base pair location" is how we get Cb and Cr.  the location is how we get the Y value.
			
			size_t		locOffsetInBytes = (loc.y * imgInfo.bytesPerRow) + (loc.x * bytesPerPixel);
			size_t		basePairOffsetInBytes = (basePairLoc.y * imgInfo.bytesPerRow) + (basePairLoc.x * bytesPerPixel);
			
			constant uint8_t		*rPtr;
			
			//	get the Y value
			rPtr = (constant uint8_t *)srcBuffer + (locOffsetInBytes/sizeof(uint8_t));
			rPtr += 1;
			returnMe[0] = float(*rPtr) / 255.;
			
			//	Cb and Cr
			rPtr = (constant uint8_t *)srcBuffer + (basePairOffsetInBytes/sizeof(uint8_t));
			returnMe[1] = float(*rPtr) / 255.;
			rPtr += 2;
			returnMe[2] = float(*rPtr) / 255.;
			
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_10:
		{
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
			rPtr = ((constant uint16_t *)srcBuffer) + (yOffsetInBytes/sizeof(uint16_t));
			returnMe[0] = float(*rPtr) / 65535.;
			
			//	after the luma plane is another plane of interleaved (422 subsampling) Cb/Cr values
			
			size_t		cbcrPlaneOffsetInBytes = yPlaneOffsetInBytes + (yBytesPerRow * imgInfo.res[1]);
			size_t		cbcrPlaneBytesPerRow = sizeof(uint16_t) * imgInfo.res[0];
			size_t		basePairOffsetInBytes = cbcrPlaneOffsetInBytes + (basePairLoc.y * cbcrPlaneBytesPerRow) + (basePairLoc.x * sizeof(uint16_t));
			rPtr = ((constant uint16_t *)srcBuffer) + (basePairOffsetInBytes/sizeof(uint16_t));
			returnMe[1] = float(*(rPtr+0)) / 65535.;
			returnMe[2] = float(*(rPtr+1)) / 65535.;
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_8:
		{
			size_t		bytesPerPixel = 8 * 2 / 8;	//	8 bits per channel, 2 channels per pixel (Y + Cb/Cr), 8 bits per byte
			
			uint2		basePairLoc = loc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			basePairLoc.x -= basePairLoc.x % 2;	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			
			//	in memory, the order is "Cb Y Cr Y"
			
			//	this is a packed pixel format- to decode one pixel of output, we have to read two pixels from the src buffer
			
			//	the "base pair location" is how we get Cb and Cr.  the location is how we get the Y value.
			
			size_t		locOffsetInBytes = (loc.y * imgInfo.bytesPerRow) + (loc.x * bytesPerPixel);
			size_t		basePairOffsetInBytes = (basePairLoc.y * imgInfo.bytesPerRow) + (basePairLoc.x * bytesPerPixel);
			
			constant uint8_t		*rPtr;
			
			//	get the Y value
			rPtr = (constant uint8_t *)srcBuffer + (locOffsetInBytes/sizeof(uint8_t));
			rPtr += 1;
			returnMe[0] = float(*rPtr) / 255.;
			
			//	Cb and Cr
			rPtr = (constant uint8_t *)srcBuffer + (basePairOffsetInBytes/sizeof(uint8_t));
			returnMe[1] = float(*rPtr) / 255.;
			rPtr += 2;
			returnMe[2] = float(*rPtr) / 255.;
			
			//	get the A value
			size_t		alphaPlaneOffsetInBytes = imgInfo.bytesPerRow * imgInfo.res[1];
			size_t		alphaPlaneBytesPerPixel = sizeof(uint8_t);
			size_t		alphaPlaneBytesPerRow = alphaPlaneBytesPerPixel * imgInfo.res[0];
			size_t		alphaLocOffsetInBytes = alphaPlaneOffsetInBytes + (loc.y * alphaPlaneBytesPerRow) + (loc.x * alphaPlaneBytesPerPixel);
			
			rPtr = (constant uint8_t *)srcBuffer + (alphaLocOffsetInBytes/sizeof(uint8_t));
			returnMe[3] = float(*rPtr) / 255.;
			//returnMe[3] = 1.0;
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		{
			/*
			uint2		basePairLoc = loc;
			//if (basePairLoc.x % 2 != 0)
			//	basePairLoc.x = basePairLoc.x - 1;
			basePairLoc.x -= (basePairLoc.x % 2);	//	if the location of the pixel we're checking isn't an even multiple of 2, the base pair is the previous pixel
			
			constant uint16_t		*rPtr;
			
			//	in memory, first there's a luma plane...
			
			size_t		yPlaneOffsetInBytes = 0;
			size_t		yBytesPerRow = sizeof(uint16_t) * imgInfo.res[0];
			size_t		yOffsetInBytes = yPlaneOffsetInBytes + (loc.y * yBytesPerRow) + (loc.x * sizeof(uint16_t));
			rPtr = ((constant uint16_t *)srcBuffer) + (yOffsetInBytes/sizeof(uint16_t));
			returnMe[0] = float(*rPtr) / 65535.;
			
			//	after the luma plane is another plane of interleaved (422 subsampling) Cb/Cr values
			
			size_t		cbcrPlaneOffsetInBytes = yPlaneOffsetInBytes + (yBytesPerRow * imgInfo.res[1]);
			size_t		cbcrPlaneBytesPerRow = sizeof(uint16_t) * imgInfo.res[0];
			size_t		basePairOffsetInBytes = cbcrPlaneOffsetInBytes + (basePairLoc.y * cbcrPlaneBytesPerRow) + (basePairLoc.x * sizeof(uint16_t));
			rPtr = ((constant uint16_t *)srcBuffer) + (basePairOffsetInBytes/sizeof(uint16_t));
			returnMe[1] = float(*(rPtr+0)) / 65535.;
			returnMe[2] = float(*(rPtr+1)) / 65535.;
			
			//	after the Cb/Cr plane is an alpha plane
			
			size_t		aPlaneOffsetInBytes = cbcrPlaneOffsetInBytes + (cbcrPlaneBytesPerRow * imgInfo.res[1]);
			size_t		aBytesPerRow = yBytesPerRow;
			size_t		aOffsetInBytes = aPlaneOffsetInBytes + (aBytesPerRow * loc.y) + (sizeof(uint16_t) * loc.x);
			rPtr = (constant uint16_t *)srcBuffer + (aOffsetInBytes/sizeof(uint16_t));
			returnMe[3] = float(*rPtr) / 65535.;
			*/
		}
		break;
	}
	
	return returnMe;
}

void PopulateNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderInfo & imageInfo, uint2 gid)	{
	
	//				****** IMPORTANT *******
	//	this function assumes that the src and dst buffers have the same resolution!
	
	switch (imageInfo.srcImg.pf)	{
	case SwizzlePF_Unknown:
		{
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				normRGB[pixelIndex] = float4(0,1,0,1);
			}
		}
		break;
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBA_PK_FP_32:
		{
			//	for each of the pixels we need to process in the dst image...
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//	calculate the location of the pixel we're processing in the dst image, get its value
				uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				//	get the normalized channel values at that location
				float4			rawVals = NormChannelValsAtLoc(srcBuffer, imageInfo.srcImg, dstLoc);
				
				//	in this case, the src image is RGB- we already have the normalized RGB vals, so we're basically done!
				normRGB[pixelIndex] = rawVals.rgba;
			}
		}
		break;
	case SwizzlePF_RGBX_PK_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//	calculate the location of the pixel we're processing in the dst image, get its value
				uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				//	get the normalized channel values at that location
				float4			rawVals = NormChannelValsAtLoc(srcBuffer, imageInfo.srcImg, dstLoc);
				
				//	in this case, the src image is RGB- we already have the normalized RGB vals, so we're basically done!
				normRGB[pixelIndex] = rawVals.rgba;
				
				//	if it's a RGBX pixel format, set the alpha to 1!
				normRGB[pixelIndex].a = 1.0;
			}
		}
		break;
	case SwizzlePF_BGRA_PK_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//	calculate the location of the pixel we're processing in the dst image, get its value
				uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				//	get the normalized channel values at that location
				float4			rawVals = NormChannelValsAtLoc(srcBuffer, imageInfo.srcImg, dstLoc);
				
				//	note: the image data in the src buffer is BGRA!
				
				//	image data is:			B	G	R	A
				//	code to access above:	R	G	B	A
				normRGB[pixelIndex] = rawVals.bgra;
			}
		}
		break;
	case SwizzlePF_BGRX_PK_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//	calculate the location of the pixel we're processing in the dst image, get its value
				uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				//	get the normalized channel values at that location
				float4			rawVals = NormChannelValsAtLoc(srcBuffer, imageInfo.srcImg, dstLoc);
				
				//	note: the image data in the src buffer is BGRA!
				
				//	image data is:			B	G	R	A
				//	code to access above:	R	G	B	A
				normRGB[pixelIndex] = rawVals.bgra;
				
				//	if it's a BGRX pixel format, set the alpha to 1!
				normRGB[pixelIndex].a = 1.0;
			}
		}
		break;
	case SwizzlePF_ARGB_PK_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//	calculate the location of the pixel we're processing in the dst image, get its value
				uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				//	get the normalized channel values at that location
				float4			rawVals = NormChannelValsAtLoc(srcBuffer, imageInfo.srcImg, dstLoc);
				
				//	note: the image data in the src buffer is ARGB!
				
				//	image data is:			A	R	G	B
				//	code to access above:	R	G	B	A
				normRGB[pixelIndex] = rawVals.gbar;
			}
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//	calculate the location of the pixel we're processing in the dst image, get its value
				uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				//	get the normalized channel values at that location
				float4			rawVals = NormChannelValsAtLoc(srcBuffer, imageInfo.srcImg, dstLoc);
				
				//	in this case, the src img is YCbCr.  NormChannelValsAtLoc() has unpacked the buffer and provided us with all three vals, we just have to convert them to RGB.
				
				//	rec709
				const float3x3		mat = float3x3(
					float3(1.164, 1.164, 1.164),
					float3(0.0, -0.213, 2.112),
					float3(1.793, -0.533, 0.0)
				);
				const float3		offsets = float3(16./255., 128./255., 128./255.);
				
				normRGB[pixelIndex].rgb = mat * (rawVals.rgb - offsets);
				
				
				normRGB[pixelIndex].a = 1.0;
			}
			
			
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_10:
		{
		}
		break;
	case SwizzlePF_UYVY_PKPL_422_UI_16:
		{
			//	for each of the pixels we need to process in the dst image...
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//	calculate the location of the pixel we're processing in the dst image, get its value
				uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				//	get the normalized channel values at that location
				float4			rawVals = NormChannelValsAtLoc(srcBuffer, imageInfo.srcImg, dstLoc);
				
				//	in this case, the src img is YCbCr.  NormChannelValsAtLoc() has unpacked the buffer and provided us with all three vals, we just have to convert them to RGB.
				
				//	rec709
				const float3x3		mat = float3x3(
					float3(1.164, 1.164, 1.164),
					float3(0.0, -0.213, 2.112),
					float3(1.793, -0.533, 0.0)
				);
				const float3		offsets = float3(16./255., 128./255., 128./255.);
				
				normRGB[pixelIndex].rgb = mat * (rawVals.rgb - offsets);
				
				
				normRGB[pixelIndex].a = 1.0;
			}
			
			
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//	calculate the location of the pixel we're processing in the dst image, get its value
				uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				//	get the normalized channel values at that location
				float4			rawVals = NormChannelValsAtLoc(srcBuffer, imageInfo.srcImg, dstLoc);
				
				//	in this case, the src img is YCbCr.  NormChannelValsAtLoc() has unpacked the buffer and provided us with all three vals, we just have to convert them to RGB.
				
				//	rec709
				const float3x3		mat = float3x3(
					float3(1.164, 1.164, 1.164),
					float3(0.0, -0.213, 2.112),
					float3(1.793, -0.533, 0.0)
				);
				const float3		offsets = float3(16./255., 128./255., 128./255.);
				
				normRGB[pixelIndex].rgb = mat * (rawVals.rgb - offsets);
				
				
				normRGB[pixelIndex].a = rawVals.a;
			}
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		{
			/*
			//	for each of the pixels we need to process in the dst image...
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//	calculate the location of the pixel we're processing in the dst image, get its value
				uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				//	get the normalized channel values at that location
				float4			rawVals = NormChannelValsAtLoc(srcBuffer, imageInfo.srcImg, dstLoc);
				
				//	in this case, the src img is YCbCr.  NormChannelValsAtLoc() has unpacked the buffer and provided us with all three vals, we just have to convert them to RGB.
				
				//	rec709
				const float3x3		mat = float3x3(
					float3(1.164, 1.164, 1.164),
					float3(0.0, -0.213, 2.112),
					float3(1.793, -0.533, 0.0)
				);
				const float3		offsets = float3(16./255., 128./255., 128./255.);
				
				normRGB[pixelIndex].rgb = mat * (rawVals.rgb - offsets);
				
				
				normRGB[pixelIndex].a = rawVals.a;
			}
			*/
		}
		break;
	}
}

void PopulateAndResampleNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderInfo & imageInfo, uint2 gid)	{
	//	INCOMPLETE- let's get the basic pixel format conversions finished before we take this on, hmm?
	for (int i=0; i<MAX_PIXELS_TO_PROCESS; ++i)	{
		normRGB[i] = float4(1,0,0,1);	//	just make everything red for now...
	}
	/*
	switch (imageInfo.srcImg.pf)	{
	case SwizzlePF_RGBA_PK_UI_8:
		{
			for (int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				float2			normDstLoc = float2( float(dstLoc.y)/float(imageInfo.dstImg.res[0]), float(dstLoc.y)/float(imageInfo.dstImg.res[1]) );
			}
		}
		break;
	case SwizzlePF_RGBX_PK_UI_8:
		break;
	case SwizzlePF_BGRA_PK_UI_8:
		break;
	case SwizzlePF_BGRX_PK_UI_8:
		break;
	case SwizzlePF_ARGB_PK_UI_8:
		break;
	case SwizzlePF_RGBA_PK_FP_32:
		break;
	case SwizzlePF_UYVY_PK_422_UI_8:
		{
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_10:
		{
		}
		break;
	case SwizzlePF_UYVY_PL_422_UI_16:
		{
		}
		break;
	}
	*/
}
void PopulateAndResampleNormRGBFromSrcTex(thread float4 * normRGB, texture2d<float,access::sample> inTex, constant SwizzleShaderInfo & imageInfo, uint2 gid)	{
	constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::normalized);
	for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
		uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
		float2			normDstLoc = float2( float(dstLoc.x)/float(imageInfo.dstImg.res[0]-1), float(dstLoc.y)/float(imageInfo.dstImg.res[1]-1) );
		float4			srcColor = inTex.sample(sampler, normDstLoc);
		normRGB[pixelIndex] = srcColor;
	}
}

void PopulateDstFromNormRGB(device void * dstBuffer, constant SwizzleShaderInfo & imageInfo, thread float4 * normRGB, uint2 gid)	{
	//uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
	uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess), gid.y);
	if (dstLoc.x >= imageInfo.dstImg.res[0] || dstLoc.y >= imageInfo.dstImg.res[1])
		return;
	
	switch (imageInfo.dstImg.pf)	{
	case SwizzlePF_Unknown:
		return;
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBX_PK_UI_8:
		{
			//float4		normCodeVals[MAX_PIXELS_TO_PROCESS];
			//char4		codeVals[MAX_PIXELS_TO_PROCESS];
			
			size_t		bytesPerPixel = 8 * 4 / 8;	//	8 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * imageInfo.dstImg.bytesPerRow) + (gid.x * imageInfo.dstPixelsToProcess * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (offsetInBytes/sizeof(uint8_t));
			
			//for (int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//normCodeVals[pixelIndex] = normRGB[pixelIndex];
				//uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				
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
			size_t		offsetInBytes = (gid.y * imageInfo.dstImg.bytesPerRow) + (gid.x * imageInfo.dstPixelsToProcess * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (offsetInBytes/sizeof(uint8_t));
			
			//for (int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//normCodeVals[pixelIndex] = normRGB[pixelIndex];
				//uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				
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
			size_t		offsetInBytes = (gid.y * imageInfo.dstImg.bytesPerRow) + (gid.x * imageInfo.dstPixelsToProcess * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (offsetInBytes/sizeof(uint8_t));
			
			//for (int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//normCodeVals[pixelIndex] = normRGB[pixelIndex];
				//uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				
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
			size_t		offsetInBytes = (gid.y * imageInfo.dstImg.bytesPerRow) + (gid.x * imageInfo.dstPixelsToProcess * bytesPerPixel);
			device float		*wPtr = (device float *)dstBuffer + (offsetInBytes/sizeof(float));
			
			//for (int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//normCodeVals[pixelIndex] = normRGB[pixelIndex];
				//uint2			dstLoc = uint2( (gid.x * imageInfo.dstPixelsToProcess) + pixelIndex, gid.y);
				
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
			const float3x3		mat = float3x3(
				float3(0.183, -0.101, 0.439),
				float3(0.614, -0.339, -0.399),
				float3(0.062, 0.439, -0.040)
			);
			const float3		offsets = float3(16./255., 128./255., 128./255.);
			
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//	convert normalized RGB to normalized YCbCr
				float4		normDstVal;
				normDstVal.rgb = (mat * normRGB[pixelIndex].rgb) + offsets;
				normDstVal.a = normRGB[pixelIndex].a;
				
				//	convert normalized YCbCr to the code point vals we'll want to (combine and) write (8-bit vals in this case)
				dstVals[pixelIndex] = uchar4(round(normDstVal * 255.));
			}
			
			//	figure out the base address at which we need to start writing pixels
			size_t		bytesPerPixel = 8 * 2 / 8;	//	8 bits per channel, 2 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * imageInfo.dstImg.bytesPerRow) + (gid.x * imageInfo.dstPixelsToProcess * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (offsetInBytes/sizeof(uint8_t));
			
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
	case SwizzlePF_UYVY_PK_422_UI_10:
		{
		}
		break;
	case SwizzlePF_UYVY_PKPL_422_UI_16:
		{
			//	we were passed normalized RGB color vals- convert 'em to the dst color format (YCbCr in this case)
			ushort4		dstVals[MAX_PIXELS_TO_PROCESS];
			
			//	rec709
			const float3x3		mat = float3x3(
				float3(0.183, -0.101, 0.439),
				float3(0.614, -0.339, -0.399),
				float3(0.062, 0.439, -0.040)
			);
			const float3		offsets = float3(16./255., 128./255., 128./255.);
			
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
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
			size_t		yBytesPerRow = sizeof(uint16_t) * imageInfo.dstImg.res[0];
			size_t		yOffsetInBytes = yPlaneOffsetInBytes + (dstLoc.y * yBytesPerRow) + (dstLoc.x * sizeof(uint16_t));
			wPtr = ((device uint16_t *)dstBuffer) + (yOffsetInBytes/sizeof(uint16_t));
			*wPtr = dstVals[0].r;
			++wPtr;
			*wPtr = dstVals[1].r;
			
			//	after the y plane there's another plane of interleaved (422 subsampling) Cb/Cr values
			size_t		cbcrPlaneOffsetInBytes = yPlaneOffsetInBytes + (yBytesPerRow * imageInfo.dstImg.res[1]);
			size_t		cbcrPlaneBytesPerRow = sizeof(uint16_t) * imageInfo.dstImg.res[0];
			size_t		basePairOffsetInBytes = cbcrPlaneOffsetInBytes + (basePairLoc.y * cbcrPlaneBytesPerRow) + (basePairLoc.x * sizeof(uint16_t));
			wPtr = (device uint16_t *)dstBuffer + (basePairOffsetInBytes/sizeof(uint16_t));
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
			const float3x3		mat = float3x3(
				float3(0.183, -0.101, 0.439),
				float3(0.614, -0.339, -0.399),
				float3(0.062, 0.439, -0.040)
			);
			const float3		offsets = float3(16./255., 128./255., 128./255.);
			
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
				//	convert normalized RGB to normalized YCbCr
				float4		normDstVal;
				normDstVal.rgb = (mat * normRGB[pixelIndex].rgb) + offsets;
				normDstVal.a = normRGB[pixelIndex].a;
				
				//	convert normalized YCbCr to the code point vals we'll want to (combine and) write (8-bit vals in this case)
				dstVals[pixelIndex] = uchar4(round(normDstVal * 255.));
			}
			
			//	figure out the base address at which we need to start writing pixels
			size_t		bytesPerPixel = 8 * 2 / 8;	//	8 bits per channel, 2 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * imageInfo.dstImg.bytesPerRow) + (gid.x * imageInfo.dstPixelsToProcess * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (offsetInBytes/sizeof(uint8_t));
			
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
			size_t		alphaPlaneOffsetInBytes = imageInfo.dstImg.bytesPerRow * imageInfo.dstImg.res[1];
			size_t		alphaPlaneBytesPerPixel = sizeof(uint8_t);
			size_t		alphaPlaneBytesPerRow = alphaPlaneBytesPerPixel * imageInfo.dstImg.res[0];
			size_t		alphaLocOffsetInBytes = alphaPlaneOffsetInBytes + (dstLoc.y * alphaPlaneBytesPerRow) + (dstLoc.x * alphaPlaneBytesPerPixel);
			
			wPtr = (device uint8_t *)dstBuffer + (alphaLocOffsetInBytes/sizeof(uint8_t));
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
			const float3x3		mat = float3x3(
				float3(0.183, -0.101, 0.439),
				float3(0.614, -0.339, -0.399),
				float3(0.062, 0.439, -0.040)
			);
			const float3		offsets = float3(16./255., 128./255., 128./255.);
			
			for (unsigned int pixelIndex = 0; pixelIndex < imageInfo.dstPixelsToProcess; ++pixelIndex)	{
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
			size_t		yBytesPerRow = sizeof(uint16_t) * imageInfo.dstImg.res[0];
			size_t		yOffsetInBytes = yPlaneOffsetInBytes + (dstLoc.y * yBytesPerRow) + (dstLoc.x * sizeof(uint16_t));
			wPtr = ((device uint16_t *)dstBuffer) + (yOffsetInBytes/sizeof(uint16_t));
			*wPtr = dstVals[0].r;
			++wPtr;
			*wPtr = dstVals[1].r;
			
			//	after the y plane there's another plane of interleaved (422 subsampling) Cb/Cr values
			size_t		cbcrPlaneOffsetInBytes = yPlaneOffsetInBytes + (yBytesPerRow * imageInfo.dstImg.res[1]);
			size_t		cbcrPlaneBytesPerRow = sizeof(uint16_t) * imageInfo.dstImg.res[0];
			size_t		basePairOffsetInBytes = cbcrPlaneOffsetInBytes + (basePairLoc.y * cbcrPlaneBytesPerRow) + (basePairLoc.x * sizeof(uint16_t));
			wPtr = (device uint16_t *)dstBuffer + (basePairOffsetInBytes/sizeof(uint16_t));
			*wPtr = (dstVals[0].g + dstVals[1].g) / 2;
			++wPtr;
			*wPtr = (dstVals[0].b + dstVals[1].b) / 2;
			
			//	after the Cb/Cr plane there is an alpha plane
			
			size_t		aPlaneOffsetInBytes = cbcrPlaneOffsetInBytes + (cbcrPlaneBytesPerRow * imageInfo.dstImg.res[1]);
			size_t		aBytesPerRow = yBytesPerRow;
			size_t		aOffsetInBytes = aPlaneOffsetInBytes + (aBytesPerRow * dstLoc.y) + (sizeof(uint16_t) * dstLoc.x);
			wPtr = (device uint16_t *)dstBuffer + (aOffsetInBytes/sizeof(uint16_t));
			*wPtr = dstVals[0].a;
			++wPtr;
			*wPtr = dstVals[1].a;
			
		}
		break;
	}
}



