#import "SwizzleMTLScene.h"
#import "MTLPool.h"
//#import "MTLImgBufferShaderTypes.h"
#import "RenderProperties.h"
#import "SwizzleMTLSceneTypes.h"
#import "MTLScene_priv.h"




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
//@property (strong) MTLImgBuffer * inputImage;
//@property (readwrite) SwizzlePF inputPF;
//@property (readwrite) SwizzlePF outputPF;
@property (strong) id<MTLBuffer> srcBuffer;
@property (strong) id<MTLBuffer> dstBuffer;
@property (strong) MTLImgBuffer * rgbTexture;
@property (readwrite) SwizzleShaderInfo info;
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
		
		self.computePipelineStateObject = [self.device
			newComputePipelineStateWithFunction:func
			error:&nsErr];
		if (self.computePipelineStateObject == nil || nsErr != nil)
			NSLog(@"ERR: unable to make PSO, %@",nsErr);
	}
	return self;
}


#pragma mark - frontend methods


- (id<MTLBuffer>) bufferWithLength:(size_t)inLength basePtr:(void*)b bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
	id<MTLBuffer>		returnMe = nil;
	if (b == nil)
		returnMe = [self.device newBufferWithLength:inLength options:MTLResourceStorageModePrivate];
	else
		returnMe = [self.device newBufferWithBytesNoCopy:b length:inLength options:MTLResourceStorageModeManaged deallocator:d];
	return returnMe;
}

- (void) convertSrcBuffer:(id<MTLBuffer>)inSrc dstBuffer:(id<MTLBuffer>)inDst dstRGBTexture:(MTLImgBuffer *)inDstRGB swizzleInfo:(SwizzleShaderInfo)inInfo inCommandBuffer:(id<MTLCommandBuffer>)inCB	{
	//	if the src or dst are nil, bail.  the rgb texture can be nil- but that's it!
	if (inSrc==nil || inDst==nil)	{
		NSLog(@"ERR: prereq A not met, %s",__func__);
		return;
	}
	
	/*
	//	either src or dst has to be RGB.
	BOOL		srcIsRGB = NO;
	BOOL		dstIsRGB = NO;
	switch (inInfo.srcImg.pf)	{
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBA_PK_FP_32:
		srcIsRGB = YES;
		break;
	default:
		break;
	}
	switch (inInfo.dstImg.pf)	{
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBA_PK_FP_32:
		dstIsRGB = YES;
		break;
	default:
		break;
	}
	if (!srcIsRGB && !dstIsRGB)	{
		NSLog(@"ERR: neither src nor dst are RGB, %s",__func__);
		return;
	}
	*/
	
	//	if there's an RGB texture, its dimensions need to match the dims of the destination buffer
	if (inDstRGB != nil && (inInfo.dstImg.res[0] != inDstRGB.width || inInfo.dstImg.res[1] != inDstRGB.height))	{
		NSLog(@"ERR: prereq B not met, %s",__func__);
		return;
	}
	
	self.srcBuffer = inSrc;
	self.dstBuffer = inDst;
	self.rgbTexture = inDstRGB;
	self.info = inInfo;
	
	//	figure out what the shader eval size will be (likely based on the dst pixel format, which may be packed)
	switch (inInfo.dstImg.pf)	{
	case SwizzlePF_RGBA_PK_UI_8:
	case SwizzlePF_RGBA_PK_FP_32:
		self.shaderEvalSize = MTLSizeMake(1,1,1);
		break;
	case SwizzlePF_UYVY_PK_422_UI_8:
		self.shaderEvalSize = MTLSizeMake(2,1,1);
		break;
	case SwizzlePF_UYVY_PK_422_UI_10:
		self.shaderEvalSize = MTLSizeMake(6,1,1);
		break;
	case SwizzlePF_UYVY_PL_422_UI_16:
		self.shaderEvalSize = MTLSizeMake(1,1,1);
		break;
	}
	
	//	don't call 'renderToBuffer', it sets the render size to 1x1 if you have a nil buffer- instead, do this (which is basically equivalent)
	//[self renderToBuffer:nil inCommandBuffer:inCB];
	{
		renderSize = CGSizeMake(inInfo.dstImg.res[0], inInfo.dstImg.res[1]);
		
		self.renderTarget = nil;
		self.commandBuffer = inCB;
		
		[self _renderCallback];
		
		self.commandBuffer = nil;
		self.renderTarget = nil;
	}
	
	self.srcBuffer = nil;
	self.dstBuffer = nil;
	self.rgbTexture = nil;
}

- (void) renderCallback	{
	id<MTLBuffer>		srcBuffer = self.srcBuffer;
	id<MTLBuffer>		dstBuffer = self.dstBuffer;
	MTLImgBuffer		*rgbTex = self.rgbTexture;
	
	[self.computeEncoder setBuffer:srcBuffer offset:0 atIndex:SwizzleShaderArg_SrcBuffer];
	[self.computeEncoder setBuffer:dstBuffer offset:0 atIndex:SwizzleShaderArg_DstBuffer];
	[self.computeEncoder setTexture:rgbTex.texture atIndex:SwizzleShaderArg_RGBTexture];
	
	SwizzleShaderInfo	info = self.info;
	id<MTLBuffer>		infoBuffer = [self.device
		newBufferWithBytes:&info
		length:sizeof(info)
		options:MTLResourceStorageModeShared];
	[self.computeEncoder setBuffer:infoBuffer offset:0 atIndex:SwizzleShaderArg_Info];
	
	[self.commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> cb)	{
		id<MTLBuffer>		a = srcBuffer;
		id<MTLBuffer>		b = dstBuffer;
		MTLImgBuffer		*c = rgbTex;
		id<MTLBuffer>		d = infoBuffer;
		
		d = nil;
		c = nil;
		b = nil;
		a = nil;
	}];
	
	MTLSize			threadGroupSize = MTLSizeMake(self.threadGroupSizeVal, self.threadGroupSizeVal, 1);
	MTLSize			numGroups = [self calculateNumberOfGroups];
	[self.computeEncoder dispatchThreadgroups:numGroups threadsPerThreadgroup:threadGroupSize];
	
	infoBuffer = nil;
	rgbTex = nil;
	dstBuffer = nil;
	srcBuffer = nil;
}


@end
