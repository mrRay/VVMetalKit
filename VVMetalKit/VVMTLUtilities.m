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




#define A_HAS_B(a,b) (((a)&(b))==(b))

#define DXT_BLOCK_SIZE 4
#define ROUNDUPTOMULTOF16(n) (((n%16)==0) ? (n) : (n + (16-(n%16))))
#define ROUNDAUPTOMULTOFB(A,B) ((((A)%(B))==0) ? (A) : ((A) + ((B)-((A)%(B)))))




void CGBitmapContextUnpremultiply(CGContextRef ctx)	{
	NSSize				actualSize = NSMakeSize(CGBitmapContextGetWidth(ctx), CGBitmapContextGetHeight(ctx));
	unsigned long		bytesPerRow = CGBitmapContextGetBytesPerRow(ctx);
	unsigned char		*bitmapData = (unsigned char *)CGBitmapContextGetData(ctx);
	unsigned char		*pixelPtr = nil;
	double				colors[4];
	if (bitmapData==nil || bytesPerRow<=0 || actualSize.width<1 || actualSize.height<1)
		return;
	for (int y=0; y<actualSize.height; ++y)	{
		pixelPtr = bitmapData + (y * bytesPerRow);
		for (int x=0; x<actualSize.width; ++x)	{
			//	convert unsigned chars to normalized doubles
			for (int i=0; i<4; ++i)
				colors[i] = ((double)*(pixelPtr+i))/255.;
			//	unpremultiply if there's an alpha and it won't cause a divide-by-zero
			if (colors[3]>0. && colors[3]<1.)	{
				for (int i=0; i<3; ++i)
					colors[i] = colors[i] / colors[3];
			}
			//	convert the normalized components back into unsigned chars
			for (int i=0; i<4; ++i)
				*(pixelPtr+i) = (unsigned char)(colors[i]*255.);
			
			//	don't forget to increment the pixel ptr!
			pixelPtr += 4;
		}
	}
}


CGImageRef CreateCGImageRefFromVVMTLTextureImage(id<VVMTLTextureImage> inImg)	{
	//	if the image occupies the whole texture, just call the function that downloads the whole texture
	NSSize			rawImgSize = inImg.srcRect.size;
	if (NSEqualSizes(rawImgSize, inImg.size))	{
		return CreateCGImageRefFromMTLTexture(inImg.texture);
	}
	
	//	...if we're here, then the image we want to create a CGImageRef of doesn't occupy the whole texture- so copy it to a new texture that it will occupy fully...
	
	id<VVMTLTextureImage>		tmpTex = [VVMTLPool.global bgra8IOSurfaceBackedTexSized:rawImgSize];
	
	CopierMTLScene		*copier = [[CopierMTLScene alloc] initWithDevice:RenderProperties.global.device];
	id<MTLCommandBuffer>		cmdBuffer = [RenderProperties.global.bgCmdQueue commandBuffer];
	[copier
		copyImg:inImg
		toImg:tmpTex
		allowScaling:NO
		sizingMode:SizingModeCopy
		inCommandBuffer:cmdBuffer];
	[cmdBuffer commit];
	[cmdBuffer waitUntilCompleted];
	
	CGImageRef			returnMe = CreateCGImageRefFromMTLTexture(tmpTex.texture);
	copier = nil;
	tmpTex = nil;
	return returnMe;
}
CGImageRef CreateCGImageRefFromResizedVVMTLTextureImage(id<VVMTLTextureImage> inImg, NSSize imgSize)	{
	//	if the image occupies the whole texture, just call the function that downloads the whole texture
	NSSize			rawImgSize = inImg.srcRect.size;
	if (NSEqualSizes(rawImgSize, imgSize))	{
		return CreateCGImageRefFromMTLTexture(inImg.texture);
	}
	
	//	...if we're here, then the image we want to create a CGImageRef of doesn't occupy the whole texture- so copy it to a new texture that it will occupy fully...
	
	id<VVMTLTextureImage>		tmpTex = [VVMTLPool.global bgra8IOSurfaceBackedTexSized:imgSize];
	
	CopierMTLScene		*copier = [[CopierMTLScene alloc] initWithDevice:RenderProperties.global.device];
	id<MTLCommandBuffer>		cmdBuffer = [RenderProperties.global.bgCmdQueue commandBuffer];
	[copier
		copyImg:inImg
		toImg:tmpTex
		allowScaling:YES
		sizingMode:SizingModeFit
		inCommandBuffer:cmdBuffer];
	[cmdBuffer commit];
	[cmdBuffer waitUntilCompleted];
	
	CGImageRef			returnMe = CreateCGImageRefFromMTLTexture(tmpTex.texture);
	copier = nil;
	tmpTex = nil;
	return returnMe;
}


