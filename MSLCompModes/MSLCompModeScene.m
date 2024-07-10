//
//  MSLCompModeScene.m
//  MSLCompModes
//
//  Created by testadmin on 7/10/24.
//

#import "MSLCompModeScene.h"
#import "MSLCompModeController.h"
#import "MSLCompModeResourceController.h"
#import "MSLCompModeResource.h"
#import "MSLCompModeRecipeStep.h"
#import "MSLCompModeRecipe.h"




@implementation MSLCompModeScene

- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice	{
	self = [super initWithDevice:inDevice];
	if (self != nil)	{
		MTLRenderPassColorAttachmentDescriptor		*attachDesc = self.renderPassDescriptor.colorAttachments[0];
		attachDesc.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
		//attachDesc.loadAction = MTLLoadActionDontCare;
		attachDesc.loadAction = MTLLoadActionClear;
		//attachDesc.loadAction = MTLLoadActionLoad;
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			selector:@selector(compModeReloadNotification:)
			name:kMSLCompModeReloadNotificationName
			object:nil];
		[self compModeReloadNotification:nil];
	}
	return self;
}
- (void) dealloc	{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kMSLCompModeReloadNotificationName object:nil];
}


- (void) compModeReloadNotification:(NSNotification *)note	{
	//	INTENTIONALLY BLANK- subclass me to grab the context-appropriate MSLCompModeResourceController
}


#pragma mark - frontend


- (BOOL) renderRecipe:(MSLCompModeRecipe *)inRecipe inCanvasBounds:(NSRect)inCanvasBounds toTexture:(id<VVMTLTextureImage>)inTex inCommandBuffer:(id<MTLCommandBuffer>)cb	{
	if (inRecipe == nil)	{
		NSLog(@"ERR: recipe nil, %s",__func__);
		return NO;
	}
	if (inTex == nil)	{
		NSLog(@"ERR: tex nil, %s",__func__);
		return NO;
	}
	
	self.recipe = inRecipe;
	if (!NSEqualRects(self.canvasBounds, inCanvasBounds))	{
		self.canvasBounds = inCanvasBounds;
		self.mvpBuffer = nil;
	}
	
	[self renderToTexture:inTex inCommandBuffer:cb];
	
	return YES;
}
- (BOOL) renderBlackFrameToTexture:(id<VVMTLTextureImage>)inTex inCommandBuffer:(id<MTLCommandBuffer>)cb	{
	//	configure the render pass descriptor to use the attachment texture
	MTLRenderPassColorAttachmentDescriptor		*attachDesc = self.renderPassDescriptor.colorAttachments[0];
	attachDesc.texture = inTex.texture;
	
	//	make a render encoder
	id<MTLRenderCommandEncoder>		renderEncoder = [cb renderCommandEncoderWithDescriptor:self.renderPassDescriptor];
	
	//	configure the viewport
	CGSize			tmpSize = inTex.size;
	[renderEncoder setViewport:(MTLViewport){ 0.f, 0.f, tmpSize.width, tmpSize.height, -1.f, 1.f }];
	
	//	set the pipeline state
	if (self.renderPSO != nil)
		[renderEncoder setRenderPipelineState:self.renderPSO];
	
	[renderEncoder endEncoding];
	return YES;
}


#pragma mark - superclass overrides


- (void) renderCallback	{
	//	INTENTIONALLY BLANK- subclasses need to override me and put rendering code in here!
}

@end
