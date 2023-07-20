//
//  VVMTLUtilities.m
//  VVMetalKit
//
//  Created by testadmin on 7/5/23.
//

#import "VVMTLUtilities.h"
#import <Accelerate/Accelerate.h>
#import "RenderProperties.h"
#import "VVMTLTextureImageDescriptor.h"
#import "VVMTLTextureImage.h"
#import "VVMTLPool.h"
#import "CopierMTLScene.h"




CGImageRef CreateCGImageRefFromMTLTexture(id<MTLTexture> inMTLTex)	{
	if (inMTLTex == nil)
		return nil;
	
	id<VVMTLTextureImage>		texToSample = [VVMTLPool.global textureForExistingTexture:inMTLTex];
	//	if the storage mode is currently sent to private, we need to copy the texture to a texture that is CPU-accessible
	if (inMTLTex.storageMode == MTLStorageModePrivate)	{
		NSLog(@"ERR: passed texture cannot be accessed by GPU, %s",__func__);
		//	we want the copy we make to have the same pixel format and stuff, it just needs to be buffer-backed
		VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
			createWithWidth:inMTLTex.width
			height:inMTLTex.height
			pixelFormat:inMTLTex.pixelFormat
			storage:MTLStorageModeManaged
			usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
		desc.mtlBufferBacking = YES;
		
		id<VVMTLTextureImage>		bufferBackedTex = [VVMTLPool.global textureForDescriptor:desc];
		
		CopierMTLScene		*copier = [[CopierMTLScene alloc] initWithDevice:RenderProperties.global.device];
		id<MTLCommandBuffer>		cmdBuffer = [RenderProperties.global.bgCmdQueue commandBuffer];
		[copier
			copyImg:texToSample
			toImg:bufferBackedTex
			allowScaling:NO
			sizingMode:SizingModeCopy
			inCommandBuffer:cmdBuffer];
		//id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		//[blitEncoder synchronizeResource:bufferBackedTex.buffer.buffer];
		//[blitEncoder endEncoding];
		[cmdBuffer commit];
		[cmdBuffer waitUntilCompleted];
		
		texToSample = bufferBackedTex;
	}
	VVMTLTextureImageDescriptor		*texDesc = (VVMTLTextureImageDescriptor*)texToSample.descriptor;
	
	CGImageRef		returnMe = NULL;
	
	NSUInteger		texBytesPerRow = 8 * 4 * texDesc.width / 8;
	NSUInteger		texBytesLength = texBytesPerRow * texDesc.height;
	MTLRegion		texRegion = MTLRegionMake2D(0, 0, texDesc.width, texDesc.height);
	void			*texBytes = NULL;
	
	//CGColorSpaceRef		colorspace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
	//CGColorSpaceRef		colorspace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	//CGColorSpaceRef		colorspace = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
	CGColorSpaceRef		colorspace = RenderProperties.global.colorSpace;
	
	size_t			rgbaBytesPerRow = 8 * 4 * texDesc.width / 8;
	size_t			rgbaBytesLength = rgbaBytesPerRow * texDesc.height;
	CFMutableDataRef		rgbaDataRef = NULL;
	CGDataProviderRef		rgbaDataProvider = NULL;
	void			*rgbaBytes = NULL;
	
	switch (texDesc.pfmt)	{
	case MTLPixelFormatBGRA8Unorm:
	case MTLPixelFormatBGRA8Unorm_sRGB:
		{
			texBytes = malloc(texBytesLength);
			
			[texToSample.texture getBytes:texBytes bytesPerRow:texBytesPerRow fromRegion:texRegion mipmapLevel:0];
			
			rgbaDataRef = CFDataCreateMutable(kCFAllocatorDefault, 0);
			CFDataSetLength(rgbaDataRef, rgbaBytesLength);
			rgbaBytes = CFDataGetMutableBytePtr(rgbaDataRef);
			rgbaDataProvider = CGDataProviderCreateWithCFData(rgbaDataRef);
			
			//	use VImage to remap the channels (BGRA to RGBA)
			vImage_Buffer		texBuffer;
			texBuffer.data = texBytes;
			texBuffer.width = texDesc.width;
			texBuffer.height = texDesc.height;
			texBuffer.rowBytes = texBytesPerRow;
			vImage_Buffer		rgbaBuffer;
			rgbaBuffer.data = rgbaBytes;
			rgbaBuffer.width = texDesc.width;
			rgbaBuffer.height = texDesc.height;
			rgbaBuffer.rowBytes = rgbaBytesPerRow;
			uint8_t			channelRemap[] = { 2, 1, 0, 3 };
			vImagePermuteChannels_ARGB8888(&texBuffer, &rgbaBuffer, channelRemap, 0);
			
			returnMe = CGImageCreate(
				texDesc.width,
				texDesc.height,
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
	case MTLPixelFormatRGBA8Unorm:
	case MTLPixelFormatRGBA8Unorm_sRGB:
		{
			rgbaDataRef = CFDataCreateMutable(kCFAllocatorDefault, 0);
			CFDataSetLength(rgbaDataRef, rgbaBytesLength);
			rgbaBytes = CFDataGetMutableBytePtr(rgbaDataRef);
			
			[texToSample.texture getBytes:rgbaBytes bytesPerRow:rgbaBytesPerRow fromRegion:texRegion mipmapLevel:0];
			
			rgbaDataProvider = CGDataProviderCreateWithCFData(rgbaDataRef);
			
			returnMe = CGImageCreate(
				texDesc.width,
				texDesc.height,
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
			texBytesPerRow = 16 * 4 * texDesc.width / 8;
			texBytesLength = texBytesPerRow * texDesc.height;
			texBytes = malloc(texBytesLength);
			
			[texToSample.texture getBytes:texBytes bytesPerRow:texBytesPerRow fromRegion:texRegion mipmapLevel:0];
			
			//	make the (8-bit, unsigned int) RGBA buffer we'll be making the CGImageRef out of
			rgbaDataRef = CFDataCreateMutable(kCFAllocatorDefault, 0);
			CFDataSetLength(rgbaDataRef, rgbaBytesLength);
			rgbaBytes = CFDataGetMutableBytePtr(rgbaDataRef);
			
			//	copy the 16-bit data to the 8-bit data buffer, converting the data as we do so
			uint16_t		*rPtr = (uint16_t*)texBytes;
			uint8_t			*wPtr = (uint8_t*)rgbaBytes;
			for (int i=0; i<texDesc.width * 4 * texDesc.height; ++i)	{
				*wPtr = round( ((double)(*rPtr)) / ((double)(0xFFFF)) * 255.0 );
				++rPtr;
				++wPtr;
			}
			
			rgbaDataProvider = CGDataProviderCreateWithCFData(rgbaDataRef);
			
			returnMe = CGImageCreate(
				texDesc.width,
				texDesc.height,
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
			rgbaBytesPerRow = 32 * 4 * texDesc.width / 8;
			rgbaBytesLength = rgbaBytesPerRow * texDesc.height;
			
			rgbaDataRef = CFDataCreateMutable(kCFAllocatorDefault, 0);
			CFDataSetLength(rgbaDataRef, rgbaBytesLength);
			rgbaBytes = CFDataGetMutableBytePtr(rgbaDataRef);
			
			[texToSample.texture getBytes:rgbaBytes bytesPerRow:rgbaBytesPerRow fromRegion:texRegion mipmapLevel:0];
			
			rgbaDataProvider = CGDataProviderCreateWithCFData(rgbaDataRef);
			
			returnMe = CGImageCreate(
				texDesc.width,
				texDesc.height,
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
			rgbaBytesPerRow = 16 * 4 * texDesc.width / 8;
			rgbaBytesLength = rgbaBytesPerRow * texDesc.height;
			
			rgbaDataRef = CFDataCreateMutable(kCFAllocatorDefault, 0);
			CFDataSetLength(rgbaDataRef, rgbaBytesLength);
			rgbaBytes = CFDataGetMutableBytePtr(rgbaDataRef);
			
			[texToSample.texture getBytes:rgbaBytes bytesPerRow:rgbaBytesPerRow fromRegion:texRegion mipmapLevel:0];
			
			rgbaDataProvider = CGDataProviderCreateWithCFData(rgbaDataRef);
			
			returnMe = CGImageCreate(
				texDesc.width,
				texDesc.height,
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
		NSLog(@"ERR: unhandled pixel format (%@) in %s", NSStringFromOSType((OSType)texDesc.pfmt), __func__);
		break;
	
	
	default:
		NSLog(@"ERR: unhandled pixel format B (%@) in %s", NSStringFromOSType((OSType)texDesc.pfmt), __func__);
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


CGImageRef CreateCGImageRefFromResizedMTLTexture(id<MTLTexture> inMTLTex, NSSize imgSize)	{
	NSSize			texSize = NSMakeSize(inMTLTex.width, inMTLTex.height);
	//	if the texture size we were passed matches the size of the passed texture, we can just call the parent function and bail
	if (NSEqualSizes(imgSize, texSize))	{
		return CreateCGImageRefFromMTLTexture(inMTLTex);
	}
	
	//	...if we're here, we need to resize the passed texture- so make a buffer-backed texture, copy the src texture to it, and then call the parent function
	
	id<VVMTLTextureImage>		inTex = [VVMTLPool.global textureForExistingTexture:inMTLTex];
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:texSize.width
		height:texSize.height
		pixelFormat:inMTLTex.pixelFormat
		storage:MTLStorageModeManaged
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
	desc.mtlBufferBacking = YES;
	
	id<VVMTLTextureImage>		bufferBackedTex = [VVMTLPool.global textureForDescriptor:desc];
	
	CopierMTLScene		*copier = [[CopierMTLScene alloc] initWithDevice:RenderProperties.global.device];
	id<MTLCommandBuffer>		cmdBuffer = [RenderProperties.global.bgCmdQueue commandBuffer];
	[copier
		copyImg:inTex
		toImg:bufferBackedTex
		allowScaling:NO
		sizingMode:SizingModeFit
		inCommandBuffer:cmdBuffer];
	//id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
	//[blitEncoder synchronizeResource:bufferBackedTex.buffer.buffer];
	//[blitEncoder endEncoding];
	[cmdBuffer commit];
	[cmdBuffer waitUntilCompleted];
	
	CGImageRef		returnMe = CreateCGImageRefFromMTLTexture(bufferBackedTex.texture);
	
	bufferBackedTex = nil;
	inTex = nil;
	copier = nil;
	
	return returnMe;
}


NSString * NSStringFromOSType(OSType n)	{
	return [NSString stringWithFormat:@"%c%c%c%c", (int)((n>>24)&0xFF), (int)((n>>16)&0xFF), (int)((n>>8)&0xFF), (int)((n>>0)&0xFF)];
}


NSString * NSStringFromMTLPixelFormat(MTLPixelFormat n)	{
	switch (n)	{
	case MTLPixelFormatInvalid:			return @"Invalid";
	case MTLPixelFormatBGRA8Unorm:		return @"BGRA8";
	case MTLPixelFormatBGRA8Unorm_sRGB:	return @"BGRA8s";
	case MTLPixelFormatRGBA8Unorm:		return @"RGBA8";
	case MTLPixelFormatRGBA8Unorm_sRGB:	return @"RGBA8s";
	case MTLPixelFormatR8Unorm:			return @"R8";
	case MTLPixelFormatR8Unorm_sRGB:	return @"R8s";
	case MTLPixelFormatRG8Unorm:		return @"RG8";
	case MTLPixelFormatRG8Unorm_sRGB:	return @"RG8s";
	case MTLPixelFormatGBGR422:			return @"GBGR8";
	case MTLPixelFormatBGRG422:			return @"BGRG8";
	case MTLPixelFormatRGB10A2Uint:		return @"RGB10A2UI";
	case MTLPixelFormatRGB10A2Unorm:	return @"RGB10A2";
	case MTLPixelFormatRGBA16Uint:		return @"RGBA16UI";
	case MTLPixelFormatRGBA16Float:		return @"RGBA16F";
	case MTLPixelFormatRGBA32Float:		return @"RGBA32F";
	case MTLPixelFormatBC1_RGBA:		return @"BC1";
	case MTLPixelFormatBC3_RGBA:		return @"BC3";
	case MTLPixelFormatBC4_RUnorm:		return @"BC4";
	case MTLPixelFormatBC6H_RGBUfloat:	return @"BC6UF";
	case MTLPixelFormatBC6H_RGBFloat:	return @"BC6F";
	case MTLPixelFormatBC7_RGBAUnorm:	return @"BC7";
	default:							return @"???";
	}
	return @"???";
}





@implementation NSImage (NSImageVVMTLUtilities)

+ (NSImage *) createFromMTLTexture:(id<MTLTexture>)n	{
	if (n == nil)
		return nil;
	CGImageRef		tmpImg = CreateCGImageRefFromMTLTexture(n);
	NSImage			*returnMe = [[NSImage alloc] initWithCGImage:tmpImg size:NSMakeSize(CGImageGetWidth(tmpImg), CGImageGetHeight(tmpImg))];
	CGImageRelease(tmpImg);
	return returnMe;
}

+ (NSImage *) createFromMTLTexture:(id<MTLTexture>)n sized:(NSSize)inSize	{
	if (n == nil)
		return nil;
	CGImageRef		tmpImg = CreateCGImageRefFromResizedMTLTexture(n, inSize);
	NSImage			*returnMe = [[NSImage alloc] initWithCGImage:tmpImg size:inSize];
	CGImageRelease(tmpImg);
	return returnMe;
}

@end



