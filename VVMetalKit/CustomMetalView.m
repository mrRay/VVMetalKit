#import "CustomMetalView.h"
#import "TargetConditionals.h"
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif




@implementation CustomMetalView


#pragma mark - init/teardown


#if TARGET_OS_IOS
- (instancetype) initWithFrame:(CGRect)frame	{
	self = [super initWithFrame:frame];
	if (self != nil)	{
		[self generalInit];
	}
	return self;
}
#else
- (instancetype) initWithFrame:(NSRect)frame	{
	self = [super initWithFrame:frame];
	if (self != nil)	{
		[self generalInit];
	}
	return self;
}
#endif
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
	
	#if TARGET_OS_IOS
	metalLayer = (CAMetalLayer*)self.layer;
	#else
	metalLayer = [CAMetalLayer layer];
	//metalLayer.maximumDrawableCount = 2;
	//metalLayer.framebufferOnly = true;
	#endif
	//NSLog(@"\t\tmetalLayer is now %@",metalLayer);
	
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
	
	#if !TARGET_OS_IOS
	self.wantsLayer = YES;
	//self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
	self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawCrossfade;
	self.layer = metalLayer;
	//[self.layer addSublayer:metalLayer];	//	doesn't work!
	#endif
	
	self.layer.delegate = self;
	
	_pso = nil;
}
- (void) dealloc	{
	//NSLog(@"%s ... %@",__func__,self);
	self.colorspace = NULL;
}


#pragma mark - superclass overrides


#if TARGET_OS_IOS
+ (Class) layerClass	{
	//return [super layerClass];
	return [CAMetalLayer class];
}
#else
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
	if (n)
		self.contentNeedsRedraw = YES;
	[super setNeedsDisplay:n];
	if (n && self.delegate != nil)
		[self.delegate redrawView:self];
}
#endif


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
	//	intentionally blank, override this in your subclass
	//	IMPORTANT NOTE:
	//	always include the following line in your subclass overrides of this method:
	//self.contentNeedsRedraw = NO;
}
- (BOOL) reconfigureDrawable	{
	//NSLog(@"%s",__func__);
	#if TARGET_OS_IOS
	CGFloat			scale = self.window.screen.scale;
	#else
	CGFloat			scale = self.window.screen.backingScaleFactor;
	#endif
	//NSLog(@"\t\tscale is %0.2f",scale);
	
	//NSLog(@"\t\tbounds are %@",NSStringFromCGRect(self.bounds));
	CGSize			newSize = self.bounds.size;
	newSize.width *= scale;
	newSize.height *= scale;
	
	BOOL			returnMe = (newSize.width!=viewportSize.x || newSize.height!=viewportSize.y) ? YES : NO;
	
	metalLayer.drawableSize = newSize;
	viewportSize.x = newSize.width;
	viewportSize.y = newSize.height;
	
	self.contentNeedsRedraw = YES;
	
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
