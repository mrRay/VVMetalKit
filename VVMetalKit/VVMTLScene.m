//
//  VVMTLScene.m
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import "VVMTLScene.h"

//#import "VVMTLTextureImage.h"
#import "VVMTLPool.h"
#import "RenderProperties.h"




#import "VVMTLScene_priv.h"




@interface VVMTLScene ()

- (void) _renderCallback;

@end




@implementation VVMTLScene


- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice	{
	self = [super init];
	if (inDevice == nil)	{
		self = nil;
	}
	if (self != nil)	{
		self.device = inDevice;
		self.commandBuffer = nil;
		self.renderTarget = nil;
		self.depthTarget = nil;
		self.msaaTarget = nil;
		self.renderSize = CGSizeMake(40,30);
		self.msaaSampleCount = 1;
		self.colorSpace = RenderProperties.global.colorSpace;
	}
	return self;
}
- (void) dealloc	{
	self.device = nil;
	self.commandBuffer = nil;
	self.renderTarget = nil;
	self.depthTarget = nil;
	self.msaaTarget = nil;
}


- (id<VVMTLTextureImage>) createAndRenderToTextureSized:(NSSize)inSize inCommandBuffer:(id<MTLCommandBuffer>)cb	{
	VVMTLPool			*pool = [VVMTLPool global];
	if (pool == nil)
		return nil;
	
	id<VVMTLTextureImage>		returnMe = [pool bgra8TexSized:inSize];
	if (returnMe == nil)
		return nil;
	[self renderToTexture:returnMe inCommandBuffer:cb];
	return returnMe;
}
- (id<VVMTLTextureImage>) createAndRenderWithDepth:(BOOL)inDepth toTextureSized:(NSSize)inSize inCommandBuffer:(id<MTLCommandBuffer>)cb	{
	VVMTLPool			*pool = [VVMTLPool global];
	if (pool == nil)
		return nil;
	
	id<VVMTLTextureImage>		returnMe = [pool bgra8TexSized:inSize];
	if (returnMe == nil)
		return nil;
	NSUInteger		sampleCount = self.msaaSampleCount;
	id<VVMTLTextureImage>		tmpDepth = (!inDepth) ? nil : [pool depthTexSized:inSize sampleCount:sampleCount];
	id<VVMTLTextureImage>		tmpMSAA = (sampleCount<=1) ? nil : [pool bgra8TexSized:inSize sampleCount:sampleCount];
	[self renderToTexture:returnMe depthBuffer:tmpDepth msaa:tmpMSAA inCommandBuffer:cb];
	tmpMSAA = nil;
	tmpDepth = nil;
	return returnMe;
}
- (void) renderToTexture:(id<VVMTLTextureImage>)n inCommandBuffer:(id<MTLCommandBuffer>)cb	{
	[self renderToTexture:n depthBuffer:nil msaa:nil inCommandBuffer:cb];
}
- (void) renderToTexture:(id<VVMTLTextureImage>)n depthBuffer:(id<VVMTLTextureImage>)d msaa:(nullable id<VVMTLTextureImage>)m inCommandBuffer:(id<MTLCommandBuffer>)cb	{
	if (n != nil)
		self.renderSize = CGSizeMake(n.width, n.height);
	
	self.renderTarget = n;
	self.depthTarget = d;
	self.msaaTarget = m;
	self.commandBuffer = cb;
	
	[self _renderCallback];
	
	self.commandBuffer = nil;
	self.msaaTarget = nil;
	self.depthTarget = nil;
	self.renderTarget = nil;
}


- (void) _loadPSO	{
	//	subclasses should put code in here that creates the new pipeline state object
	//	VVMTLScene doesn't have any PSOs of its own- only its subclasses (compute and render) have PSOs.
}
- (void) _renderCallback	{
	//	setup the PSO
	[self _loadPSO];
	
	//	setup for render
	[self _renderSetup];
	
	//	sublcasses render here
	[self renderCallback];
	
	//	teardown after render
	[self _renderTeardown];
}
- (void) _renderSetup	{
}
- (void) _renderTeardown	{

}


- (void) renderCallback	{
	//	intentionally blank- subclasses must implement their own render callbacks
}


@synthesize msaaSampleCount=_msaaSampleCount;
- (void) setMsaaSamplecount:(NSUInteger)n	{
	_msaaSampleCount = n;
}
- (NSUInteger) msaaSampleCount	{
	return _msaaSampleCount;
}


@synthesize colorSpace=_colorSpace;
- (void) setColorSpace:(CGColorSpaceRef)n	{
	if (_colorSpace != NULL)	{
		CGColorSpaceRelease(_colorSpace);
	}
	_colorSpace = n;
	if (_colorSpace != NULL)	{
		CGColorSpaceRetain(_colorSpace);
	}
}
- (CGColorSpaceRef) colorSpace	{
	return _colorSpace;
}


@end