CGImageRef CreateCGImageRefFromMTLTexture(id<MTLTexture> inMTLTex)	{
	if (inMTLTex == nil)
		return nil;
	
	id<VVMTLTextureImage>		texToSample = [VVMTLPool.global textureForExistingTexture:inMTLTex];
	//	if the storage mode is currently sent to private, we need to copy the texture to a texture that is CPU-accessible
	if (inMTLTex.storageMode == MTLStorageModePrivate)	{
		NSLog(@"ERR: passed texture cannot be accessed by CPU, %s",__func__);
		//	we want the copy we make to have the same pixel format and stuff, it just needs to be buffer-backed
		VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
			createWithWidth:inMTLTex.width
			height:inMTLTex.height
			pixelFormat:inMTLTex.pixelFormat
			storage:MTLStorageModeManaged
			usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
			bytesPerRow:0];
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
        
		id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		[blitEncoder synchronizeResource:bufferBackedTex.buffer.buffer];
		[blitEncoder endEncoding];
		
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
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:0];
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
	
	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
	[blitEncoder synchronizeResource:bufferBackedTex.buffer.buffer];
	[blitEncoder endEncoding];
	
	[cmdBuffer commit];
	[cmdBuffer waitUntilCompleted];
	
	CGImageRef		returnMe = CreateCGImageRefFromMTLTexture(bufferBackedTex.texture);
	
	bufferBackedTex = nil;
	inTex = nil;
	copier = nil;
	
	return returnMe;
}


