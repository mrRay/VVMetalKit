//
//  VVMTLRenderScene.m
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import "VVMTLRenderScene.h"

#import "VVMTLTextureImage.h"
#import "VVMTLPool.h"




@interface VVMTLRenderScene ()
@property (strong,nonatomic) MTLRenderPassDescriptor * renderPassDescriptor;
@property (readwrite,nonatomic) id<MTLRenderCommandEncoder> renderEncoder;
@end




@implementation VVMTLRenderScene


- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice	{
	self = [super initWithDevice:inDevice];
	if (self != nil)	{
		self.renderPSODesc = nil;
		self.renderPSO = nil;
		self.renderPassDescriptor = nil;
		self.renderEncoder = nil;
		self.mvpBuffer = nil;
		
		self.renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
		MTLRenderPassColorAttachmentDescriptor		*attachDesc = self.renderPassDescriptor.colorAttachments[0];
		attachDesc.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
		attachDesc.loadAction = MTLLoadActionDontCare;
		
		self.renderPSODesc = [[MTLRenderPipelineDescriptor alloc] init];
		//self.renderPSODesc.vertexFunction = vertFunc;
		//self.renderPSODesc.fragmentFunction = fragFunc;
		self.renderPSODesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
		
		self.renderPSODesc.alphaToCoverageEnabled = NO;
		self.renderPSODesc.colorAttachments[0].blendingEnabled = YES;
		
		self.renderPSODesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
		self.renderPSODesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
		
		//	"GL over" is:
		self.renderPSODesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
		self.renderPSODesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
		self.renderPSODesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
		self.renderPSODesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
		
		//	"GL add" is:
		//self.renderPSODesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
		//self.renderPSODesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
		//self.renderPSODesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorDestinationAlpha;
		//self.renderPSODesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
	}
	return self;
}
- (void) dealloc	{
	self.renderPSO = nil;
	self.renderPassDescriptor = nil;
	self.renderEncoder = nil;
}


- (void) _renderSetup	{
	//	the super creates the command buffer, populates it with any transitive scheduled/completed blocks
	[super _renderSetup];
	
	//	configure the render pass descriptor to use the attachment texture
	if (self.renderTarget != nil)	{
		MTLRenderPassColorAttachmentDescriptor		*attachDesc = self.renderPassDescriptor.colorAttachments[0];
		attachDesc.texture = self.renderTarget.texture;
	}
	
	//	make a render encoder
	self.renderEncoder = [self.commandBuffer renderCommandEncoderWithDescriptor:self.renderPassDescriptor];
	
	//	configure the viewport
	CGSize			tmpSize = self.renderSize;
	[self.renderEncoder setViewport:(MTLViewport){ 0.f, 0.f, tmpSize.width, tmpSize.height, -1.f, 1.f }];
	
	//	set the pipeline state
	if (self.renderPSO != nil)
		[self.renderEncoder setRenderPipelineState:self.renderPSO];
}
- (void) _renderTeardown	{
	//	if there's a color attachment, make sure it's retained through the end of the command buffer
	if (self.renderTarget != nil)	{
		//id<VVMTLTextureImage>		tmpBuffer = self.renderTarget;
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
}


- (void) setRenderSize:(CGSize)n	{
	BOOL		changed = (CGSizeEqualToSize(n,self.renderSize)) ? NO : YES;
	[super setRenderSize:n];
	if (changed)	{
		self.mvpBuffer = nil;
	}
}


@end

