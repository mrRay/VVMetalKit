#import "CopierMTLScene.h"
#import "VVMTLPool.h"
#import "VVMTLTextureImageShaderTypes.h"
#import "RenderProperties.h"
#import "SizingTool_objc.h"




@interface CopierMTLScene ()
@property (strong) id<VVMTLTextureImage> inputImage;
//@property (readwrite) BOOL autoCropToSrcRect;
@property (readwrite) BOOL allowScaling;
@property (readwrite) SizingMode sizingMode;
@end




@implementation CopierMTLScene


- (nullable instancetype) initWithDevice:(id<MTLDevice>)n	{
	self = [super initWithDevice:n];
	if (self != nil)	{
		self.inputImage = nil;
		
		NSError				*nsErr = nil;
		NSBundle			*myBundle = [NSBundle bundleForClass:[self class]];
		id<MTLLibrary>		defaultLibrary = [self.device newDefaultLibraryWithBundle:myBundle error:&nsErr];
		id<MTLFunction>		func = [defaultLibrary newFunctionWithName:@"CopierMTLSceneFunc"];
		
		self.computePSO = [self.device
			newComputePipelineStateWithFunction:func
			error:&nsErr];
		if (self.computePSO == nil || nsErr != nil)
			NSLog(@"ERR: unable to make PSO, %@",nsErr);
	}
	return self;
}
- (void) dealloc	{
	self.inputImage = nil;
}


- (void) copyImg:(id<VVMTLTextureImage>)inSrc toImg:(id<VVMTLTextureImage>)inDst allowScaling:(BOOL)inScale sizingMode:(SizingMode)inSM inCommandBuffer:(id<MTLCommandBuffer>)inCB	{
	if (inSrc==nil || inDst==nil || inCB==nil)	{
		NSLog(@"ERR: prereqs not met, %s",__func__);
		return;
	}
	
	NSSize			tmpSize = NSMakeSize(inDst.width,inDst.height);
	if (!inScale && !NSEqualSizes(inSrc.srcRect.size, tmpSize))	{
		NSLog(@"ERR: size mismatch, dst img size doesn't match src img src rect (%@ vs %@), %s",NSStringFromSize(inSrc.srcRect.size),NSStringFromSize(tmpSize),__func__);
		return;
	}
	
	self.allowScaling = inScale;
	
	self.sizingMode = inSM;
	
	self.inputImage = inSrc;
	
	[self renderToTexture:inDst inCommandBuffer:inCB];
}


- (void) renderCallback	{
	//NSLog(@"%s",__func__);
	
	id<VVMTLTextureImage>		inputImage = self.inputImage;
	[self.computeEncoder setTexture:inputImage.texture atIndex:0];
	
	id<VVMTLTextureImage>		renderTarget = self.renderTarget;
	[self.computeEncoder setTexture:self.renderTarget.texture atIndex:1];
	
	VVMTLTextureImageStruct		geoStruct;
	[inputImage populateStruct:&geoStruct];
	geoStruct.dstRect = MakeRect(0.0, 0.0, renderTarget.width, renderTarget.height);
	geoStruct.colorMultiplier = simd_make_float4(1,1,1,1);
	
	//if (self.autoCropToSrcRect)	{
	//	geoStruct.srcRect = GRectFromNSRect(inputImage.srcRect);
	//}
	//else	{
	//	geoStruct.srcRect = MakeRect(0., 0., inputImage.width, inputImage.height);
	//}
	
	id<MTLBuffer>			geoBuffer = [self.device
		newBufferWithBytes:&geoStruct
		length:sizeof(VVMTLTextureImageStruct)
		options:MTLResourceStorageModeShared];
	[self.computeEncoder setBuffer:geoBuffer offset:0 atIndex:2];
	
	[self.commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> cb)	{
		//	make sure the input image buffer is retained through the end of the command buffer
		id<VVMTLTextureImage>		tmpBufferA = self.inputImage;
		tmpBufferA = nil;
		//	make sure the render target is retained through the end of the command buffer
		id<VVMTLTextureImage>		tmpBufferB = self.renderTarget;
		tmpBufferB = nil;
		//	make sure the geo buffer is retained through the end of the command buffer
		id<MTLBuffer>		tmpBufferC = geoBuffer;
		tmpBufferC = nil;
	}];
	
	uint32_t		threadGroupSizeVal = (uint32_t)sqrt( (double)self.computePSO.maxTotalThreadsPerThreadgroup );
	MTLSize			threadGroupSize = MTLSizeMake(threadGroupSizeVal, threadGroupSizeVal, 1);
	MTLSize			numGroups = [self calculateNumThreadgroups];
	[self.computeEncoder dispatchThreadgroups:numGroups threadsPerThreadgroup:threadGroupSize];
	
	geoBuffer = nil;
	
}


@end