id<VVMTLTextureImage> CreateTextureFromCGImage(CGImageRef inImg)	{
	NSSize			rawSize = (inImg==NULL) ? NSZeroSize : NSMakeSize(CGImageGetWidth(inImg), CGImageGetHeight(inImg));
	return CreateTextureFromResizedCGImage(inImg, rawSize);
}
id<VVMTLTextureImage> CreateTextureFromResizedCGImage(CGImageRef inImg, NSSize targetSize)	{
	//NSLog(@"%s ... %@, %@",__func__,inImg,NSStringFromSize(targetSize));
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(targetSize));
	if (inImg == NULL)
		return nil;
	
	CGBitmapInfo		calculatedImgInfo = CGImageGetBitmapInfo(inImg);
	CGImageAlphaInfo		calculatedAlphaInfo = calculatedImgInfo & kCGBitmapAlphaInfoMask;
	CGImageByteOrderInfo		calculatedByteOrderInfo = calculatedImgInfo & kCGBitmapByteOrderMask;
	CGImagePixelFormatInfo		calculatedPxlFmtInfo = CGImageGetPixelFormatInfo(inImg);
	/*
	NSString * (^StringFromByteOrder)(CGImageByteOrderInfo) = ^(CGImageByteOrderInfo inInfo)	{
		switch (inInfo)	{
		case kCGImageByteOrderMask:			return @"kCGImageByteOrderMask";
		case kCGImageByteOrderDefault:		return @"kCGImageByteOrderDefault";
		case kCGImageByteOrder16Little:		return @"kCGImageByteOrder16Little";
		case kCGImageByteOrder32Little:		return @"kCGImageByteOrder32Little";
		case kCGImageByteOrder16Big:		return @"kCGImageByteOrder16Big";
		case kCGImageByteOrder32Big:		return @"kCGImageByteOrder32Big";
		}
		return @"Unknown CGImageByteOrderInfo";
	};
	NSString * (^StringFromPxlFmt)(CGImagePixelFormatInfo) = ^(CGImagePixelFormatInfo inInfo)	{
		switch (inInfo)	{
		case kCGImagePixelFormatMask:		return @"kCGImagePixelFormatMask";
		case kCGImagePixelFormatPacked:		return @"kCGImagePixelFormatPacked";
		case kCGImagePixelFormatRGB555:		return @"kCGImagePixelFormatRGB555";
		case kCGImagePixelFormatRGB565:		return @"kCGImagePixelFormatRGB565";
		case kCGImagePixelFormatRGB101010:		return @"kCGImagePixelFormatRGB101010";
		case kCGImagePixelFormatRGBCIF10:		return @"kCGImagePixelFormatRGBCIF10";
		}
		return @"Unknown CGImagePixelFormatInfo";
	};
	NSString * (^StringFromAlphaInfo)(CGImageAlphaInfo) = ^(CGImageAlphaInfo inInfo)	{
		switch (inInfo)	{
		case kCGImageAlphaNone:			return @"kCGImageAlphaNone";
		case kCGImageAlphaPremultipliedLast:	return @"kCGImageAlphaPremultipliedLast";
		case kCGImageAlphaPremultipliedFirst:	return @"kCGImageAlphaPremultipliedFirst";
		case kCGImageAlphaLast:			return @"kCGImageAlphaLast";
		case kCGImageAlphaFirst:		return @"kCGImageAlphaFirst";
		case kCGImageAlphaNoneSkipLast:			return @"kCGImageAlphaNoneSkipLast";
		case kCGImageAlphaNoneSkipFirst:		return @"kCGImageAlphaNoneSkipFirst";
		case kCGImageAlphaOnly:			return @"kCGImageAlphaOnly";
		}
		return @"Unknown CGImageAlphaInfo";
	};
	NSLog(@"\t\tpixel format is %@",StringFromPxlFmt(calculatedPxlFmtInfo));
	NSLog(@"\t\tbyte order is %@",StringFromByteOrder(calculatedByteOrderInfo));
	NSLog(@"\t\talpha info is %@",StringFromAlphaInfo(calculatedAlphaInfo));
	*/
	
	
	
	NSSize		rawSize = NSMakeSize(CGImageGetWidth(inImg), CGImageGetHeight(inImg));
	//NSLog(@"\t\trawSize is %@",NSStringFromSize(rawSize));
	
	BOOL		directUploadOK = YES;	//	if YES, the data is okay to upload directly to a texture
	MTLPixelFormat		dstPxlFmt = MTLPixelFormatRGBA8Unorm;
	
	BOOL		remapBeforeUpload = NO;	//	only used if 'directUploadOK' is YES- if this is also YES then the data has to be remapped to be interpreted correctly
	uint8_t		remapPatterns[3][4] = {
		{ 0, 1, 2, 3 }, //	RGBX -> RGBX
		{ 3, 2, 1, 0 },	//	XBGR -> RGBX
		{ 1, 2, 3, 0 }	//	XRGB -> RGBX
	};
	uint8_t		remapPatternIdx = 0;
	
	
	//	let's rule out 'direct upload' for a couple obvious cases right away: floating-point images, images that aren't packed (planar), and RGB images (no corresponding texture type!)
	if (A_HAS_B(calculatedImgInfo, kCGBitmapFloatComponents))	{
		directUploadOK = NO;
	}
	if (calculatedPxlFmtInfo != kCGImagePixelFormatPacked)	{
		directUploadOK = NO;
	}
	if (calculatedAlphaInfo == kCGImageAlphaNone)	{
		directUploadOK = NO;
	}
	
	
	//	determine the bytes per row of the memory backing the CGImage
	uint32_t		imgDataBytesPerRow = (uint32_t)CGImageGetBytesPerRow(inImg);
	//	calculate the bytes per row of image data- this is basically the "minimum bytes per row", with no padding.  if we need to copy image data, this is the amount per row we need to copy.
	uint32_t		imgBytesPerRow = rawSize.width * (1 * 4);
	switch (calculatedAlphaInfo)	{
		case kCGImageAlphaPremultipliedLast:
		case kCGImageAlphaLast:
		case kCGImageAlphaNoneSkipLast:
		case kCGImageAlphaPremultipliedFirst:
		case kCGImageAlphaFirst:
		case kCGImageAlphaNoneSkipFirst:
			break;
		case kCGImageAlphaNone:					//	RGB
			imgBytesPerRow = rawSize.width * (1 * 3);
			break;
		case kCGImageAlphaOnly:					//	A (UL as R8)
			imgBytesPerRow = rawSize.width;
			break;
	}
	
	//	take a closer look at the image's properties, figure out if it's still okay upload directly, what kind of texture it needs to upload to, whether or not its channels need to be remapped, etc...
	if (directUploadOK)	{
		switch (calculatedByteOrderInfo)	{
			case kCGImageByteOrderMask:
			case kCGImageByteOrder16Little:
			case kCGImageByteOrder16Big:
				directUploadOK = NO;
				break;
			case kCGImageByteOrder32Little:	{
				
				switch (calculatedAlphaInfo)	{
					case kCGImageAlphaNone:					//	RGB (never encountered, we check for kCGImageAlphaNone earlier)
						directUploadOK = NO;
						break;
					case kCGImageAlphaPremultipliedLast:	//	RGBA -> remap to ABGR (UL as RGBA)
					case kCGImageAlphaLast:					//	RGBA -> remap to ABGR (UL as RGBA)
					case kCGImageAlphaNoneSkipLast:			//	RGBX -> remap to XBGR (UL as RGBA)
						dstPxlFmt = MTLPixelFormatRGBA8Unorm;
						remapBeforeUpload = YES;
						remapPatternIdx = 1;
						break;
					case kCGImageAlphaOnly:					//	A (UL as R8)
						dstPxlFmt = MTLPixelFormatR8Unorm;
						break;
					case kCGImageAlphaPremultipliedFirst:	//	ARGB (UL as BGRA)
					case kCGImageAlphaFirst:				//	ARGB (UL as BGRA)
					case kCGImageAlphaNoneSkipFirst:		//	XRGB (UL as BGRA)
						dstPxlFmt = MTLPixelFormatBGRA8Unorm;
						break;
				}
				
				break;
			}
			case kCGImageByteOrderDefault:
			case kCGImageByteOrder32Big:	{
				
				switch (calculatedAlphaInfo)	{
					case kCGImageAlphaNone:					//	RGB (never encountered, we check for kCGImageAlphaNone earlier)
						directUploadOK = NO;
						break;
					case kCGImageAlphaPremultipliedLast:	//	RGBA (UL as RGBA)
					case kCGImageAlphaLast:					//	RGBA (UL as RGBA)
					case kCGImageAlphaNoneSkipLast:			//	RGBX (UL as RGBA)
						dstPxlFmt = MTLPixelFormatRGBA8Unorm;
						break;
					case kCGImageAlphaOnly:					//	A (UL as R8)
						dstPxlFmt = MTLPixelFormatR8Unorm;
						break;
					case kCGImageAlphaPremultipliedFirst:	//	ARGB (UL as BGRA)
					case kCGImageAlphaFirst:				//	ARGB (UL as BGRA)
					case kCGImageAlphaNoneSkipFirst:		//	XRGB (UL as BGRA)
						dstPxlFmt = MTLPixelFormatBGRA8Unorm;
						break;
				}
				
				break;
			}
		}
	}
	
	
	if (directUploadOK)	{
		NSUInteger		linearAlignment = [RenderProperties.global.device minimumLinearTextureAlignmentForPixelFormat:dstPxlFmt];
		uint32_t		bufferBytesPerRow = (uint32_t)ROUNDAUPTOMULTOFB(imgBytesPerRow,linearAlignment);
		
		//if (imgBytesPerRow != bufferBytesPerRow)	{
		//	remapBeforeUpload = YES;
		//	remapPatternIdx = 0;
		//}
		
		NSData		*frameData = (__bridge_transfer NSData *)CGDataProviderCopyData(CGImageGetDataProvider(inImg));
		if (frameData == nil)	{
			return nil;
		}
		
		void		*basePtr = (void *)frameData.bytes;
		
		//	if we have to remap before upload...
		if (remapBeforeUpload)	{
			id<VVMTLTextureImage>		returnMe = [VVMTLPool.global
				bufferBackedTexSized:rawSize
				pixelFormat:dstPxlFmt
				bytesPerRow:bufferBytesPerRow];
			
			size_t		totalBytesToWrite = bufferBytesPerRow * rawSize.height;
			void		*wPtr = [returnMe.buffer.buffer contents];
			
			vImage_Buffer		rImg;
			rImg.data = basePtr;
			rImg.width = rawSize.width;
			rImg.height = rawSize.height;
			rImg.rowBytes = imgDataBytesPerRow;
			
			vImage_Buffer		wImg;
			wImg.data = wPtr;
			wImg.width = rawSize.width;
			wImg.height = rawSize.height;
			wImg.rowBytes = bufferBytesPerRow;
			
			vImagePermuteChannels_ARGB8888(&rImg, &wImg, remapPatterns[remapPatternIdx], 0);
			
			[returnMe.buffer.buffer didModifyRange:NSMakeRange(0,totalBytesToWrite)];
			
			[VVMTLPool.global timestampThis:returnMe];
			return returnMe;
		}
		//	else if the img's bytes per row doesn't match the buffer's bytes per row (we don't have to check this during remap because the remap API lets us take this into account)
		else if (imgDataBytesPerRow != bufferBytesPerRow)	{
			#define DIRECT_UPLOAD_TEX 0
#if DIRECT_UPLOAD_TEX==1
			NSLog(@"****");
			VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
				createWithWidth:rawSize.width
				height:rawSize.height
				pixelFormat:dstPxlFmt
				storage:MTLStorageModeManaged
				usage:MTLTextureUsageShaderRead
				bytesPerRow:0];
			desc.mtlBufferBacking = NO;
			desc.iosfcBacking = NO;
			desc.cvpbBacking = NO;
			id<VVMTLTextureImage>		returnMe = [VVMTLPool.global textureForDescriptor:desc];
			[returnMe.texture
				replaceRegion:MTLRegionMake2D(0,0,rawSize.width,rawSize.height)
				mipmapLevel:0
				withBytes:basePtr
				bytesPerRow:imgDataBytesPerRow];
			
			id<MTLCommandBuffer>		cmdBuffer = [RenderProperties.global.bgCmdQueue commandBuffer];
			
			id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
			[blitEncoder synchronizeResource:returnMe.texture];
			[blitEncoder endEncoding];
			
			[cmdBuffer commit];
			[cmdBuffer waitUntilCompleted];
			
			[VVMTLPool.global timestampThis:returnMe];
			return returnMe;
#else
			id<VVMTLTextureImage>		returnMe = [VVMTLPool.global
				bufferBackedTexSized:rawSize
				pixelFormat:dstPxlFmt
				bytesPerRow:bufferBytesPerRow];
			
			size_t		totalBytesToWrite = bufferBytesPerRow * rawSize.height;
			uint8_t		*wPtr = (uint8_t*)[returnMe.buffer.buffer contents];
			uint8_t		*rPtr = (uint8_t*)basePtr;
			
			for (int i=0; i<rawSize.height; ++i)	{
				memcpy(wPtr, rPtr, imgBytesPerRow);
				wPtr += bufferBytesPerRow;
				rPtr += imgDataBytesPerRow;
			}
			
			[returnMe.buffer.buffer didModifyRange:NSMakeRange(0,totalBytesToWrite)];
			
			[VVMTLPool.global timestampThis:returnMe];
			return returnMe;
#endif
			
		}
		//	else we can just blast the pixel data pretty much directly to the texture
		else	{
			id<VVMTLTextureImage>		returnMe = [VVMTLPool.global
				bufferBackedTexSized:rawSize
				pixelFormat:dstPxlFmt
				basePtr:basePtr
				bytesPerRow:imgDataBytesPerRow
				bufferDeallocator:^(void *pointer, NSUInteger length)	{
					NSData * tmpData = frameData;
					tmpData = nil;
				}];
			frameData = nil;
			return returnMe;
		}
	}
	
	//	...if we're here, the 'direct upload' approach is NOT okay: we need to draw the CGImageRef into a bitmap backed by a texture we own and control
	
	dstPxlFmt = MTLPixelFormatRGBA8Unorm;
	
	NSUInteger		linearAlignment = [RenderProperties.global.device minimumLinearTextureAlignmentForPixelFormat:dstPxlFmt];
	size_t		bufferBytesPerRow = targetSize.width * (1 * 4);
	bufferBytesPerRow = ROUNDAUPTOMULTOFB(bufferBytesPerRow,linearAlignment);
	size_t		totalBytesToWrite = bufferBytesPerRow * targetSize.height;
	
	id<VVMTLTextureImage>		returnMe = [VVMTLPool.global
		bufferBackedTexSized:targetSize
		pixelFormat:dstPxlFmt
		bytesPerRow:(uint32_t)bufferBytesPerRow];
	
	//	make a CGContextRef that will use our buffer/texture as its backing
	CGContextRef		ctx = CGBitmapContextCreate(
		(void*)returnMe.buffer.buffer.contents,
		(long)targetSize.width,
		(long)targetSize.height,
		0,
		bufferBytesPerRow,
		RenderProperties.global.colorSpace,
		kCGImageAlphaPremultipliedLast);
	if (ctx == NULL)	{
		NSLog(@"ERR: ctx NULL in %s",__func__);
		return nil;
	}
	
	//	draw the image in the bitmap context, flush it
	CGContextDrawImage(ctx, CGRectMake(0,0,targetSize.width,targetSize.height), inImg);
	CGContextFlush(ctx);
	
	//	the bitmap context we just drew into has premultiplied alpha, so we need to un-premultiply before uploading it
	//CGBitmapContextUnpremultiply(ctx);		//	commented out b/c it's a big perf hit!
	
	CGContextRelease(ctx);
	
	[returnMe.buffer.buffer didModifyRange:NSMakeRange(0,totalBytesToWrite)];
	[VVMTLPool.global timestampThis:returnMe];
	
	return nil;
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
	case MTLPixelFormatDepth32Float:	return @"Depth32";
	case MTLPixelFormatDepth32Float_Stencil8:		return @"D32S8";
	default:							return @"???";
	}
	return @"???";
}


