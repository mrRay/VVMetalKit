#import "CustomMetalView.h"




@implementation CustomMetalView


#pragma mark - init/teardown


- (instancetype) initWithFrame:(NSRect)frame	{
	self = [super initWithFrame:frame];
	if (self != nil)	{
		[self generalInit];
	}
	return self;
}
- (instancetype) initWithCoder:(NSCoder *)inCoder	{
	self = [super initWithCoder:inCoder];
	if (self != nil)	{
		[self generalInit];
	}
	return self;
}
- (void) generalInit	{
	//NSLog(@"%s ... %@",__func__,self);
	viewportSize = simd_make_uint2(1,1);
	
	metalLayer = [CAMetalLayer layer];
	//metalLayer.maximumDrawableCount = 2;
	//metalLayer.framebufferOnly = true;
	
	passDescriptor = [MTLRenderPassDescriptor new];
	passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
	passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
	passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
	currentDrawable = nil;
	
	//self.pixelFormat = MTLPixelFormatRGBA32Float;	//	doesn't work (throws exception, invalid pixel format)
	self.pixelFormat = MTLPixelFormatBGRA8Unorm;
	//self.pixelFormat = MTLPixelFormatRGB10A2Unorm;	//	used this for a long time
	
	CGColorSpaceRef		tmpSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
	self.colorspace = tmpSpace;
	if (tmpSpace != NULL)
		CGColorSpaceRelease(tmpSpace);
	
	self.wantsLayer = YES;
	self.layer = metalLayer;
	//[self.layer addSublayer:metalLayer];	//	doesn't work!
	//self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
	self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawCrossfade;
	
	self.layer.delegate = self;
	
	_pso = nil;
}
- (void) dealloc	{
	//NSLog(@"%s ... %@",__func__,self);
	self.colorspace = NULL;
}


#pragma mark - superclass overrides


- (void) viewDidMoveToWindow	{
	[super viewDidMoveToWindow];
	[self reconfigureDrawable];
	
	if (self.delegate != nil)
		[self.delegate redrawView:self];
}
- (void) viewDidChangeBackingProperties	{
	[super viewDidChangeBackingProperties];
	[self reconfigureDrawable];
	
	if (self.delegate != nil)
		[self.delegate redrawView:self];
}
- (void) setFrameSize:(NSSize)n	{
	[super setFrameSize:n];
	[self reconfigureDrawable];
	
	if (self.delegate != nil)
		[self.delegate redrawView:self];
}
- (void) setBoundsSize:(NSSize)n	{
	[super setBoundsSize:n];
	[self reconfigureDrawable];
	
	if (self.delegate != nil)
		[self.delegate redrawView:self];
}


//@synthesize needsDisplay=myNeedsDisplay;
- (void) setNeedsDisplay:(BOOL)n	{
	//myNeedsDisplay = n;
	[super setNeedsDisplay:n];
	if (n && self.delegate != nil)
		[self.delegate redrawView:self];
}


#pragma mark - backend


- (void) setDevice:(id<MTLDevice>)n	{
	device = n;
	
	metalLayer.device = device;
	
	metalLayer.pixelFormat = self.pixelFormat;
	
	if (self.colorspace != NULL)
		metalLayer.colorspace = self.colorspace;
	
	//	subclasses should override this method, call the super, and then make the pso here
}
- (void) drawInCmdBuffer:(id<MTLCommandBuffer>)cmdBuffer	{
}
- (BOOL) reconfigureDrawable	{
	//NSLog(@"%s",__func__);
	NSScreen		*screen = self.window.screen;
	CGFloat			scale = screen.backingScaleFactor;
	
	CGSize			newSize = self.bounds.size;
	newSize.width *= scale;
	newSize.height *= scale;
	
	BOOL			returnMe = (newSize.width!=viewportSize.x || newSize.height!=viewportSize.y) ? YES : NO;
	
	metalLayer.drawableSize = newSize;
	viewportSize.x = newSize.width;
	viewportSize.y = newSize.height;
	
	return returnMe;
}
- (void) renderToCommandBuffer:(id<MTLCommandBuffer>)n	{
}


#pragma mark - key-value overrides


@synthesize pixelFormat=myPixelFormat;
- (void) setPixelFormat:(MTLPixelFormat)n	{
	myPixelFormat = n;
	
	metalLayer.pixelFormat = n;
}
- (MTLPixelFormat) pixelFormat	{
	return myPixelFormat;
}
@synthesize colorspace=myColorspace;
- (void) setColorspace:(CGColorSpaceRef)n	{
	if (myColorspace != NULL)
		CGColorSpaceRelease(myColorspace);
	myColorspace = (n==NULL) ? NULL : CGColorSpaceRetain(n);
	
	metalLayer.colorspace = n;
}
- (CGColorSpaceRef) colorspace	{
	return myColorspace;
}


@end
