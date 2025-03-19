//
//  VVMTLComputeScene.m
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import "VVMTLComputeScene.h"
#import "VVMTLScene_priv.h"
#import "VVMTLTextureImage.h"
#import "VVMTLPool.h"




@interface VVMTLComputeScene ()
@property (strong,nonatomic) id<MTLComputeCommandEncoder> computeEncoder;
@property (readwrite,nonatomic) NSUInteger threadGroupSizeVal;
@end




@implementation VVMTLComputeScene


- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice	{
	self = [super initWithDevice:inDevice];
	if (self != nil)	{
		self.computePSODesc = nil;
		self.computePSO = nil;
		self.computeEncoder = nil;
		self.shaderEvalSize = MTLSizeMake(1,1,1);
	}
	return self;
}
- (void) dealloc	{
	self.computePSODesc = nil;
	self.computePSO = nil;
	self.computeEncoder = nil;
}


- (void) _renderCallback	{
	//	if we don't currently have a PSO, load one!
	//if (self.computePSO == nil)	{
	//	[self _loadPSO];
	//}
	[super _renderCallback];
}
- (void) _renderSetup	{
	//	the super creates the command buffer, populates it with any transitive scheduled/completed blocks
	[super _renderSetup];
	
	//	make a render encoder
	self.computeEncoder = [self.commandBuffer computeCommandEncoder];
	if (self.label != nil)
		self.computeEncoder.label = self.label;
	else
		self.computeEncoder.label = [NSString stringWithFormat:@"%@ encoder",NSStringFromClass(self.class)];
	
	//	set the pipeline state
	[self.computeEncoder setComputePipelineState:self.computePSO];
}
- (void) _renderTeardown	{
	//	end encoding
	[self.computeEncoder endEncoding];
	
	//	super commits and then frees the command buffer on teardown
	[super _renderTeardown];
	
	//	free my local vars
	self.computeEncoder = nil;
}


- (void) setMsaaSamplecount:(NSUInteger)n	{
	BOOL		changed = (self.msaaSampleCount != n);
	[super setMsaaSampleCount:n];
	if (changed)	{
		self.computePSO = nil;
	}
}


- (MTLSize) calculateNumThreadgroups	{
	uint32_t		threadGroupSizeVal = (uint32_t)sqrt( (double)self.computePSO.maxTotalThreadsPerThreadgroup );
	MTLSize			threadGroupSize = MTLSizeMake(threadGroupSizeVal, threadGroupSizeVal, 1);
	MTLSize			numGroups = MTLSizeMake(
		self.renderSize.width/self.shaderEvalSize.width/threadGroupSize.width + 1,
		self.renderSize.height/self.shaderEvalSize.height/threadGroupSize.height + 1,
		1);
	return numGroups;
}


@end

