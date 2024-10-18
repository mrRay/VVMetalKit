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

@property (strong) NSMutableArray<MTLCommandBufferHandler> * transitiveScheduledHandlers;
@property (strong) NSMutableArray<MTLCommandBufferHandler> * transitiveCompletedHandlers;

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
		self.renderSize = CGSizeMake(40,30);
		self.colorSpace = RenderProperties.global.colorSpace;
		
		self.transitiveScheduledHandlers = [[NSMutableArray alloc] init];
		self.transitiveCompletedHandlers = [[NSMutableArray alloc] init];
	}
	return self;
}
- (void) dealloc	{
	self.device = nil;
	self.commandBuffer = nil;
	self.renderTarget = nil;
	self.transitiveScheduledHandlers = nil;
	self.transitiveCompletedHandlers = nil;
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
- (id<VVMTLTextureImage>) createAndRenderWithDepthToTextureSized:(NSSize)inSize inCommandBuffer:(id<MTLCommandBuffer>)cb	{
	VVMTLPool			*pool = [VVMTLPool global];
	if (pool == nil)
		return nil;
	
	id<VVMTLTextureImage>		returnMe = [pool bgra8TexSized:inSize];
	if (returnMe == nil)
		return nil;
	id<VVMTLTextureImage>		tmpDepth = [pool depthTexSized:inSize];
	[self renderToTexture:returnMe depthBuffer:tmpDepth inCommandBuffer:cb];
	return returnMe;
}
- (void) renderToTexture:(id<VVMTLTextureImage>)n inCommandBuffer:(id<MTLCommandBuffer>)cb	{
	[self renderToTexture:n depthBuffer:nil inCommandBuffer:cb];
}
- (void) renderToTexture:(id<VVMTLTextureImage>)n depthBuffer:(id<VVMTLTextureImage>)d inCommandBuffer:(id<MTLCommandBuffer>)cb	{
	self.renderSize = (n==nil) ? CGSizeMake(1,1) : CGSizeMake(n.width, n.height);
	
	self.renderTarget = n;
	self.depthTarget = d;
	self.commandBuffer = cb;
	
	[self _renderCallback];
	
	self.commandBuffer = nil;
	self.depthTarget = nil;
	self.renderTarget = nil;
}


- (void) _renderCallback	{
	//	setup for render
	[self _renderSetup];
	
	//	execute the render callback- this is where subclasses do their rendering
	[self renderCallback];
	
	//	teardown after render
	[self _renderTeardown];
}
- (void) _renderSetup	{
	//	if there are any transitive scheduled/completed blocks, add them to the command buffer
	if (self.transitiveScheduledHandlers.count > 0)	{
		NSEnumerator		*it = [self.transitiveScheduledHandlers objectEnumerator];
		MTLCommandBufferHandler		handler = [it nextObject];
		while (handler != nil)	{
			[self.commandBuffer addScheduledHandler:handler];
			handler = [it nextObject];
		}
		[self.transitiveScheduledHandlers removeAllObjects];
	}
	if (self.transitiveCompletedHandlers.count > 0)	{
		NSEnumerator		*it = [self.transitiveCompletedHandlers objectEnumerator];
		MTLCommandBufferHandler		handler = [it nextObject];
		while (handler != nil)	{
			[self.commandBuffer addCompletedHandler:handler];
			handler = [it nextObject];
		}
		[self.transitiveCompletedHandlers removeAllObjects];
	}
}
- (void) _renderTeardown	{

}


//@synthesize renderSize=_renderSize;
//- (void) setRenderSize:(NSSize)n	{
//	_renderSize = n;
//}
//- (NSSize) renderSize	{
//	return renderSize;
//}


- (void) renderCallback	{
	//	intentionally blank- subclasses must implement their own render callbacks
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


- (void) addScheduledHandler:(MTLCommandBufferHandler)n	{
	if (self.commandBuffer == nil)
		[self.transitiveScheduledHandlers addObject:n];
	else
		[self.commandBuffer addScheduledHandler:n];
}
- (void) addCompletedHandler:(MTLCommandBufferHandler)n	{
	if (self.commandBuffer == nil)
		[self.transitiveCompletedHandlers addObject:n];
	else
		[self.commandBuffer addCompletedHandler:n];
}


@end
