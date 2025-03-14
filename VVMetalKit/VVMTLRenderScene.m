//
//  VVMTLRenderScene.m
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import "VVMTLRenderScene.h"

#import <VVMetalKit/AAPLMathUtilities.h>
#import "VVMTLScene_priv.h"
#import "VVMTLTextureImage.h"
#import "VVMTLPool.h"
#import "VVMacros.h"




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
		
		self.renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
		//self.renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
		self.renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
		
		self.renderPassDescriptor.depthAttachment.clearDepth = 1.0;
		self.renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
		//self.renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;
		
		self.renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
		//self.renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionMultisampleResolve;
		
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
		
		//	subclasses still need to create their pipeline state objects...
		//self.renderPSO = [inDevice newRenderPipelineStateWithDescriptor:self.renderPSODesc error:&nsErr];
	}
	return self;
}
- (void) dealloc	{
	self.renderPSO = nil;
	self.renderPassDescriptor = nil;
	self.renderEncoder = nil;
}


- (void) _renderCallback	{
	//	if we don't currently have a PSO, load one!
	//if (self.renderPSO == nil)	{
	//	[self _loadPSO];
	//}
	[super _renderCallback];
}
- (void) _renderSetup	{
	//	the super populates the cmd buffer with any transitive scheduled/completed blocks
	[super _renderSetup];
	
	MTLRenderPassDescriptor		*localDesc = [self.renderPassDescriptor copy];
	
	//	configure the render pass descriptor to use the various attached textures
	if (self.msaaTarget != nil)	{
		localDesc.colorAttachments[0].texture = self.msaaTarget.texture;
		if (self.renderTarget != nil)
			localDesc.colorAttachments[0].resolveTexture = self.renderTarget.texture;
	}
	else if (self.renderTarget != nil)	{
		localDesc.colorAttachments[0].texture = self.renderTarget.texture;
		localDesc.colorAttachments[0].resolveTexture = nil;
	}
	
	if (self.depthTarget != nil)	{
		localDesc.depthAttachment.texture = self.depthTarget.texture;
	}
	
	//	make a render encoder
	self.renderEncoder = [self.commandBuffer renderCommandEncoderWithDescriptor:localDesc];
	if (self.label != nil)
		self.renderEncoder.label = self.label;
	else
		self.renderEncoder.label = [NSString stringWithFormat:@"%@ encoder",NSStringFromClass(self.class)];
	
	//	configure the MVP buffer
	[self _setMVPBuffer];
	
	//	configure the viewport
	[self _setViewport];
	
	//	set the pipeline state
	if (self.renderPSO != nil)
		[self.renderEncoder setRenderPipelineState:self.renderPSO];
	
	localDesc = nil;
}
- (void) _setViewport	{
	//	configure the viewport
	CGSize			tmpSize = self.renderSize;
	//[self.renderEncoder setViewport:(MTLViewport){ 0.f, 0.f, tmpSize.width, tmpSize.height, -10.f, 10.f }];
	[self.renderEncoder setViewport:(MTLViewport){ 0.f, 0.f, tmpSize.width, tmpSize.height, -1.f, 1.f }];
}
- (void) _setMVPBuffer	{
	NSSize			renderSize = self.renderSize;
	self.mvpBuffer = CreateOrthogonalMVPBufferForCanvas(NSMakeRect(0,0,renderSize.width,renderSize.height),NO,NO,self.device);
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


- (void) setMsaaSamplecount:(NSUInteger)n	{
	BOOL		changed = (self.msaaSampleCount != n);
	[super setMsaaSampleCount:n];
	if (changed)	{
		self.renderPSO = nil;
	}
}


@end





id<MTLBuffer> CreateOrthogonalMVPBufferForCanvas(NSRect inCanvasBounds, BOOL inFlipH, BOOL inFlipV, id<MTLDevice> inDevice)	{
	double			left = VVMINX(inCanvasBounds);
	double			right = VVMAXX(inCanvasBounds);
	double			top = VVMAXY(inCanvasBounds);
	double			bottom = VVMINY(inCanvasBounds);
	double			far = 1.0;
	double			near = -1.0;
	if (inFlipV)	{
		//top = 0.0;
		//bottom = renderSize.height;
		top = VVMINY(inCanvasBounds);
		bottom = VVMAXY(inCanvasBounds);
	}
	if (inFlipH)	{
		//right = 0.0;
		//left = renderSize.width;
		right = VVMINX(inCanvasBounds);
		left = VVMAXX(inCanvasBounds);
	}
	
	matrix_float4x4		mvp = matrix_ortho_left_hand(left, right, bottom, top, near, far);
	
	id<MTLBuffer>		returnMe = [inDevice
		newBufferWithBytes:&mvp
		length:sizeof(mvp)
		options:MTLResourceStorageModeShared];
	
	return returnMe;
}
//matrix_float4x4 CreatePerspectiveProjectionForCanvas(NSRect inCanvasBounds, double near, double far, id<MTLDevice> inDevice)	{
//	double			left = round(VVMINX(inCanvasBounds));
//	double			right = round(VVMAXX(inCanvasBounds));
//	double			top = round(VVMAXY(inCanvasBounds));
//	double			bottom = round(VVMINY(inCanvasBounds));
//	matrix_float4x4			mvp = simd_matrix_from_rows(
//		simd_make_float4((2.*near)/(right-left),	0.,							0.,							0.),
//		simd_make_float4(0.,						(2.*near)/(top-bottom),		0.,							0.),
//		simd_make_float4(0.,						0.,							(-1.*(far))/(far-near),		-1.),
//		simd_make_float4(0.,						0.,							(-1.*far*near)/(far-near),	0.)
//	);
//	return mvp;
//}




