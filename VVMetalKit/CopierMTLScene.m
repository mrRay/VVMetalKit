#import "CopierMTLScene.h"
#import "MTLPool.h"
#import "MTLImgBufferShaderTypes.h"
#import "SizingTool_objc.h"




@interface CopierMTLScene ()
@property (strong) MTLImgBuffer * inputImage;
//@property (readwrite) BOOL autoCropToSrcRect;
@property (readwrite) BOOL allowScaling;
@end




@implementation CopierMTLScene


- (nullable instancetype) initWithDevice:(id<MTLDevice>)n	{
	self = [super initWithDevice:n];
	if (self != nil)	{
		self.inputImage = nil;
		
		NSError				*nsErr = nil;
		NSBundle			*myBundle = [NSBundle bundleForClass:[self class]];
		id<MTLLibrary>		defaultLibrary = [n newDefaultLibraryWithBundle:myBundle error:&nsErr];
		id<MTLFunction>		func = [defaultLibrary newFunctionWithName:@"CopierMTLSceneFunc"];
		
		self.computePipelineStateObject = [self.device
			newComputePipelineStateWithFunction:func
			error:&nsErr];
		if (self.computePipelineStateObject == nil || nsErr != nil)
			NSLog(@"ERR: unable to make PSO, %@",nsErr);
	}
	return self;
}
- (void) dealloc	{
	self.inputImage = nil;
}


- (void) copyImg:(MTLImgBuffer *)inSrc toImg:(MTLImgBuffer *)inDst allowScaling:(BOOL)inScale inCommandBuffer:(id<MTLCommandBuffer>)inCB	{
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
	
	self.inputImage = inSrc;
	
	[self renderToBuffer:inDst inCommandBuffer:inCB];
}


- (void) renderCallback	{
	//NSLog(@"%s",__func__);
	
	MTLImgBuffer		*inputImage = self.inputImage;
	[self.computeEncoder setTexture:inputImage.texture atIndex:0];
	
	MTLImgBuffer		*renderTarget = self.renderTarget;
	[self.computeEncoder setTexture:self.renderTarget.texture atIndex:1];
	
	MTLImgBufferStruct		geoStruct;
	[inputImage populateStruct:&geoStruct];
	geoStruct.dstRect = MakeRect(0.0, 0.0, renderTarget.width, renderTarget.height);
	
	//if (self.autoCropToSrcRect)	{
	//	geoStruct.srcRect = GRectFromNSRect(inputImage.srcRect);
	//}
	//else	{
	//	geoStruct.srcRect = MakeRect(0., 0., inputImage.width, inputImage.height);
	//}
	
	id<MTLBuffer>			geoBuffer = [self.device
		newBufferWithBytes:&geoStruct
		length:sizeof(MTLImgBufferStruct)
		options:MTLResourceStorageModeShared];
	[self.computeEncoder setBuffer:geoBuffer offset:0 atIndex:2];
	
	[self.commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> cb)	{
		//	make sure the input image buffer is retained through the end of the command buffer
		MTLImgBuffer		*tmpBufferA = self.inputImage;
		tmpBufferA = nil;
		//	make sure the render target is retained through the end of the command buffer
		MTLImgBuffer		*tmpBufferB = self.renderTarget;
		tmpBufferB = nil;
		//	make sure the geo buffer is retained through the end of the command buffer
		id<MTLBuffer>		tmpBufferC = geoBuffer;
		tmpBufferC = nil;
	}];
	
	MTLSize			threadGroupSize = MTLSizeMake(self.threadGroupSizeVal, self.threadGroupSizeVal, 1);
	MTLSize			numGroups = [self calculateNumberOfGroups];
	[self.computeEncoder dispatchThreadgroups:numGroups threadsPerThreadgroup:threadGroupSize];
	
	geoBuffer = nil;
	
}


@end
