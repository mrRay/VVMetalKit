#include <metal_stdlib>
#include "SwizzleMTLSceneTypes.h"

using namespace metal;




//	returns the normalized values of the channels from the passed src buffer/info at the passed location
//	doesn't convert any colors- only converts ints to floats, at most
float4 NormChannelValsAtLoc(constant void * srcBuffer, constant SwizzleShaderInfo * info, uint2 loc);

//	populates the passed array of 'normRGB' values from the passed 'srcBuffer', using 'info' (which describes the nature of 'srcBuffer')
void PopulateNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderInfo & info, uint2 gid);
//	same as above, but there's a size mismatch between the src and dst images and we need to do some resampling!
void PopulateAndResampleNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderInfo & info, uint2 gid);
//	populates the passed array of 'normRGB' values from the passed texture, using 'info' (which describes the nature of 'srcTexture')
void PopulateAndResampleNormRGBFromSrcTex(thread float4 * normRGB, texture2d<float,access::sample> inTex, constant SwizzleShaderInfo & info, uint2 gid);

//	populates the passed dst buffer using the contents of the passed normalized RGB values
void PopulateDstFromNormRGB(device void * dstBuffer, constant SwizzleShaderInfo & info, thread float4 * normRGB, uint2 gid);




kernel void SwizzleMTLSceneFunc(
	constant void * srcBuffer [[ buffer(SwizzleShaderArg_SrcBuffer) ]],
	texture2d<float,access::sample> srcRGBTexture [[ texture(SwizzleShaderArg_SrcRGBTexture) ]],
	device void * dstBuffer [[ buffer(SwizzleShaderArg_DstBuffer) ]],
	texture2d<float,access::write> dstRGBTexture [[ texture(SwizzleShaderArg_DstRGBTexture) ]],
	constant SwizzleShaderInfo & info [[ buffer(SwizzleShaderArg_Info) ]],
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
		PopulateAndResampleNormRGBFromSrcTex(normRGB, srcRGBTexture, info, gid);
	}
	//	else we're not reading from a src texture- we're reading from a src buffer...
	else	{
		//	if the dst and src image sizes differ...
		if (info.dstImg.res[0] != info.srcImg.res[0] || info.dstImg.res[1] != info.srcImg.res[1])	{
			//	use a different function to calculate the normalized RGB vals- we'll do this part last, once we get everything else working!
			PopulateAndResampleNormRGBFromSrcBuffer(normRGB, srcBuffer, info, gid);
		}
		//	else the dst and src images have the same size...
		else	{
			//	populate the normalized RGB vals from the src buffer
			PopulateNormRGBFromSrcBuffer(normRGB, srcBuffer, info, gid);
		}
	}
	
	//	if there's a destination RGB texture attached, write the pixels to it now
	if (!is_null_texture(dstRGBTexture))	{
		for (unsigned int pixelIndex = 0; pixelIndex < info.dstPixelsToProcess; ++pixelIndex)	{
			uint2			dstLoc = uint2( (gid.x * info.dstPixelsToProcess) + pixelIndex, gid.y);
			dstRGBTexture.write(normRGB[pixelIndex], dstLoc);
		}
	}
	
	//	if there's a dst buffer, populate it from the RGB values!
	if (dstBuffer != nullptr)	{
		PopulateDstFromNormRGB(dstBuffer, info, normRGB, gid);
	}
	
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
			size_t		cbOffsetInBytes;
			size_t		crOffsetInBytes;
			if (loc.x % 2 == 0)	{
				cbOffsetInBytes = (loc.y * imgInfo.bytesPerRow) + ((loc.x) * bytesPerPixel);
				crOffsetInBytes = (loc.y * imgInfo.bytesPerRow) + ((loc.x + 1) * bytesPerPixel);
			}
			else	{
				cbOffsetInBytes = (loc.y * imgInfo.bytesPerRow) + ((loc.x - 1) * bytesPerPixel);
				crOffsetInBytes = (loc.y * imgInfo.bytesPerRow) + ((loc.x) * bytesPerPixel);
			}
			constant uint8_t		*rPtr = nullptr;
			rPtr = (constant uint8_t *)srcBuffer + (cbOffsetInBytes/sizeof(uint8_t));
			returnMe[0] = float(*rPtr) / 255.;
			returnMe[1] = float(*(rPtr+1)) / 255.;
			
			rPtr = (constant uint8_t *)srcBuffer + (crOffsetInBytes/sizeof(uint8_t));
			returnMe[2] = float(*(rPtr+1)) / 255.;
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_10:
		{
		}
		break;
	case SwizzlePF_UYVY_PKPL_422_UI_16:
		{
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_8:
		{
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		{
		}
		break;
	}
	
	return returnMe;
}

void PopulateNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderInfo & info, uint2 gid)	{
	//	if we're in this method, we know for a fact that the images in the src and dst buffers have the same resolution
	switch (info.srcImg.pf)	{
	case SwizzlePF_Unknown:
		{
			for (unsigned int pixelIndex = 0; pixelIndex < info.dstPixelsToProcess; ++pixelIndex)	{
				normRGB[pixelIndex] = float4(0,1,0,1);
			}
		}
		break;
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBX_PK_UI_8:
	case SwizzlePF_RGBA_PK_FP_32:
		{
			//	for each of the pixels we need to process in the dst image...
			for (unsigned int pixelIndex = 0; pixelIndex < info.dstPixelsToProcess; ++pixelIndex)	{
				//	calculate the location of the pixel we're processing in the dst image, get its value
				uint2			dstLoc = uint2( (gid.x * info.dstPixelsToProcess) + pixelIndex, gid.y);
				//	get the normalized channel values at that location
				float4			rawVals = NormChannelValsAtLoc(srcBuffer, info.srcImg, dstLoc);
				
				//	in this case, the src image is RGB- we already have the normalized RGB vals, so we're basically done!
				normRGB[pixelIndex] = rawVals.rgba;
				
				//	if it's a RGBX pixel format, set the alpha to 1!
				if (info.srcImg.pf == SwizzlePF_RGBX_PK_UI_8)
					normRGB[pixelIndex].a = 1.0;
			}
		}
		break;
	case SwizzlePF_BGRA_PK_UI_8:
	case SwizzlePF_BGRX_PK_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			for (unsigned int pixelIndex = 0; pixelIndex < info.dstPixelsToProcess; ++pixelIndex)	{
				//	calculate the location of the pixel we're processing in the dst image, get its value
				uint2			dstLoc = uint2( (gid.x * info.dstPixelsToProcess) + pixelIndex, gid.y);
				//	get the normalized channel values at that location
				float4			rawVals = NormChannelValsAtLoc(srcBuffer, info.srcImg, dstLoc);
				
				//	note: the image data in the src buffer is BGRA!
				
				//	image data is:			B	G	R	A
				//	code to access above:	R	G	B	A
				normRGB[pixelIndex] = rawVals.bgra;
				
				//	if it's a BGRX pixel format, set the alpha to 1!
				if (info.srcImg.pf == SwizzlePF_BGRX_PK_UI_8)
					normRGB[pixelIndex].a = 1.0;
			}
		}
		break;
	case SwizzlePF_ARGB_PK_UI_8:
		{
			//	for each of the pixels we need to process in the dst image...
			for (unsigned int pixelIndex = 0; pixelIndex < info.dstPixelsToProcess; ++pixelIndex)	{
				//	calculate the location of the pixel we're processing in the dst image, get its value
				uint2			dstLoc = uint2( (gid.x * info.dstPixelsToProcess) + pixelIndex, gid.y);
				//	get the normalized channel values at that location
				float4			rawVals = NormChannelValsAtLoc(srcBuffer, info.srcImg, dstLoc);
				
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
			for (unsigned int pixelIndex = 0; pixelIndex < info.dstPixelsToProcess; ++pixelIndex)	{
				//	calculate the location of the pixel we're processing in the dst image, get its value
				uint2			dstLoc = uint2( (gid.x * info.dstPixelsToProcess) + pixelIndex, gid.y);
				//	get the normalized channel values at that location
				float4			rawVals = NormChannelValsAtLoc(srcBuffer, info.srcImg, dstLoc);
				
				//	in this case, the src img is YCbCr.  NormChannelValsAtLoc() has unpacked the buffer and provided us with all three vals, we just have to convert them to RGB.
				
				//	rec709
				const float3x3		mat = float3x3(
					float3(1.164, 1.164, 1.164),
					float3(0.0, -0.213, 2.112),
					float3(1.793, -0.533, 0.0)
				);
				const float3		offsets = float3(16./255., 128./255., 128./255.);
				
				//normRGB[pixelIndex].rgb = mat * (rawVals.gbr - offsets);
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
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_8:
		{
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		{
		}
		break;
	}
}

void PopulateAndResampleNormRGBFromSrcBuffer(thread float4 * normRGB, constant void * srcBuffer, constant SwizzleShaderInfo & info, uint2 gid)	{
	//	INCOMPLETE- let's get the basic pixel format conversions finished before we take this on, hmm?
	for (int i=0; i<MAX_PIXELS_TO_PROCESS; ++i)	{
		normRGB[i] = float4(1,0,0,1);	//	just make everything red for now...
	}
	/*
	switch (info.srcImg.pf)	{
	case SwizzlePF_RGBA_PK_UI_8:
		{
			for (int pixelIndex = 0; pixelIndex < info.dstPixelsToProcess; ++pixelIndex)	{
				uint2			dstLoc = uint2( (gid.x * info.dstPixelsToProcess) + pixelIndex, gid.y);
				float2			normDstLoc = float2( float(dstLoc.y)/float(info.dstImg.res[0]), float(dstLoc.y)/float(info.dstImg.res[1]) );
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
void PopulateAndResampleNormRGBFromSrcTex(thread float4 * normRGB, texture2d<float,access::sample> inTex, constant SwizzleShaderInfo & info, uint2 gid)	{
	constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::normalized);
	for (unsigned int pixelIndex = 0; pixelIndex < info.dstPixelsToProcess; ++pixelIndex)	{
		uint2			dstLoc = uint2( (gid.x * info.dstPixelsToProcess) + pixelIndex, gid.y);
		float2			normDstLoc = float2( float(dstLoc.y)/float(info.dstImg.res[0]), float(dstLoc.y)/float(info.dstImg.res[1]) );
		float4			srcColor = inTex.sample(sampler, normDstLoc);
		normRGB[pixelIndex] = srcColor;
	}
}

void PopulateDstFromNormRGB(device void * dstBuffer, constant SwizzleShaderInfo & info, thread float4 * normRGB, uint2 gid)	{
	switch (info.dstImg.pf)	{
	case SwizzlePF_Unknown:
		return;
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBX_PK_UI_8:
		{
			//float4		normCodeVals[MAX_PIXELS_TO_PROCESS];
			//char4		codeVals[MAX_PIXELS_TO_PROCESS];
			
			size_t		bytesPerPixel = 8 * 4 / 8;	//	8 bits per channel, 4 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * info.dstImg.bytesPerRow) + (gid.x * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (offsetInBytes/sizeof(uint8_t));
			
			//for (int pixelIndex = 0; pixelIndex < info.dstPixelsToProcess; ++pixelIndex)	{
				//normCodeVals[pixelIndex] = normRGB[pixelIndex];
				//uint2			dstLoc = uint2( (gid.x * info.dstPixelsToProcess) + pixelIndex, gid.y);
				
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
			size_t		offsetInBytes = (gid.y * info.dstImg.bytesPerRow) + (gid.x * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (offsetInBytes/sizeof(uint8_t));
			
			//for (int pixelIndex = 0; pixelIndex < info.dstPixelsToProcess; ++pixelIndex)	{
				//normCodeVals[pixelIndex] = normRGB[pixelIndex];
				//uint2			dstLoc = uint2( (gid.x * info.dstPixelsToProcess) + pixelIndex, gid.y);
				
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
			size_t		offsetInBytes = (gid.y * info.dstImg.bytesPerRow) + (gid.x * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (offsetInBytes/sizeof(uint8_t));
			
			//for (int pixelIndex = 0; pixelIndex < info.dstPixelsToProcess; ++pixelIndex)	{
				//normCodeVals[pixelIndex] = normRGB[pixelIndex];
				//uint2			dstLoc = uint2( (gid.x * info.dstPixelsToProcess) + pixelIndex, gid.y);
				
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
			size_t		offsetInBytes = (gid.y * info.dstImg.bytesPerRow) + (gid.x * bytesPerPixel);
			device float		*wPtr = (device float *)dstBuffer + (offsetInBytes/sizeof(float));
			
			//for (int pixelIndex = 0; pixelIndex < info.dstPixelsToProcess; ++pixelIndex)	{
				//normCodeVals[pixelIndex] = normRGB[pixelIndex];
				//uint2			dstLoc = uint2( (gid.x * info.dstPixelsToProcess) + pixelIndex, gid.y);
				
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
			char4		dstVals[MAX_PIXELS_TO_PROCESS];
			
			//	rec709
			const float3x3		mat = float3x3(
				float3(0.183, -0.101, 0.439),
				float3(0.614, -0.339, -0.399),
				float3(0.062, 0.439, -0.040)
			);
			const float3		offsets = float3(128./255., 16./255., 128./255.);
			
			for (unsigned int pixelIndex = 0; pixelIndex < info.dstPixelsToProcess; ++pixelIndex)	{
				//	convert RGB to normalized YCbCr
				float4		normDstVal;
				normDstVal.rgb = mat * (normRGB[pixelIndex].rgb - offsets);
				normDstVal.a = normRGB[pixelIndex].a;
				//	convert normalized YCbCr to the code point vals we'll want to (combine and) write (8-bit vals in this case)
				dstVals[pixelIndex] = char4(round(normDstVal * 255.));
				//	note: we're calcating Y + Cb + Cr for each pixel (at this point we're still 444) 
			}
			
			//	figure out the base address at which we need to start writing pixels
			size_t		bytesPerPixel = 8 * 2 / 8;	//	8 bits per channel, 2 channels per pixel, 8 bits per byte
			size_t		offsetInBytes = (gid.y * info.dstImg.bytesPerRow) + (gid.x * bytesPerPixel);
			device uint8_t		*wPtr = (device uint8_t *)dstBuffer + (offsetInBytes/sizeof(uint8_t));
			
			//	(combine and) write the pixels (this is where we go from 444 to 422)
			*(wPtr + 0) = dstVals[0].x;	//	Y from the first pixel
			*(wPtr + 1) = (dstVals[0].y + dstVals[1].y) / 2;	//	Cb, adds chroma subsampling
			*(wPtr + 2) = dstVals[1].x;	//	Y from the second pixel
			*(wPtr + 3) = (dstVals[0].z + dstVals[1].z) / 2;	//	Cr, adds chroma subsampling
		}
		break;
	case SwizzlePF_UYVY_PK_422_UI_10:
		{
		}
		break;
	case SwizzlePF_UYVY_PKPL_422_UI_16:
		{
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_8:
		{
		}
		break;
	case SwizzlePF_UYVA_PKPL_422_UI_16:
		{
		}
		break;
	}
}