vector_float4 Vec4FromNSColor(NSColor * inColor)	{
	vector_float4		returnMe = simd_make_float4(1., 1., 1., 1.);
	if (inColor != nil)	{
		CGFloat				tmpCGFloats[8];
		[inColor getComponents:tmpCGFloats];
		NSInteger			numOfComponents = inColor.numberOfComponents;
		for (NSInteger i=0; i<numOfComponents; ++i)	{
			switch (i)	{
			case 0:		returnMe.r = tmpCGFloats[i];		break;
			case 1:		returnMe.g = tmpCGFloats[i];		break;
			case 2:		returnMe.b = tmpCGFloats[i];		break;
			case 3:		returnMe.a = tmpCGFloats[i];		break;
			}
		}
		//	if there were < 4 components, write a '1' to any unused channels
		for (NSInteger i=numOfComponents; i<4; ++i)	{
			switch (i)	{
			case 0:		returnMe.r = 1.0;		break;
			case 1:		returnMe.g = 1.0;		break;
			case 2:		returnMe.b = 1.0;		break;
			case 3:		returnMe.a = 1.0;		break;
			}
		}
	}
	return returnMe;
}


BOOL IsMTLPixelFormatFloatingPoint(MTLPixelFormat inPfmt)	{
	switch (inPfmt)	{
	case MTLPixelFormatBC6H_RGBFloat:
	case MTLPixelFormatBC6H_RGBUfloat:
	case MTLPixelFormatRGBA32Float:
	case MTLPixelFormatDepth32Float:
	case MTLPixelFormatDepth32Float_Stencil8:
		return YES;
	default:
		return NO;
	}
	return NO;
}
BOOL IsMTLPixelFormatCompressed(MTLPixelFormat n)	{
	switch (n)	{
		case MTLPixelFormatBC1_RGBA:
		case MTLPixelFormatBC1_RGBA_sRGB:
		case MTLPixelFormatBC2_RGBA:
		case MTLPixelFormatBC2_RGBA_sRGB:
		case MTLPixelFormatBC3_RGBA:
		case MTLPixelFormatBC3_RGBA_sRGB:
		case MTLPixelFormatBC4_RUnorm:
		case MTLPixelFormatBC4_RSnorm:
		case MTLPixelFormatBC5_RGUnorm:
		case MTLPixelFormatBC5_RGSnorm:
		case MTLPixelFormatBC6H_RGBFloat:
		case MTLPixelFormatBC6H_RGBUfloat:
		case MTLPixelFormatBC7_RGBAUnorm:
		case MTLPixelFormatBC7_RGBAUnorm_sRGB:
		case MTLPixelFormatPVRTC_RGB_2BPP:
		case MTLPixelFormatPVRTC_RGB_2BPP_sRGB:
		case MTLPixelFormatPVRTC_RGB_4BPP:
		case MTLPixelFormatPVRTC_RGB_4BPP_sRGB:
		case MTLPixelFormatPVRTC_RGBA_2BPP:
		case MTLPixelFormatPVRTC_RGBA_2BPP_sRGB:
		case MTLPixelFormatPVRTC_RGBA_4BPP:
		case MTLPixelFormatPVRTC_RGBA_4BPP_sRGB:
		case MTLPixelFormatEAC_R11Unorm:
		case MTLPixelFormatEAC_R11Snorm:
		case MTLPixelFormatEAC_RG11Unorm:
		case MTLPixelFormatEAC_RG11Snorm:
		case MTLPixelFormatEAC_RGBA8:
		case MTLPixelFormatEAC_RGBA8_sRGB:
		case MTLPixelFormatETC2_RGB8:
		case MTLPixelFormatETC2_RGB8_sRGB:
		case MTLPixelFormatETC2_RGB8A1:
		case MTLPixelFormatETC2_RGB8A1_sRGB:
		case MTLPixelFormatASTC_4x4_sRGB:
		case MTLPixelFormatASTC_5x4_sRGB:
		case MTLPixelFormatASTC_5x5_sRGB:
		case MTLPixelFormatASTC_6x5_sRGB:
		case MTLPixelFormatASTC_6x6_sRGB:
		case MTLPixelFormatASTC_8x5_sRGB:
		case MTLPixelFormatASTC_8x6_sRGB:
		case MTLPixelFormatASTC_8x8_sRGB:
		case MTLPixelFormatASTC_10x5_sRGB:
		case MTLPixelFormatASTC_10x6_sRGB:
		case MTLPixelFormatASTC_10x8_sRGB:
		case MTLPixelFormatASTC_10x10_sRGB:
		case MTLPixelFormatASTC_12x10_sRGB:
		case MTLPixelFormatASTC_12x12_sRGB:
		case MTLPixelFormatASTC_4x4_LDR:
		case MTLPixelFormatASTC_5x4_LDR:
		case MTLPixelFormatASTC_5x5_LDR:
		case MTLPixelFormatASTC_6x5_LDR:
		case MTLPixelFormatASTC_6x6_LDR:
		case MTLPixelFormatASTC_8x5_LDR:
		case MTLPixelFormatASTC_8x6_LDR:
		case MTLPixelFormatASTC_8x8_LDR:
		case MTLPixelFormatASTC_10x5_LDR:
		case MTLPixelFormatASTC_10x6_LDR:
		case MTLPixelFormatASTC_10x8_LDR:
		case MTLPixelFormatASTC_10x10_LDR:
		case MTLPixelFormatASTC_12x10_LDR:
		case MTLPixelFormatASTC_12x12_LDR:
		case MTLPixelFormatASTC_4x4_HDR:
		case MTLPixelFormatASTC_5x4_HDR:
		case MTLPixelFormatASTC_5x5_HDR:
		case MTLPixelFormatASTC_6x5_HDR:
		case MTLPixelFormatASTC_6x6_HDR:
		case MTLPixelFormatASTC_8x5_HDR:
		case MTLPixelFormatASTC_8x6_HDR:
		case MTLPixelFormatASTC_8x8_HDR:
		case MTLPixelFormatASTC_10x5_HDR:
		case MTLPixelFormatASTC_10x6_HDR:
		case MTLPixelFormatASTC_10x8_HDR:
		case MTLPixelFormatASTC_10x10_HDR:
		case MTLPixelFormatASTC_12x10_HDR:
		case MTLPixelFormatASTC_12x12_HDR:
			return YES;
		default:
			return NO;
	}
	return NO;
}


