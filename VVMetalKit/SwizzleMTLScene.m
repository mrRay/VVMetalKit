#import "SwizzleMTLScene.h"
#import "MTLPool.h"
//#import "MTLImgBufferShaderTypes.h"
#import "RenderProperties.h"
#import "SwizzleMTLSceneTypes.h"




NSString * NSStringFromSwizzlePF(SwizzlePF inPF)	{
	char		destCharPtr[5];
	destCharPtr[0] = (inPF>>24) & 0xFF;
	destCharPtr[1] = (inPF>>16) & 0xFF;
	destCharPtr[2] = (inPF>>8) & 0xFF;
	destCharPtr[3] = (inPF) & 0xFF;
	destCharPtr[4] = 0;
	return [NSString stringWithCString:destCharPtr encoding:NSASCIIStringEncoding];
}




@interface SwizzleMTLScene ()
@property (strong) MTLImgBuffer * inputImage;
@property (readwrite) SwizzlePF inputPF;
@property (readwrite) SwizzlePF outputPF;
@end




@implementation SwizzleMTLScene


#pragma mark - class methods


+ (BOOL) isMetalPF:(MTLPixelFormat)inMtlPF compatibleWithSwizzlePF:(SwizzlePF)inSwizzlePF	{
	switch (inSwizzlePF)	{
	case SwizzlePF_RGBA_UI_8:
	//case SwizzlePF_BGRA_UI_8:
		{
			static MTLPixelFormat		matches[] = {
				MTLPixelFormatRGBA8Unorm,
				MTLPixelFormatRGBA8Unorm_sRGB,
				
				MTLPixelFormatRGBA8Uint,
				
				MTLPixelFormatBGRA8Unorm,
				MTLPixelFormatBGRA8Unorm_sRGB
			};
			for (int i=0; i<sizeof(matches)/sizeof(MTLPixelFormat); ++i)	{
				if (inMtlPF == matches[i])
					return YES;
			}
		}
		break;
	case SwizzlePF_RGBA_FP_32:
		{
			static MTLPixelFormat		matches[] = {
				MTLPixelFormatRGBA32Float
			};
			for (int i=0; i<sizeof(matches)/sizeof(MTLPixelFormat); ++i)	{
				if (inMtlPF == matches[i])
					return YES;
			}
		}
		break;
	case SwizzlePF_UYVY_422_UI_8:
		{
			static MTLPixelFormat		matches[] = {
				MTLPixelFormatGBGR422,
				MTLPixelFormatBGRG422
			};
			for (int i=0; i<sizeof(matches)/sizeof(MTLPixelFormat); ++i)	{
				if (inMtlPF == matches[i])
					return YES;
			}
		}
		break;
	case SwizzlePF_UYVY_422_UI_10:
		{
			static MTLPixelFormat		matches[] = {
				MTLPixelFormatRGB10A2Unorm,
				
				MTLPixelFormatRGB10A2Uint,
			};
			for (int i=0; i<sizeof(matches)/sizeof(MTLPixelFormat); ++i)	{
				if (inMtlPF == matches[i])
					return YES;
			}
		}
		break;
	}
	
	return NO;
}
+ (MTLPixelFormat) metalPFForSwizzlePF:(SwizzlePF)pf	{
	switch (pf)	{
	case SwizzlePF_RGBA_UI_8:		return MTLPixelFormatRGBA8Unorm;
	//case SwizzlePF_BGRA_UI_8:		return MTLPixelFormatBGRA8Unorm;
	case SwizzlePF_RGBA_FP_32:		return MTLPixelFormatRGBA32Float;
	case SwizzlePF_UYVY_422_UI_8:	return MTLPixelFormatGBGR422;
	case SwizzlePF_UYVY_422_UI_10:	return MTLPixelFormatRGB10A2Unorm;
	}
	return MTLPixelFormatRGBA8Unorm;
}


#pragma mark - init/dealloc


- (nullable instancetype) initWithDevice:(id<MTLDevice>)n	{
	self = [super initWithDevice:n];
	if (self != nil)	{
		self.inputImage = nil;
		
		NSError				*nsErr = nil;
		NSBundle			*myBundle = [NSBundle bundleForClass:[self class]];
		id<MTLLibrary>		defaultLibrary = [self.device newDefaultLibraryWithBundle:myBundle error:&nsErr];
		id<MTLFunction>		func = [defaultLibrary newFunctionWithName:@"SwizzleMTLSceneFunc"];
		
		self.computePipelineStateObject = [self.device
			newComputePipelineStateWithFunction:func
			error:&nsErr];
		if (self.computePipelineStateObject == nil || nsErr != nil)
			NSLog(@"ERR: unable to make PSO, %@",nsErr);
	}
	return self;
}


