//
//  MTLRenderScene.m
//  VVMetalKit
//
//  Created by testAdmin on 5/9/21.
//

#import "MTLRenderScene.h"

#import "MTLImgBuffer.h"
#import "MTLPool.h"




@interface MTLRenderScene ()
@property (strong,nonatomic) MTLRenderPassDescriptor * renderPassDescriptor;
@property (readwrite,nonatomic) id<MTLRenderCommandEncoder> renderEncoder;
@end




@implementation MTLRenderScene


- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice	{
	self = [super initWithDevice:inDevice];
	if (self != nil)	{
		self.renderPipelineStateObject = nil;
		self.renderPassDescriptor = nil;
		self.renderEncoder = nil;
		self.vertBuffer = nil;
		self.mvpBuffer = nil;
	}
	return self;
}
- (void) dealloc	{
	self.renderPipelineStateObject = nil;
	self.renderPassDescriptor = nil;
	self.renderEncoder = nil;
}


- (void) _renderSetup	{
	//	the super creates the command buffer, populates it with any transitive scheduled/completed blocks
	[super _renderSetup];
	
	//	make a render pass descriptor, configure it to use the attachment texture
	self.renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
	if (self.renderTarget != nil)	{
		MTLRenderPassColorAttachmentDescriptor		*attachDesc = self.renderPassDescriptor.colorAttachments[0];
		attachDesc.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
		attachDesc.texture = self.renderTarget.texture;
		attachDesc.loadAction = MTLLoadActionDontCare;
	}
	
	//	make a render encoder
	self.renderEncoder = [self.commandBuffer renderCommandEncoderWithDescriptor:self.renderPassDescriptor];
	
	//	configure the viewport
	CGSize			tmpSize = self.renderSize;
	[self.renderEncoder setViewport:(MTLViewport){ 0.f, 0.f, tmpSize.width, tmpSize.height, -1.f, 1.f }];
	
	//	set the pipeline state
	if (self.renderPipelineStateObject != nil)
		[self.renderEncoder setRenderPipelineState:self.renderPipelineStateObject];
}
- (void) _renderTeardown	{
	//	if there's a color attachment, make sure it's retained through the end of the command buffer
	if (self.renderTarget != nil)	{
		//VVMTLImgBuffer		*tmpBuffer = self.renderTarget;
		//AntiARCRetain(tmpBuffer);
		//[self.commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> cb)	{
		//	AntiARCRelease(tmpBuffer);
		//}];
	}
	
	//	end encoding
	[self.renderEncoder endEncoding];
	
	//	super commits and then frees the command buffer on teardown
	[super _renderTeardown];
	
	//	free my local vars
	self.renderEncoder = nil;
	self.renderPassDescriptor = nil;
}


- (void) setRenderSize:(CGSize)n	{
	BOOL		changed = (CGSizeEqualToSize(n,self.renderSize)) ? NO : YES;
	[super setRenderSize:n];
	if (changed)	{
		self.vertBuffer = nil;
		self.mvpBuffer = nil;
	}
}


@end