size_t BytesPerRowFromMTLPixelFormatAndSize(MTLPixelFormat inPfmt, NSSize * inoutSize)	{
	size_t			bytesPerRow = 0;
	NSSize			size = *inoutSize;
	switch (inPfmt)	{
	case MTLPixelFormatR8Unorm:
	case MTLPixelFormatR8Unorm_sRGB:
		bytesPerRow = size.width * 8 * 1 / 8;
		break;
	case MTLPixelFormatRG8Unorm:
	case MTLPixelFormatRG8Unorm_sRGB:
		bytesPerRow = size.width * 8 * 2 / 8;
		break;
	case MTLPixelFormatGBGR422:
	case MTLPixelFormatBGRG422:
		size.width = ROUNDAUPTOMULTOFB((int)round(size.width), 2);
		bytesPerRow = size.width * 8 * 2 / 8;
		break;
	case MTLPixelFormatBGRA8Unorm:
	case MTLPixelFormatBGRA8Unorm_sRGB:
	case MTLPixelFormatRGBA8Unorm:
	case MTLPixelFormatRGBA8Unorm_sRGB:
		bytesPerRow = size.width * 8 * 4 / 8;
		break;
	case MTLPixelFormatRGB10A2Uint:
	case MTLPixelFormatRGB10A2Unorm:
		bytesPerRow = size.width * 32 / 8;
		break;
	case MTLPixelFormatRGBA16Uint:
		bytesPerRow = size.width * 16 * 4 / 8;
		break;
	case MTLPixelFormatRGBA16Float:
		bytesPerRow = size.width * 16 * 4 / 8;
		break;
	case MTLPixelFormatRGBA32Float:
	case MTLPixelFormatDepth32Float:
		bytesPerRow = size.width * 32 * 4 / 8;
		break;
	case MTLPixelFormatDepth32Float_Stencil8:
		bytesPerRow = size.width * 40 * 4 / 8;
		break;
	case MTLPixelFormatBC1_RGBA:
		size.width = ROUNDAUPTOMULTOFB((int)round(size.width), DXT_BLOCK_SIZE);
		size.height = ROUNDAUPTOMULTOFB((int)round(size.height), DXT_BLOCK_SIZE);
		bytesPerRow = size.width / DXT_BLOCK_SIZE * 8;	//	two 16-bit color and one 32-bit descriptor per 4 x 4 block of pixels (DXT_BLOCK_SIZE is 4)
		break;
	case MTLPixelFormatBC3_RGBA:
		size.width = ROUNDAUPTOMULTOFB((int)round(size.width), DXT_BLOCK_SIZE);
		size.height = ROUNDAUPTOMULTOFB((int)round(size.height), DXT_BLOCK_SIZE);
		bytesPerRow = size.width / DXT_BLOCK_SIZE * 16;	//	BC1 for the color plus BC4 for the alpha!
		break;
	case MTLPixelFormatBC4_RUnorm:
		size.width = ROUNDAUPTOMULTOFB((int)round(size.width), DXT_BLOCK_SIZE);
		size.height = ROUNDAUPTOMULTOFB((int)round(size.height), DXT_BLOCK_SIZE);
		bytesPerRow = size.width / DXT_BLOCK_SIZE * 8;	//	8 bytes per 4x4 block- greyscale/alpha only!
		break;
	case MTLPixelFormatBC6H_RGBUfloat:
	case MTLPixelFormatBC6H_RGBFloat:
	case MTLPixelFormatBC7_RGBAUnorm:
		size.width = ROUNDAUPTOMULTOFB((int)round(size.width), DXT_BLOCK_SIZE);
		size.height = ROUNDAUPTOMULTOFB((int)round(size.height), DXT_BLOCK_SIZE);
		bytesPerRow = size.width / DXT_BLOCK_SIZE * 16;
		break;
	default:
		NSLog(@"******** ERR: %s, %ld %lx",__func__,(unsigned long)inPfmt,(unsigned long)inPfmt);
		break;
	}
	*inoutSize = size;
	return bytesPerRow;
}


