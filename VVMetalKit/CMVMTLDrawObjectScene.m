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
		
		self.renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
		self.renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
		
		NSError				*nsErr = nil;
		NSBundle			*myBundle = [NSBundle bundleForClass:[CustomMetalView class]];
		id<MTLLibrary>		defaultLibrary = [inDevice newDefaultLibraryWithBundle:myBundle error:&nsErr];
		id<MTLFunction>		vertFunc = [defaultLibrary newFunctionWithName:@"CustomMetalViewVertShader"];
		id<MTLFunction>		fragFunc = [defaultLibrary newFunctionWithName:@"CustomMetalViewFragShader"];
		
		self.renderPSODesc.label = @"CMVMTLDrawObjectScene";
		self.renderPSODesc.vertexFunction = vertFunc;
		self.renderPSODesc.fragmentFunction = fragFunc;
		self.renderPSODesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
		
	}
	return self;
}

- (void) renderCallback	{
	[super renderCallback];
	
	CMVMTLDrawObject		*localDrawObject = self.drawObject;
	if (localDrawObject != nil)	{
		//[localDrawObject executeInRenderEncoder:self.renderEncoder commandBuffer:self.commandBuffer];
		
		id<MTLFunction>		localFragFunc = self.renderPSODesc.fragmentFunction;
		id<MTLArgumentEncoder>		argEncoder = [localFragFunc newArgumentEncoderWithBufferIndex:CMV_FS_Idx_Tex];
		[localDrawObject executeInRenderEncoder:self.renderEncoder textureArgumentEncoder:argEncoder commandBuffer:self.commandBuffer];
		localDrawObject = nil;
	}
}

- (void) _loadPSO	{
	[super _loadPSO];
	NSError		*nsErr = nil;
	self.renderPSO = [self.device newRenderPipelineStateWithDescriptor:self.renderPSODesc error:&nsErr];
}

@end
