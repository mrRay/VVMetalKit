//
//  CMVMTLDrawObjectScene.m
//  VVMetalKit
//
//  Created by testadmin on 11/12/24.
//

#import "CMVMTLDrawObjectScene.h"
#import "CustomMetalView.h"
#import "CMVMTLDrawObject.h"

@implementation CMVMTLDrawObjectScene

- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice	{
	self = [super initWithDevice:inDevice];
	if (self != nil)	{
		self.drawObject = nil;
		
		MTLRenderPassColorAttachmentDescriptor		*attachDesc = self.renderPassDescriptor.colorAttachments[0];
		attachDesc.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
		attachDesc.loadAction = MTLLoadActionDontCare;
		
		NSError				*nsErr = nil;
		NSBundle			*myBundle = [NSBundle bundleForClass:[CustomMetalView class]];
		id<MTLLibrary>		defaultLibrary = [inDevice newDefaultLibraryWithBundle:myBundle error:&nsErr];
		id<MTLFunction>		vertFunc = [defaultLibrary newFunctionWithName:@"CustomMetalViewVertShader"];
		id<MTLFunction>		fragFunc = [defaultLibrary newFunctionWithName:@"CustomMetalViewFragShader"];
		
		self.renderPSODesc.label = @"CMVMTLDrawObjectScene";
		self.renderPSODesc.vertexFunction = vertFunc;
		self.renderPSODesc.fragmentFunction = fragFunc;
		self.renderPSODesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
		
		self.renderPSO = [inDevice newRenderPipelineStateWithDescriptor:self.renderPSODesc error:&nsErr];
	}
	return self;
}

- (void) renderCallback	{
	[super renderCallback];
	
	CMVMTLDrawObject		*drawObject = self.drawObject;
	if (drawObject != nil)	{
		[drawObject executeInRenderEncoder:self.renderEncoder commandBuffer:self.commandBuffer];
		drawObject = nil;
	}
}

@end