#pragma mark - frontend methods


- (void) convertSrcImg:(MTLImgBuffer *)inSrcImg srcPixelFormat:(SwizzlePF)inSrcPF dstImg:(MTLImgBuffer *)inDstImg dstPixelFormat:(SwizzlePF)inDstPF inCommandBuffer:(id<MTLCommandBuffer>)inCB	{
	if (inSrcImg == nil || inDstImg == nil)	{
		NSLog(@"ERR: prereq not met, bailing, %s (%@, %@)",__func__,inSrcImg,inDstImg);
		return;
	}
	if (![SwizzleMTLScene isMetalPF:inDstImg.texture.pixelFormat compatibleWithSwizzlePF:inDstPF])	{
		NSLog(@"ERR: dst texture PF (%ld) doesn't match target PF (%@)",inDstImg.texture.pixelFormat,NSStringFromSwizzlePF(inDstPF));
		return;
	}
	if (![SwizzleMTLScene isMetalPF:inSrcImg.texture.pixelFormat compatibleWithSwizzlePF:inSrcPF])	{
		NSLog(@"ERR: src texture PF (%ld) doesn't match target PF (%@)",inSrcImg.texture.pixelFormat,NSStringFromSwizzlePF(inSrcPF));
		return;
	}
	
	//	synchronize around this instance, to guarantee that the call to render that populates the command buffer won't be interrupted
	@synchronized (self)	{
		self.inputImage = inSrcImg;
		self.inputPF = inSrcPF;
		self.outputPF = inDstPF;
		
		switch (inSrcPF)	{
		case SwizzlePF_RGBA_UI_8:
		//case SwizzlePF_BGRA_UI_8:
		case SwizzlePF_RGBA_FP_32:
		case SwizzlePF_UYVY_422_UI_8:
			{
				switch (inDstPF)	{
				case SwizzlePF_RGBA_UI_8:
				//case SwizzlePF_BGRA_UI_8:
				case SwizzlePF_RGBA_FP_32:
				case SwizzlePF_UYVY_422_UI_8:
					self.shaderEvalSize = MTLSizeMake(1,1,1);
					break;
				case SwizzlePF_UYVY_422_UI_10:
					//	each pass process a strip of 6 adjacent pixels in a horiz strip
					//	each pass produces 6 RGB color values, which are converted to 6 YCbCr color values
					//	because it's 422, we pack the 6 YCbCr color values into data provided by 4 RGB pixels
					self.shaderEvalSize = MTLSizeMake(6,1,1);
					break;
				}
			}
			break;
		case SwizzlePF_UYVY_422_UI_10:
			{
				switch (inDstPF)	{
				case SwizzlePF_RGBA_UI_8:
				//case SwizzlePF_BGRA_UI_8:
				case SwizzlePF_RGBA_FP_32:
				case SwizzlePF_UYVY_422_UI_8:
					//	each pass produces a strip of 4 adjacent pixels in a horiz strip
					//	each pass produces 4 rgb color values, which are unpacked into 6 YCbCr color values (422)
					self.shaderEvalSize = MTLSizeMake(4,1,1);
					break;
				case SwizzlePF_UYVY_422_UI_10:
					//	each pass process a strip of 6 adjacent pixels in a horiz strip
					//	each pass produces 6 RGB color values, which are converted to 6 YCbCr color values
					//	because it's 422, we pack the 6 YCbCr color values into data provided by 4 RGB pixels
					self.shaderEvalSize = MTLSizeMake(1,1,1);
					break;
				}
			}
			break;
		}
		
		[self renderToBuffer:inDstImg inCommandBuffer:inCB];
		
		self.inputImage = nil;
	}
}


- (void) renderCallback	{
	[self.computeEncoder setTexture:self.inputImage.texture atIndex:SwizzleShaderArg_SrcImg];
	[self.computeEncoder setTexture:self.renderTarget.texture atIndex:SwizzleShaderArg_DstImg];
	
	SwizzleShaderInfo	info;
	info.inputPF = self.inputPF;
	info.outputPF = self.outputPF;
	id<MTLBuffer>		infoBuffer = [self.device
		newBufferWithBytes:&info
		length:sizeof(info)
		options:MTLResourceStorageModeShared];
	[self.computeEncoder setBuffer:infoBuffer offset:0 atIndex:SwizzleShaderArg_Info];
	
	MTLSize			threadGroupSize = MTLSizeMake(self.threadGroupSizeVal, self.threadGroupSizeVal, 1);
	MTLSize			numGroups = [self calculateNumberOfGroups];
	[self.computeEncoder dispatchThreadgroups:numGroups threadsPerThreadgroup:threadGroupSize];
}


@end
