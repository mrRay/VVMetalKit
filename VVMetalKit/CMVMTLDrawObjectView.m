//
//  CMVMTLDrawObjectView.m
//  VVMetalKit
//
//  Created by testadmin on 2/6/25.
//

#import "CMVMTLDrawObjectView.h"

@implementation CMVMTLDrawObjectView

- (void) generalInit	{
	[super generalInit];
	
	_mvpBuffer = nil;
	
	self.contentNeedsRedraw = YES;
}

#pragma mark - frontend

- (void) drawObject:(CMVMTLDrawObject*)inDrawObj inCmdBuffer:(id<MTLCommandBuffer>)cmdBuffer	{
	//NSLog(@"%s",__func__);
	
	//	get local copies of some buffers and stuff we'll need to draw
	id<MTLBuffer>		localMVPBuffer = nil;
	//id<MTLBuffer>		localVertBuffer = nil;
	id<MTLRenderPipelineState>		localPSO = nil;
	//VVFontAtlasMTLLabelDrawResources	*drawResources = self.labelA.drawResources;
	
	@synchronized (self)	{
		
		//	always set this to NO as soon as you're pretty sure the frame can/will be drawn!
		self.contentNeedsRedraw = NO;
		
		//	make sure the mvp buffer exists, create it if it doesn't
		if (self.mvpBuffer == nil)	{
			self.mvpBuffer = CreateOrthogonalMVPBufferForCanvas(NSMakeRect(0,0,viewportSize.x,viewportSize.y), NO, NO, metalLayer.device);
		}
		localMVPBuffer = self.mvpBuffer;
		
		localPSO = pso;
	}
	
	if (metalLayer.device==nil || metalLayer==nil)	{
		NSLog(@"ERR: bailing, %s",__func__);
		return;
	}
	
	//	configure the current drawable & render pass descriptor
	currentDrawable = metalLayer.nextDrawable;
	if (currentDrawable == nil)	{
		NSLog(@"ERR: current drawable nil in %s",__func__);
		return;
	}
	if (currentDrawable.texture == nil)	{
		NSLog(@"ERR: current drawable tex nil in %s",__func__);
		return;
	}
	passDescriptor.colorAttachments[0].texture = currentDrawable.texture;
	
	//	make a render encoder, configure it
	id<MTLRenderCommandEncoder>		renderEncoder = [cmdBuffer renderCommandEncoderWithDescriptor:passDescriptor];
	renderEncoder.label = [NSString stringWithFormat:@"%@ encoder",[self className]];
	[renderEncoder setViewport:(MTLViewport){ 0.f, 0.f, viewportSize.x, viewportSize.y, -1.f, 1.f }];
	[renderEncoder setRenderPipelineState:localPSO];
	[renderEncoder setVertexBuffer:localMVPBuffer offset:0 atIndex:CMV_VS_IDX_MVP];
	
	//	execute the draw object
	if (inDrawObj != nil)	{
		id<MTLFunction>		localFragFunc = psoDesc.fragmentFunction;
		id<MTLArgumentEncoder>		argEncoder = [localFragFunc newArgumentEncoderWithBufferIndex:CMV_FS_Idx_Tex];
		[inDrawObj executeInRenderEncoder:renderEncoder textureArgumentEncoder:argEncoder commandBuffer:cmdBuffer];
	}
	
	//	finish up the encoder
	[renderEncoder endEncoding];
	
	//NSLog(@"\t\tcmd buffer should have cmds for %@ in it...",self);
	//	the buffer needs to draw the drawable!
	[cmdBuffer presentDrawable:currentDrawable];
	
	currentDrawable = nil;
}

#pragma mark - superclass overrides

- (void) setDevice:(id<MTLDevice>)n	{
	@synchronized (self)	{
		//	call the super first!
		[super setDevice:n];
		
		//	configure the render pipeline
		NSError				*nsErr = nil;
		NSBundle			*myBundle = [NSBundle bundleForClass:[CustomMetalView class]];
		id<MTLLibrary>		defaultLibrary = [n newDefaultLibraryWithBundle:myBundle error:&nsErr];
		id<MTLFunction>		vertFunc = [defaultLibrary newFunctionWithName:@"CustomMetalViewVertShader"];
		id<MTLFunction>		fragFunc = [defaultLibrary newFunctionWithName:@"CustomMetalViewFragShader"];
		
		psoDesc = [[MTLRenderPipelineDescriptor alloc] init];
		//psoDesc.previewLabel = @"VVMTLImgBufferView pipeline";
		psoDesc.vertexFunction = vertFunc;
		psoDesc.fragmentFunction = fragFunc;
		psoDesc.colorAttachments[0].pixelFormat = metalLayer.pixelFormat;
		psoDesc.colorAttachments[0].writeMask = MTLColorWriteMaskAll;
		
		//	commented out- this was an attempt to make MTLImgBufferRectView "transparent" (0 alpha would display view behind it)
		psoDesc.alphaToCoverageEnabled = NO;
		psoDesc.colorAttachments[0].blendingEnabled = YES;
		psoDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
		psoDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
		
		//	"GL over" is:
		psoDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
		psoDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
		psoDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
		psoDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
		
		//	"GL add" is:
		//psoDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
		//psoDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
		//psoDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorDestinationAlpha;
		//psoDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
		
		//	make the PSO
		pso = [device newRenderPipelineStateWithDescriptor:psoDesc error:&nsErr];
		
		self.mvpBuffer = nil;
	}
	self.contentNeedsRedraw = YES;
}
- (BOOL) reconfigureDrawable	{
	@synchronized (self)	{
		BOOL		sizeChanged = [super reconfigureDrawable];
	
		if (sizeChanged)	{
			self.mvpBuffer = nil;
		}
	
		return sizeChanged;
	}
}

@end
