#import "SwizzleMTLScene.h"
#import "VVMTLPool.h"
//#import "VVMTLTextureImageShaderTypes.h"
#import "RenderProperties.h"
#import "SwizzleMTLSceneTypes.h"
#import "VVMTLScene_priv.h"
//#import <VVCore/VVCore.h>




@interface SwizzleMTLScene ()	{
	id<VVMTLBuffer>		slugBuffer;	//	we can't pass nil buffers to metal because...i don't know why not
	id<VVMTLTextureImage>		slugTexture;	//	we can't pass nil textures to metal because...if we do, the metal debugger doesn't work.
}

@property (strong) id<VVMTLBuffer> srcBuffer;
@property (strong) id<VVMTLTextureImage> srcRGBTexture;

@property (strong) id<VVMTLBuffer> dstBuffer;
@property (strong) id<VVMTLTextureImage> dstRGBTexture;

//	contains information describing how the shader should execute (the compute shader needs this)
@property (readwrite) SwizzleShaderOpInfo info;

@end




@implementation SwizzleMTLScene


#pragma mark - init/dealloc


- (nullable instancetype) initWithDevice:(id<MTLDevice>)n	{
	self = [super initWithDevice:n];
	if (self != nil)	{
		
		NSError				*nsErr = nil;
		NSBundle			*myBundle = [NSBundle bundleForClass:[self class]];
		id<MTLLibrary>		defaultLibrary = [self.device newDefaultLibraryWithBundle:myBundle error:&nsErr];
		id<MTLFunction>		func = [defaultLibrary newFunctionWithName:@"SwizzleMTLSceneFunc"];
		if (func == nil)	{
			NSLog(@"ERR: %s, func nil- lib is %@, bundle is %@/%@",__func__,defaultLibrary,myBundle,myBundle.bundlePath);
			self = nil;
			return self;
		}
		
		self.computePSO = [self.device
			newComputePipelineStateWithFunction:func
			error:&nsErr];
		if (self.computePSO == nil || nsErr != nil)	{
			NSLog(@"ERR: unable to make PSO, %@",nsErr);
			self = nil;
			return self;
		}
		
		slugBuffer = [VVMTLPool.global bufferWithLength:1 storage:MTLStorageModeShared];
		slugTexture = [VVMTLPool.global rgbaFloatTexSized:NSMakeSize(16,16)];
	}
	return self;
}


#pragma mark - frontend methods


