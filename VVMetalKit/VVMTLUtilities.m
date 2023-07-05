//
//  VVMTLUtilities.m
//  VVMetalKit
//
//  Created by testadmin on 7/5/23.
//

#import "VVMTLUtilities.h"
#import <Accelerate/Accelerate.h>




CGImageRef CreateCGImageRefFromMTLTexture(id<MTLTexture> inTex)	{
	if (inTex == nil)
		return nil;
	
	CGImageRef		returnMe = NULL;
	
	NSUInteger		texBytesPerRow = 8 * 4 * inTex.width / 8;
	NSUInteger		texBytesLength = texBytesPerRow * inTex.height;
	MTLRegion		texRegion = MTLRegionMake2D(0, 0, inTex.width, inTex.height);
	void			*texBytes = NULL;
	
	//CGColorSpaceRef		colorspace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
	CGColorSpaceRef		colorspace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	//CGColorSpaceRef		colorspace = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
	
	size_t			rgbaBytesPerRow = 8 * 4 * inTex.width / 8;
	size_t			rgbaBytesLength = rgbaBytesPerRow * inTex.height;
	CFMutableDataRef		rgbaDataRef = NULL;
	CGDataProviderRef		rgbaDataProvider = NULL;
	void			*rgbaBytes = NULL;
	
	switch (inTex.pixelFormat)	{
	case MTLPixelFormatBGRA8Unorm:
	case MTLPixelFormatBGRA8Unorm_sRGB:
		{
			texBytes = malloc(texBytesLength);
			
			[inTex getBytes:rgbaBytes bytesPerRow:texBytesPerRow fromRegion:texRegion mipmapLevel:0];
			
			rgbaDataRef = CFDataCreateMutable(kCFAllocatorDefault, 0);
			CFDataSetLength(rgbaDataRef, rgbaBytesLength);
			rgbaBytes = CFDataGetMutableBytePtr(rgbaDataRef);
			rgbaDataProvider = CGDataProviderCreateWithCFData(rgbaDataRef);
			
			//	use VImage to remap the channels (BGRA to RGBA)
			vImage_Buffer		texBuffer;
			texBuffer.data = texBytes;
			texBuffer.width = inTex.width;
			texBuffer.height = inTex.height;
			texBuffer.rowBytes = texBytesPerRow;
			vImage_Buffer		rgbaBuffer;
			rgbaBuffer.data = rgbaBytes;
			rgbaBuffer.width = inTex.width;
			rgbaBuffer.height = inTex.height;
			rgbaBuffer.rowBytes = rgbaBytesPerRow;
			uint8_t			channelRemap[] = { 2, 1, 0, 3 };
			vImagePermuteChannels_ARGB8888(&texBuffer, &rgbaBuffer, channelRemap, 0);
			
			returnMe = CGImageCreate(
				inTex.width,
				inTex.height,
				8,
				32,
				rgbaBytesPerRow,
				colorspace,
				(CGBitmapInfo)kCGImageAlphaLast,
				rgbaDataProvider,
				NULL,
				YES,
				kCGRenderingIntentDefault);
			
			free(texBytes);
		}
		break;
	case MTLPixelFormatRGBA8Unorm:
	case MTLPixelFormatRGBA8Unorm_sRGB:
		{
			rgbaDataRef = CFDataCreateMutable(kCFAllocatorDefault, 0);
			CFDataSetLength(rgbaDataRef, rgbaBytesLength);
			rgbaBytes = CFDataGetMutableBytePtr(rgbaDataRef);
			
			[inTex getBytes:rgbaBytes bytesPerRow:rgbaBytesPerRow fromRegion:texRegion mipmapLevel:0];
			
			rgbaDataProvider = CGDataProviderCreateWithCFData(rgbaDataRef);
			
			returnMe = CGImageCreate(
				inTex.width,
				inTex.height,
				8,
				32,
				rgbaBytesPerRow,
				colorspace,
				(CGBitmapInfo)kCGImageAlphaLast,
				rgbaDataProvider,
				NULL,
				YES,
				kCGRenderingIntentDefault);
		}
		break;
	
	
	case MTLPixelFormatRGBA16Uint:
		{
			//	copy the (16-bit, unsigned int) texture to a CPU buffer with the raw values
			texBytesPerRow = 16 * 4 * inTex.width / 8;
			texBytesLength = texBytesPerRow * inTex.height;
			texBytes = malloc(texBytesLength);
			
			[inTex getBytes:texBytes bytesPerRow:texBytesPerRow fromRegion:texRegion mipmapLevel:0];
			
			//	make the (8-bit, unsigned int) RGBA buffer we'll be making the CGImageRef out of
			rgbaDataRef = CFDataCreateMutable(kCFAllocatorDefault, 0);
			CFDataSetLength(rgbaDataRef, rgbaBytesLength);
			rgbaBytes = CFDataGetMutableBytePtr(rgbaDataRef);
			
			//	copy the 16-bit data to the 8-bit data buffer, converting the data as we do so
			uint16_t		*rPtr = (uint16_t*)texBytes;
			uint8_t			*wPtr = (uint8_t*)rgbaBytes;
			for (int i=0; i<inTex.width * 4 * inTex.height; ++i)	{
				*wPtr = round( ((double)(*rPtr)) / ((double)(0xFFFF)) * 255.0 );
				++rPtr;
				++wPtr;
			}
			
			rgbaDataProvider = CGDataProviderCreateWithCFData(rgbaDataRef);
			
			returnMe = CGImageCreate(
				inTex.width,
				inTex.height,
				16,
				64,
				rgbaBytesPerRow,
				colorspace,
				(CGBitmapInfo)kCGImageAlphaLast,
				rgbaDataProvider,
				NULL,
				YES,
				kCGRenderingIntentDefault);
			
			free(texBytes);
		}
		break;
	
	
	case MTLPixelFormatRGBA32Float:
		{
			rgbaBytesPerRow = 32 * 4 * inTex.width / 8;
			rgbaBytesLength = rgbaBytesPerRow * inTex.height;
			
			rgbaDataRef = CFDataCreateMutable(kCFAllocatorDefault, 0);
			CFDataSetLength(rgbaDataRef, rgbaBytesLength);
			rgbaBytes = CFDataGetMutableBytePtr(rgbaDataRef);
			
			[inTex getBytes:rgbaBytes bytesPerRow:rgbaBytesPerRow fromRegion:texRegion mipmapLevel:0];
			
			rgbaDataProvider = CGDataProviderCreateWithCFData(rgbaDataRef);
			
			returnMe = CGImageCreate(
				inTex.width,
				inTex.height,
				32,
				128,
				rgbaBytesPerRow,
				colorspace,
				(CGBitmapInfo)(kCGImageAlphaLast | kCGBitmapFloatComponents | kCGBitmapByteOrder32Little),
				rgbaDataProvider,
				NULL,
				YES,
				kCGRenderingIntentDefault);
		}
		break;
	case MTLPixelFormatRGBA16Float:
		{
			rgbaBytesPerRow = 16 * 4 * inTex.width / 8;
			rgbaBytesLength = rgbaBytesPerRow * inTex.height;
			
			rgbaDataRef = CFDataCreateMutable(kCFAllocatorDefault, 0);
			CFDataSetLength(rgbaDataRef, rgbaBytesLength);
			rgbaBytes = CFDataGetMutableBytePtr(rgbaDataRef);
			
			[inTex getBytes:rgbaBytes bytesPerRow:rgbaBytesPerRow fromRegion:texRegion mipmapLevel:0];
			
			rgbaDataProvider = CGDataProviderCreateWithCFData(rgbaDataRef);
			
			returnMe = CGImageCreate(
				inTex.width,
				inTex.height,
				16,
				64,
				rgbaBytesPerRow,
				colorspace,
				(CGBitmapInfo)(kCGImageAlphaLast | kCGBitmapFloatComponents | kCGBitmapByteOrder16Little),
				rgbaDataProvider,
				NULL,
				YES,
				kCGRenderingIntentDefault);
		}
		break;
	
	
	case MTLPixelFormatRGB10A2Uint:
	case MTLPixelFormatRGB10A2Unorm:
	case MTLPixelFormatBGRG422:
	case MTLPixelFormatGBGR422:
	case MTLPixelFormatR8Unorm:
	case MTLPixelFormatR8Unorm_sRGB:
	case MTLPixelFormatRG8Unorm:
	case MTLPixelFormatRG8Unorm_sRGB:
		NSLog(@"ERR: unhandled pixel format (%@) in %s", NSStringFromOSType((OSType)inTex.pixelFormat), __func__);
		break;
	
	
	default:
		NSLog(@"ERR: unhandled pixel format B (%@) in %s", NSStringFromOSType((OSType)inTex.pixelFormat), __func__);
		break;
	}
	
	//	free the assets we allocated for this transformation
	if (texBytes != NULL)	{
		free(texBytes);
	}
	if (rgbaDataProvider != NULL)	{
		CGDataProviderRelease(rgbaDataProvider);
	}
	if (rgbaDataRef != NULL)	{
		CFRelease(rgbaDataRef);
	}
	if (colorspace != NULL)	{
		CGColorSpaceRelease(colorspace);
	}
	
	return returnMe;
}


NSString * NSStringFromOSType(OSType n)	{
	return [NSString stringWithFormat:@"%c%c%c%c", (int)((n>>24)&0xFF), (int)((n>>16)&0xFF), (int)((n>>8)&0xFF), (int)((n>>0)&0xFF)];
}

