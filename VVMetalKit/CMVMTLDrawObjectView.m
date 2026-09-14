//
//  CMVMTLDrawObjectView.m
//  VVMetalKit
//
//  Created by testadmin on 2/6/25.
//

#import "CMVMTLDrawObjectView.h"
#import "VVMacros.h"

@implementation CMVMTLDrawObjectView

- (void) generalInit	{
	[super generalInit];
	
	_mvpBuffer = nil;
	_drawObjects = [NSMutableArray arrayWithCapacity:0];
	
	self.contentNeedsRedraw = YES;
}

#pragma mark - frontend

- (void) clearDrawObjects	{
	@synchronized (self)	{
		[_drawObjects removeAllObjects];
	}
}
- (void) addDrawObject:(CMVMTLDrawObject *)n	{
	if (n != nil)	{
		@synchronized (self)	{
			[_drawObjects addObject:n];
		}
	}
}

- (void) drawNow	{
	if (self.localWindow==nil || self.localHidden)	{
		//NSLog(@"\t\terr: bailing A %s, %@",__func__,[self className]);
		return;
	}
	
	NSArray<CMVMTLDrawObject*>		*localDrawObjects = nil;
	@synchronized (self)	{
		localDrawObjects = [_drawObjects copy];
	}
	
	id<MTLCommandBuffer>		cmdBuffer = [RenderProperties.global.displayCmdQueue commandBuffer];
	
	[self drawObjects:localDrawObjects inCommandBuffer:cmdBuffer];
	
	[cmdBuffer commit];
}
- (void) drawInCommandBuffer:(id<MTLCommandBuffer>)inCmdBuffer	{
	NSArray<CMVMTLDrawObject*>		*localDrawObjects = nil;
	@synchronized (self)	{
		localDrawObjects = [_drawObjects copy];
	}
	if (localDrawObjects==nil || localDrawObjects.count<1)
		return;
	[self drawObjects:localDrawObjects inCommandBuffer:inCmdBuffer];
	localDrawObjects = nil;
}
- (void) drawObject:(CMVMTLDrawObject*)inDrawObj inCommandBuffer:(id<MTLCommandBuffer>)cmdBuffer	{
	if (inDrawObj == nil)
		[self drawObjects:@[] inCommandBuffer:cmdBuffer];
	else
		[self drawObjects:@[inDrawObj] inCommandBuffer:cmdBuffer];
}
- (void) drawObjects:(NSArray<CMVMTLDrawObject*> *)inDrawObjs inCommandBuffer:(id<MTLCommandBuffer>)cmdBuffer	{

	//	if my parent window is occluded, bail
	if (!A_HAS_B(self.localOcclusionState, NSWindowOcclusionStateVisible))	{
		return;
	}
	
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
		
		[self _loadPSO];
		localPSO = pso;
	}
	//	no PSO means the shader funcs didn't load- draw nothing, _loadPSO tries again next draw
	if (localPSO == nil)
		return;
	
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
	
	MTLRenderPassDescriptor		*localPassDesc;
	@synchronized (self)	{
		localPassDesc = [passDescriptor copy];
	}
	localPassDesc.colorAttachments[0].texture = currentDrawable.texture;
	
	//	make a render encoder, configure it
	id<MTLRenderCommandEncoder>		renderEncoder = [cmdBuffer renderCommandEncoderWithDescriptor:localPassDesc];
	renderEncoder.label = [NSString stringWithFormat:@"%@ encoder",[self className]];
	[renderEncoder setViewport:(MTLViewport){ 0.f, 0.f, viewportSize.x, viewportSize.y, -1.f, 1.f }];
	[renderEncoder setRenderPipelineState:localPSO];
	[renderEncoder setVertexBuffer:localMVPBuffer offset:0 atIndex:CMV_VS_IDX_MVP];
	
	//	execute the draw object(s)
	id<MTLArgumentEncoder>		argEncoder = self.textureArgumentEncoder;
	for (CMVMTLDrawObject * drawObj in inDrawObjs)	{
		if (drawObj != nil)	{
			[drawObj executeInRenderEncoder:renderEncoder textureArgumentEncoder:argEncoder commandBuffer:cmdBuffer];
		}
	}
	
	//	finish up the encoder
	[renderEncoder endEncoding];
	
	//NSLog(@"\t\tcmd buffer should have cmds for %@ in it...",self);
	//	the buffer needs to draw the drawable!
	[cmdBuffer presentDrawable:currentDrawable];
	
	currentDrawable = nil;
	localPassDesc = nil;
}

#pragma mark - superclass overrides

- (void) setDevice:(id<MTLDevice>)n	{
	@synchronized (self)	{
		[super setDevice:n];
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

- (BOOL) isACMVMTLDrawObjectView	{
	return YES;
}

@end
