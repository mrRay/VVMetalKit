#import "MTLScene.h"

#import "MTLImgBuffer.h"
#import "MTLPool.h"




#import "MTLScene_priv.h"




@interface MTLScene ()

@property (strong) NSMutableArray<MTLCommandBufferHandler> * transitiveScheduledHandlers;
@property (strong) NSMutableArray<MTLCommandBufferHandler> * transitiveCompletedHandlers;

@end




@implementation MTLScene


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


- (MTLImgBuffer *) createAndRenderToBufferSized:(CGSize)inSize inCommandBuffer:(id<MTLCommandBuffer>)cb	{
	MTLPool			*pool = [MTLPool global];
	if (pool == nil)
		return nil;
	
	MTLImgBuffer		*returnMe = [pool bgra8TexSized:inSize];
	if (returnMe == nil)
		return nil;
	[self renderToBuffer:returnMe inCommandBuffer:cb];
	return returnMe;
}
- (void) renderToBuffer:(MTLImgBuffer *)n inCommandBuffer:(id<MTLCommandBuffer>)cb	{
	self.renderSize = (n==nil) ? CGSizeMake(1,1) : CGSizeMake(n.width, n.height);
	
	self.renderTarget = n;
	self.commandBuffer = cb;
	
	[self _renderCallback];
	
	self.commandBuffer = nil;
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
//- (void) setRenderSize:(CGSize)n	{
//	_renderSize = n;
//}
//- (CGSize) renderSize	{
//	return renderSize;
//}


- (void) renderCallback	{
	//	intentionally blank- subclasses must implement their own render callbacks
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