- (void) convertSrcBuffer:(id<VVMTLBuffer>)inSrc dstBuffer:(nullable id<VVMTLBuffer>)outDst dstRGBTexture:(nullable id<VVMTLTextureImage>)inDstRGB swizzleInfo:(SwizzleShaderOpInfo)inInfo inCommandBuffer:(id<MTLCommandBuffer>)inCB	{
	//NSLog(@"%s",__func__);
	//NSLog(@"%s ... %@ -> %@",__func__,[NSString stringFromFourCC:inInfo.srcImg.pf],[NSString stringFromFourCC:inInfo.dstImg.pf]);
	//	if the src is nil, OR if both the dst buffer and dst texture are nil, bail
	if (inSrc==nil || (outDst==nil && inDstRGB==nil))	{
		NSLog(@"ERR: prereq A not met, %s",__func__);
		return;
	}
	
	//	if there's an RGB texture, its dimensions need to match the dims of the destination buffer
	if (inDstRGB != nil && (inInfo.dstImg.res[0] != inDstRGB.width || inInfo.dstImg.res[1] != inDstRGB.height))	{
		NSLog(@"ERR: prereq B not met, %s",__func__);
		return;
	}
	
	//if (inSrc != nil)	{
	//	id<MTLBlitCommandEncoder>		blitEncoder = [inCB blitCommandEncoder];
	//	[blitEncoder synchronizeResource:inSrc];
	//	[blitEncoder endEncoding];
	//}
	
	//	lock to prevent multiple threads from calling this method simultaneously, which wouldn't execute properly (we read the properties in the render callback)
	@synchronized (self)	{
		self.srcBuffer = inSrc;
		self.srcRGBTexture = nil;
		self.dstBuffer = outDst;
		self.dstRGBTexture = inDstRGB;
		self.info = inInfo;
	
		//	figure out what the shader eval size will be (likely based on the dst pixel format, which may be packed)
		switch (inInfo.dstImg.pf)	{
		case SwizzlePF_Unknown:
		case SwizzlePF_Luma_PK_UI_8:
		case SwizzlePF_Luma_PK_FP_32:
		case SwizzlePF_RGBA_PK_UI_8:
		case SwizzlePF_RGBX_PK_UI_8:
		case SwizzlePF_BGRA_PK_UI_8:
		case SwizzlePF_BGRX_PK_UI_8:
		case SwizzlePF_ARGB_PK_UI_8:
		case SwizzlePF_RGBA_PK_FP_32:
		case SwizzlePF_HSVA_PK_UI_8:
		case SwizzlePF_CMYK_PK_UI_8:
			self.shaderEvalSize = MTLSizeMake(1,1,1);
			break;
		case SwizzlePF_UYVY_PK_422_UI_8:
		case SwizzlePF_YUYV_PK_422_UI_8:
		case SwizzlePF_UYVA_PKPL_422_UI_8:
		case SwizzlePF_UYVA_PKPL_422_UI_16:
		case SwizzlePF_UYVY_PKPL_422_UI_16:
			self.shaderEvalSize = MTLSizeMake(2,1,1);
			break;
		case SwizzlePF_UYVY_PK_422_UI_10:
			self.shaderEvalSize = MTLSizeMake(6,1,1);
			break;
		//case SwizzlePF_UYVY_PKPL_422_UI_16:
		//	self.shaderEvalSize = MTLSizeMake(1,1,1);
		//	break;
		case SwizzlePF_UYVY_PKPL_420_UI_8:
		case SwizzlePF_UYVY_PL_420_UI_8:
			self.shaderEvalSize = MTLSizeMake(2,2,1);
			break;
		//case SwizzlePF_Y_8:	//	these should never get hit, the pixel formats are basically used to refer to planes
		//case SwizzlePF_CbCr_PK_8:
		//	self.shaderEvalSize = MTLSizeMake(1,1,1);
		//	break;
		}
		
		_info.readSrcImgFromBuffer = true;
		
		//	make sure our SwizzleShaderOpInfo object has an accurate record of how many pixels need to be processed in the shader
		_info.dstPixelsToProcess[0] = (int)self.shaderEvalSize.width;
		_info.dstPixelsToProcess[1] = (int)self.shaderEvalSize.height;
		
		//	don't call 'renderToTexture', it sets the render size to 1x1 if you have a nil buffer- instead, do this (which is basically equivalent)
		//[self renderToTexture:nil inCommandBuffer:inCB];
		{
			self.renderSize = CGSizeMake(inInfo.dstImg.res[0], inInfo.dstImg.res[1]);
		
			self.renderTarget = nil;
			self.commandBuffer = inCB;
		
			[self _renderCallback];
		
			self.commandBuffer = nil;
			self.renderTarget = nil;
		}
	
		self.srcBuffer = nil;
		self.srcRGBTexture = nil;
		self.dstBuffer = nil;
		self.dstRGBTexture = nil;
	}
	
	//if (outDst != nil)	{
	//	id<MTLBlitCommandEncoder>		blitEncoder = [inCB blitCommandEncoder];
	//	[blitEncoder synchronizeResource:outDst];
	//	[blitEncoder endEncoding];
	//}
}
- (void) convertSrcRGBTexture:(id<VVMTLTextureImage>)inSrc dstBuffer:(nullable id<VVMTLBuffer>)outDst dstRGBTexture:(nullable id<VVMTLTextureImage>)outTex swizzleInfo:(SwizzleShaderOpInfo)inInfo inCommandBuffer:(id<MTLCommandBuffer>)inCB;	{
	//	if the src texture or dst buffer are nil, bail
	//if (inSrc == nil || outDst == nil)
	if (inSrc==nil && !(outDst!=nil || outTex != nil))
	{
		NSLog(@"ERR: prereq A not met, %s",__func__);
		return;
	}
	
	//	lock to prevent multiple threads from calling this method simultaneously, which wouldn't execute properly (we read the properties in the render callback)
	@synchronized (self)	{
		self.srcBuffer = nil;
		self.srcRGBTexture = inSrc;
		self.dstBuffer = outDst;
		self.dstRGBTexture = outTex;
		self.info = inInfo;
	
		//	figure out what the shader eval size will be (likely based on the dst pixel format, which may be packed)
		switch (inInfo.dstImg.pf)	{
		case SwizzlePF_Unknown:
		case SwizzlePF_Luma_PK_UI_8:
		case SwizzlePF_Luma_PK_FP_32:
		case SwizzlePF_RGBA_PK_UI_8:
		case SwizzlePF_RGBX_PK_UI_8:
		case SwizzlePF_BGRA_PK_UI_8:
		case SwizzlePF_BGRX_PK_UI_8:
		case SwizzlePF_ARGB_PK_UI_8:
		case SwizzlePF_RGBA_PK_FP_32:
		case SwizzlePF_HSVA_PK_UI_8:
		case SwizzlePF_CMYK_PK_UI_8:
			self.shaderEvalSize = MTLSizeMake(1,1,1);
			break;
		case SwizzlePF_UYVY_PK_422_UI_8:
		case SwizzlePF_YUYV_PK_422_UI_8:
		case SwizzlePF_UYVA_PKPL_422_UI_8:
		case SwizzlePF_UYVA_PKPL_422_UI_16:
		case SwizzlePF_UYVY_PKPL_422_UI_16:
			self.shaderEvalSize = MTLSizeMake(2,1,1);
			break;
		case SwizzlePF_UYVY_PKPL_420_UI_8:
		case SwizzlePF_UYVY_PL_420_UI_8:
			self.shaderEvalSize = MTLSizeMake(2,2,1);
			break;
		case SwizzlePF_UYVY_PK_422_UI_10:
			self.shaderEvalSize = MTLSizeMake(6,1,1);
			break;
		}
		
		_info.readSrcImgFromBuffer = false;
		
		//	make sure our SwizzleShaderOpInfo object has an accurate record of how many pixels need to be processed in the shader
		_info.dstPixelsToProcess[0] = (int)self.shaderEvalSize.width;
		_info.dstPixelsToProcess[1] = (int)self.shaderEvalSize.height;
	
		//	don't call 'renderToTexture', it sets the render size to 1x1 if you have a nil buffer- instead, do this (which is basically equivalent)
		//[self renderToTexture:nil inCommandBuffer:inCB];
		{
			self.renderSize = CGSizeMake(inInfo.dstImg.res[0], inInfo.dstImg.res[1]);
		
			self.renderTarget = nil;
			self.commandBuffer = inCB;
		
			[self _renderCallback];
		
			self.commandBuffer = nil;
			self.renderTarget = nil;
		}
	
		self.srcBuffer = nil;
		self.srcRGBTexture = nil;
		self.dstBuffer = nil;
		self.dstRGBTexture = nil;
	}
	
	//if (outDst != nil)	{
	//	id<MTLBlitCommandEncoder>		blitEncoder = [inCB blitCommandEncoder];
	//	[blitEncoder synchronizeResource:outDst];
	//	[blitEncoder endEncoding];
	//}
}

