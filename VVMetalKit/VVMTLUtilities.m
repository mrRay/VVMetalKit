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
		NSLog(@"ERR: passed texture cannot be accessed by GPU, %s",__func__);
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


id<VVMTLTextureImage> CreateTextureFromCGImage(CGImageRef inImg)	{
	NSSize			rawSize = (inImg==NULL) ? NSZeroSize : NSMakeSize(CGImageGetWidth(inImg), CGImageGetHeight(inImg));
	return CreateTextureFromResizedCGImage(inImg, rawSize);
}
id<VVMTLTextureImage> CreateTextureFromResizedCGImage(CGImageRef inImg, NSSize targetSize)	{
	//NSLog(@"%s ... %@, %@",__func__,inImg,NSStringFromSize(targetSize));
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(targetSize));
	NSSize			rawSize = (inImg==NULL) ? NSZeroSize : NSMakeSize(CGImageGetWidth(inImg), CGImageGetHeight(inImg));
	//NSLog(@"\t\trawSize is %@",NSStringFromSize(rawSize));
	
	BOOL				directUploadOK = YES;
	CGBitmapInfo		newImgInfo = CGImageGetBitmapInfo(inImg);
	CGImageAlphaInfo	calculatedAlphaInfo = newImgInfo & kCGBitmapAlphaInfoMask;
	CGImageByteOrderInfo	calculatedByteOrderInfo = newImgInfo & kCGBitmapByteOrderMask;
	CGImagePixelFormatInfo	calculatedPxlFmtInfo = CGImageGetPixelFormatInfo(inImg);
	size_t				bytesPerRow = CGImageGetBytesPerRow(inImg);
	
	
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
	//NSLog(@"\t\tpixel format is %@",StringFromPxlFmt(calculatedPxlFmtInfo));
	NSLog(@"\t\tbyte order is %@",StringFromByteOrder(calculatedByteOrderInfo));
	NSLog(@"\t\talpha info is %@",StringFromAlphaInfo(calculatedAlphaInfo));
	*/
	
	
	
	//	the "default" byte order (kCGImageByteOrderDefault) is per-platform, and thus is alwasy big-endian on macOS
	//	however, m1s- and intel machines- are little-endian!
	
	if (A_HAS_B(newImgInfo, kCGBitmapFloatComponents))	{
		directUploadOK = NO;
	}
	
	if (calculatedPxlFmtInfo != kCGImagePixelFormatPacked)	{
		directUploadOK = NO;
	}
	
	//	we can use some big-endian formats directly if we dump their data into BGRA textures (instead of RGBA)
	BOOL		uploadAsBGRA = NO;
	BOOL		remapBeforeUpload = NO;
	uint8_t		remapPatterns[3][4] = {
		{ 0, 1, 2, 3 }, //	RGBX -> RGBX
		{ 3, 2, 1, 0 },	//	XBGR -> RGBX
		{ 1, 2, 3, 0 }	//	XRGB -> RGBX
	};
	uint8_t		remapPatternIdx = 0;
	
	switch (calculatedByteOrderInfo)	{
    case kCGImageByteOrderMask:
    	break;
    case kCGImageByteOrder16Little:
    case kCGImageByteOrder16Big:
    	directUploadOK = NO;
    	break;
    case kCGImageByteOrder32Little:
    	{
    		switch (calculatedAlphaInfo)	{
			case kCGImageAlphaNone:
			case kCGImageAlphaPremultipliedLast:	//	RGBA -> ABGR
			case kCGImageAlphaLast:	//	RGBA -> ABGR
			case kCGImageAlphaNoneSkipLast:	//	RGBX -> XBGR
				remapBeforeUpload = YES;
				remapPatternIdx = 1;
				break;
			case kCGImageAlphaOnly:	//	A
				directUploadOK = NO;
				break;
			case kCGImageAlphaPremultipliedFirst:	//	ARGB -> BGRA
			case kCGImageAlphaFirst:	//	ARGB -> BGRA
			case kCGImageAlphaNoneSkipFirst:	//	XRGB -> BGRX
				uploadAsBGRA = YES;
				break;
    		}
    	}
    	break;
    case kCGImageByteOrder32Big:
    case kCGImageByteOrderDefault:
    	{
    		switch (calculatedAlphaInfo)	{
			case kCGImageAlphaNone:
			case kCGImageAlphaPremultipliedFirst:	//	ARGB
			case kCGImageAlphaFirst:	//	ARGB
			case kCGImageAlphaNoneSkipFirst:	//	XRGB
				remapBeforeUpload = YES;
				remapPatternIdx = 2;
				break;
			case kCGImageAlphaOnly:	//	A
				directUploadOK = NO;
				break;
			case kCGImageAlphaPremultipliedLast:	//	RGBA
			case kCGImageAlphaLast:	//	RGBA
			case kCGImageAlphaNoneSkipLast:	//	RGBX
				//	intentionally blank, can be uploaded directly as RGBA
				break;
    		}
    	}
    	break;
	}
	
	if (!NSEqualSizes(targetSize,rawSize))	{
		directUploadOK = NO;
	}
	
	
	if (bytesPerRow % 16 != 0 && directUploadOK)	{
		remapBeforeUpload = YES;
		//	don't set the remapPatternIdx here- it defaults to 0, which is what we want if it's just RGBX with a funky bytesPerRow, but if it's not 0 then we've already set the relevant remapPatternIdx and don't want to overwrite it...
	}
	
	//	if the direct upload is OK, just copy the data right out of the image and upload it
	if (directUploadOK)	{
		//NSLog(@"direct upload!");
		NSData		*frameData = (__bridge_transfer NSData *)CGDataProviderCopyData(CGImageGetDataProvider(inImg));
		if (frameData == nil)	{
			return nil;
		}
		
		//	if we have to remap before upload, we're allocating a buffer-backed texture and using the Accelerate framework to remap the channels (on the CPU) before uploading it to a texture
		if (remapBeforeUpload)	{
			//NSLog(@"remapping using index %d",remapPatternIdx);
			uint32_t		wBytesPerRow = sizeof(uint8_t) * 4 * targetSize.width;
			if (wBytesPerRow % 16 != 0)	{
				wBytesPerRow += (16 - (wBytesPerRow % 16));
			}
			
			id<VVMTLTextureImage>		returnMe = [VVMTLPool.global
				bufferBackedTexSized:rawSize
				pixelFormat:MTLPixelFormatRGBA8Unorm
				bytesPerRow:wBytesPerRow];
			void		*wPtr = [returnMe.buffer.buffer contents];
			
			vImage_Buffer		rImg;
			rImg.data = (void*)frameData.bytes;
			rImg.width = targetSize.width;
			rImg.height = targetSize.height;
			rImg.rowBytes = bytesPerRow;
			
			vImage_Buffer		wImg;
			wImg.data = wPtr;
			wImg.width = targetSize.width;
			wImg.height = targetSize.height;
			wImg.rowBytes = returnMe.bytesPerRow;
			
			vImagePermuteChannels_ARGB8888(&rImg, &wImg, remapPatterns[remapPatternIdx], 0);
			
			id<MTLCommandBuffer>		cmdBuffer = [RenderProperties.global.bgCmdQueue commandBuffer];
			id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
			[blitEncoder synchronizeResource:returnMe.buffer.buffer];
			[blitEncoder endEncoding];
			[cmdBuffer commit];
			[cmdBuffer waitUntilCompleted];
			[VVMTLPool.global timestampThis:returnMe];
			return returnMe;
			
			
		}
		else	{
			void		*basePtr = (void *)frameData.bytes;
			id<VVMTLTextureImage>		newFrameImgBuffer = nil;
			if ((uint64_t)basePtr % 4096 == 0)	{
				newFrameImgBuffer = [VVMTLPool.global
					bufferBackedTexSized:rawSize
					pixelFormat:(uploadAsBGRA) ? MTLPixelFormatBGRA8Unorm : MTLPixelFormatRGBA8Unorm
					basePtr:basePtr
					bytesPerRow:(uint32_t)bytesPerRow
					bufferDeallocator:^(void *pointer, NSUInteger length)	{
						NSData		*tmpData = frameData;
						tmpData = nil;
					}];
				frameData = nil;
			}
			else	{
				newFrameImgBuffer = [VVMTLPool.global
					bufferBackedTexSized:rawSize
					pixelFormat:(uploadAsBGRA) ? MTLPixelFormatBGRA8Unorm : MTLPixelFormatRGBA8Unorm
					basePtr:basePtr
					bytesPerRow:(uint32_t)bytesPerRow];
				frameData = nil;
			}
			//NSLog(@"newFrameImgBuffer is %@",newFrameImgBuffer);
			
			return newFrameImgBuffer;
		}
		
	}
	//	else the direct upload isn't OK- i have to draw the image into a context which is backing a texture
	else	{
		//NSLog(@"redraw!");
		//	allocate a buffer-backed texture of the appropriate dimensions
		size_t			bytesPerRow = sizeof(uint8_t) * 4 * targetSize.width;
		bytesPerRow = ROUNDUPTOMULTOF16(bytesPerRow);
		id<VVMTLTextureImage>		returnMe = [VVMTLPool.global
			bufferBackedTexSized:targetSize
			pixelFormat:(uploadAsBGRA) ? MTLPixelFormatBGRA8Unorm : MTLPixelFormatRGBA8Unorm
			bytesPerRow:(uint32_t)bytesPerRow];
		//	make a CGBitmapContext backed by the same buffer that backs our texture
		void			*bufferDataPtr = returnMe.buffer.buffer.contents;
		CGContextRef	ctx = CGBitmapContextCreate(
			bufferDataPtr,
			(long)targetSize.width,
			(long)targetSize.height,
			8,
			bytesPerRow,
			RenderProperties.global.colorSpace,
			kCGImageAlphaPremultipliedLast);
		if (ctx == NULL)	{
			NSLog(@"\t\tERR: ctx null in %s",__func__);
			return nil;
		}
		//	draw the image in the bitmap context, flush it
		CGContextDrawImage(ctx, CGRectMake(0,0,targetSize.width,targetSize.height), inImg);
		CGContextFlush(ctx);
		
		//	the bitmap context we just drew into has premultiplied alpha, so we need to un-premultiply before uploading it
		//CGBitmapContextUnpremultiply(ctx);		//	commented out b/c it's a big perf hit!
		
		CGContextRelease(ctx);
		//	make a blit encoder, synchronize the resource
		id<MTLCommandBuffer>		cmdBuffer = [RenderProperties.global.bgCmdQueue commandBuffer];
		id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		[blitEncoder synchronizeResource:returnMe.buffer.buffer];
		[blitEncoder endEncoding];
		[cmdBuffer commit];
		[cmdBuffer waitUntilCompleted];
		[VVMTLPool.global timestampThis:returnMe];
		return returnMe;
	}
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
		bytesPerRow = size.width * 32 * 4 / 8;
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
		//	intentionally blank, not handled
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
	
	case MTLPixelFormatRGBA32Float:
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