MTLResourceOptions MTLResourceStorageModeForMTLStorageMode(MTLStorageMode inStorage)	{
	MTLResourceOptions		returnMe = MTLResourceStorageModePrivate;
	switch (inStorage)	{
	case MTLStorageModePrivate:
		returnMe = MTLResourceStorageModePrivate;
		break;
	case MTLStorageModeShared:
		returnMe = MTLResourceStorageModeShared;
		break;
	case MTLStorageModeManaged:
		returnMe = MTLResourceStorageModeManaged;
		break;
	case MTLStorageModeMemoryless:
		returnMe = MTLResourceStorageModeMemoryless;
		break;
	}
	return returnMe;
}

OSType BestGuessCVPixelFormatTypeForMTLPixelFormat(MTLPixelFormat inPF)	{
	OSType			cvPixelFormat = 0x00;
	switch (inPF)	{
	case MTLPixelFormatR8Unorm:	//	??
		cvPixelFormat = kCVPixelFormatType_OneComponent8;
		break;
	
	case MTLPixelFormatRG8Unorm:
		cvPixelFormat = kCVPixelFormatType_TwoComponent8;
		break;
	
	case MTLPixelFormatBGRG422:	//	BM stuff
		cvPixelFormat = kCVPixelFormatType_422YpCbCr8;
		break;
	case MTLPixelFormatGBGR422:	//	BM stuff
		cvPixelFormat = kCVPixelFormatType_422YpCbCr8_yuvs;
		//cvPixelFormat = kCVPixelFormatType_422YpCbCr8FullRange;
		break;
	case MTLPixelFormatRGBA8Unorm:
	case MTLPixelFormatRGBA8Unorm_sRGB:
		cvPixelFormat = kCVPixelFormatType_32RGBA;
		break;
	case MTLPixelFormatBGRA8Unorm:
	case MTLPixelFormatBGRA8Unorm_sRGB:
		cvPixelFormat = kCVPixelFormatType_32BGRA;
		break;
	
	case MTLPixelFormatRGBA16Float:
		cvPixelFormat = kCVPixelFormatType_64RGBAHalf;
		break;
	case MTLPixelFormatRGBA32Float:
	case MTLPixelFormatDepth32Float:
		cvPixelFormat = kCVPixelFormatType_128RGBAFloat;
		break;
	
	case MTLPixelFormatRGB10A2Uint:	//	BM stuff
		cvPixelFormat = kCVPixelFormatType_30RGB;
		break;
	case MTLPixelFormatRGB10A2Unorm:	//	not used?
		cvPixelFormat = kCVPixelFormatType_30RGB;
		break;
	
	case MTLPixelFormatRGBA16Uint:
		//	no corresponding CV pixel fmt?
		break;
		
	default:
		//	intentionally blank
		break;
	}
	return cvPixelFormat;
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