- (void) renderCallback	{
	id<VVMTLBuffer>		srcBuffer = self.srcBuffer;
	id<VVMTLTextureImage>		srcRGBTex = self.srcRGBTexture;
	id<VVMTLBuffer>		dstBuffer = self.dstBuffer;
	id<VVMTLTextureImage>		dstRGBTex = self.dstRGBTexture;
	bool				outputToBuffer = true;
	
	if (srcBuffer == nil)
		srcBuffer = slugBuffer;
	if (dstBuffer == nil)	{
		dstBuffer = slugBuffer;
		outputToBuffer = false;
	}
	
	if (srcRGBTex == nil)
		srcRGBTex = slugTexture;
	
	[self.computeEncoder
		setBuffer:srcBuffer.buffer
		offset:0
		atIndex:SwizzleShaderArg_SrcBuffer];
	
	[self.computeEncoder
		setTexture:srcRGBTex.texture
		atIndex:SwizzleShaderArg_SrcRGBTexture];
	
	[self.computeEncoder
		setBuffer:dstBuffer.buffer
		offset:0
		atIndex:SwizzleShaderArg_DstBuffer];
	
	[self.computeEncoder
		setTexture:(dstRGBTex==nil) ? nil : dstRGBTex.texture
		atIndex:SwizzleShaderArg_DstRGBTexture];
	
	SwizzleShaderOpInfo	info = self.info;
	id<MTLBuffer>		infoBuffer = [self.device
		newBufferWithBytes:&info
		length:sizeof(info)
		options:MTLResourceStorageModeShared];
	[self.computeEncoder setBuffer:infoBuffer offset:0 atIndex:SwizzleShaderArg_OpInfo];
	
	id<MTLBuffer>		writeBufferBuffer = [self.device
		newBufferWithBytes:&outputToBuffer
		length:sizeof(outputToBuffer)
		options:MTLResourceStorageModeShared];
	[self.computeEncoder setBuffer:writeBufferBuffer offset:0 atIndex:SwizzleShaderArg_WriteBuffer];
	
	[self.commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> cb)	{
		id<VVMTLBuffer>		a = srcBuffer;
		id<VVMTLBuffer>		b = dstBuffer;
		id<VVMTLTextureImage>		c = dstRGBTex;
		id<MTLBuffer>		d = infoBuffer;
		id<MTLBuffer>		e = writeBufferBuffer;
		
		e = nil;
		d = nil;
		c = nil;
		b = nil;
		a = nil;
	}];
	
	uint32_t		threadGroupSizeVal = (uint32_t)sqrt( (double)self.computePSO.maxTotalThreadsPerThreadgroup );
	MTLSize			threadGroupSize = MTLSizeMake(threadGroupSizeVal, threadGroupSizeVal, 1);
	MTLSize			numGroups = [self calculateNumThreadgroups];
	[self.computeEncoder dispatchThreadgroups:numGroups threadsPerThreadgroup:threadGroupSize];
	
	infoBuffer = nil;
	dstRGBTex = nil;
	dstBuffer = nil;
	srcRGBTex = nil;
	srcBuffer = nil;
}


@end

