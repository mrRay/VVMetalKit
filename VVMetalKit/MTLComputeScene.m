#import "MTLComputeScene.h"

#import "MTLImgBuffer.h"
#import "MTLImgBufferPool.h"




@interface MTLComputeScene ()
@property (strong,nonatomic) id<MTLComputeCommandEncoder> computeEncoder;
@property (readwrite,nonatomic) NSUInteger threadGroupSizeVal;
@end




@implementation MTLComputeScene


- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice	{
	self = [super initWithDevice:inDevice];
	if (self != nil)	{
		self.computePipelineStateObject = nil;
		self.computeEncoder = nil;
		self.threadGroupSizeVal = 0;
		self.shaderEvalSize = MTLSizeMake(1,1,1);
	}
	return self;
}
- (void) dealloc	{
	self.computePipelineStateObject = nil;
	self.computeEncoder = nil;
}


- (void) _renderSetup	{
	if (self.threadGroupSizeVal < 1 && self.computePipelineStateObject != nil)	{
		//	threadGroupSize.width * threadGroupSize.height * threadGroupSize.depth MUST BE <= max total threads per threadgroup)
		self.threadGroupSizeVal = (NSUInteger)sqrt( (double)self.computePipelineStateObject.maxTotalThreadsPerThreadgroup );
	}
	
	//	the super creates the command buffer, populates it with any transitive scheduled/completed blocks
	[super _renderSetup];
	
	//	make a render encoder
	self.computeEncoder = [self.commandBuffer computeCommandEncoder];
	if (self.label != nil)
		self.computeEncoder.label = self.label;
	else
		self.computeEncoder.label = [NSString stringWithFormat:@"%@ encoder",NSStringFromClass(self.class)];
	
	//	set the pipeline state
	[self.computeEncoder setComputePipelineState:self.computePipelineStateObject];
}
- (void) _renderTeardown	{
	//	end encoding
	[self.computeEncoder endEncoding];
	
	//	super commits and then frees the command buffer on teardown
	[super _renderTeardown];
	
	//	free my local vars
	self.computeEncoder = nil;
}


- (MTLSize) calculateNumberOfGroups	{
	MTLSize			threadGroupSize = MTLSizeMake(self.threadGroupSizeVal, self.threadGroupSizeVal, 1);
	MTLSize			numGroups = MTLSizeMake(
		self.renderSize.width/self.shaderEvalSize.width/threadGroupSize.width + 1,
		self.renderSize.height/self.shaderEvalSize.height/threadGroupSize.height + 1,
		1);
	return numGroups;
}


@end
