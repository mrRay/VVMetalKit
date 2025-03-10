#import "CustomMetalView.h"

#import "RenderProperties.h"




@interface CustomMetalView ()
@property (readwrite) double localToBackingBoundsMultiplier;
@end




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
	_localToBackingBoundsMultiplier = 1.0;
	viewportSize = simd_make_uint2(1,1);
	
	metalLayer = [CAMetalLayer layer];
	//metalLayer.maximumDrawableCount = 2;
	//metalLayer.framebufferOnly = true;
	//NSLog(@"\t\tmetalLayer is now %@",metalLayer);
	
	passDescriptor = [MTLRenderPassDescriptor new];
	passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
	passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
	passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
	currentDrawable = nil;
	
	//self.pixelFormat = MTLPixelFormatRGBA32Float;	//	doesn't work (throws exception, invalid pixel format)
	self.pixelFormat = MTLPixelFormatBGRA8Unorm;
	//self.pixelFormat = MTLPixelFormatRGB10A2Unorm;	//	used this for a long time
	
	self.colorspace = RenderProperties.global.colorSpace;
	
	self.wantsLayer = YES;
	//self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
	self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawCrossfade;
	self.layer = metalLayer;
	//[self.layer addSublayer:metalLayer];	//	doesn't work!
	
	self.layer.delegate = self;
	
	pso = nil;
	
	//	this makes the view "transparent" (areas with alpha of 0 will show the background of the enclosing view)
	self.layerBackgroundColor = nil;
	//self.layerBackgroundColor = [NSColor colorWithDeviceRed:0. green:0. blue:0. alpha:1.];
	
	self.localBoundsRotation = self.boundsRotation;
	self.localBounds = self.bounds;
	self.localFrame = self.frame;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.bounds];
	self.localWindow = self.window;
	self.localHidden = self.hidden;
	self.localVisibleRect = self.visibleRect;
}
- (void) awakeFromNib	{
	self.colorspace = RenderProperties.global.colorSpace;
}
- (void) dealloc	{
	//NSLog(@"%s ... %@",__func__,self);
	self.colorspace = NULL;
}


#pragma mark - superclass overrides


+ (Class) layerClass	{
	//return [super layerClass];
	return [CAMetalLayer class];
}
//- (void) viewDidMoveToWindow	{
//	[super viewDidMoveToWindow];
//	[self reconfigureDrawable];
//	
//	if (self.delegate != nil)
//		[self.delegate redrawView:self];
//}
//- (void) viewDidChangeBackingProperties	{
//	//NSLog(@"%s ... %@",__func__,self);
//	[super viewDidChangeBackingProperties];
//	[self reconfigureDrawable];
//	
//	if (self.delegate != nil)
//		[self.delegate redrawView:self];
//}
- (void) setFrameSize:(NSSize)n	{
	[super setFrameSize:n];
	[self reconfigureDrawable];
	
	if (self.delegate != nil)
		[self.delegate redrawView:self];
}
//- (void) setBoundsSize:(NSSize)n	{
//	[super setBoundsSize:n];
//	[self reconfigureDrawable];
//	
//	if (self.delegate != nil)
//		[self.delegate redrawView:self];
//}


- (BOOL) isOpaque	{
	if (self.layerBackgroundColor == nil)
		return NO;
	return YES;
}
- (CALayer *) makeBackingLayer	{
	return [CAMetalLayer layer];
}

- (void) viewDidChangeBackingProperties	{
	//NSLog(@"%s ... %@",__func__,self);
	[super viewDidChangeBackingProperties];
	
	[self reconfigureDrawable];
	
	self.localBounds = self.bounds;
	self.localFrame = self.frame;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
	[self setNeedsDisplay:YES];
	//if (self.delegate != nil)
	//	[self.delegate redrawView:self];
}
- (void)viewDidMoveToWindow	{
	//NSLog(@"%s ... %@",__func__,self);
	
	[super viewDidMoveToWindow];
	[self reconfigureDrawable];
	
	self.localWindow = self.window;
	self.localVisibleRect = self.visibleRect;
	
	[self updateTrackingAreas];
	
	[self setNeedsDisplay:YES];
	//if (self.delegate != nil)
	//	[self.delegate redrawView:self];
}
- (void) updateTrackingAreas	{
	[super updateTrackingAreas];
	
	self.localBounds = self.bounds;
	self.localFrame = self.frame;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
}

- (void) setBoundsRotation:(CGFloat)n	{
	[super setBoundsRotation:n];
	self.localBoundsRotation = self.boundsRotation;
	self.localVisibleRect = self.visibleRect;
}
- (void) setBounds:(NSRect)n	{
	[super setBounds:n];
	self.localBounds = self.bounds;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
}
- (void) setBoundsOrigin:(NSPoint)n	{
	[super setBoundsOrigin:n];
	self.localBounds = self.bounds;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
}
- (void) setBoundsSize:(NSSize)n	{
	[super setBoundsSize:n];
	[self reconfigureDrawable];
	self.localBounds = self.bounds;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
	
	[self setNeedsDisplay:YES];
	//if (self.delegate != nil)
	//	[self.delegate redrawView:self];
}
- (void) setFrame:(NSRect)n	{
	[super setFrame:n];
	self.localBounds = self.bounds;
	self.localFrame = self.frame;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
}
- (void) viewWillMoveToWindow:(NSWindow *)n	{
	//NSLog(@"%s",__func__);
	self.localWindow = n;
	self.localVisibleRect = self.visibleRect;
	[super viewWillMoveToWindow:n];
}
- (void) setHidden:(BOOL)n	{
	[super setHidden:n];
	self.localHidden = self.hidden;
	self.localVisibleRect = self.visibleRect;
}
//@synthesize needsDisplay=myNeedsDisplay;
- (void) setNeedsDisplay:(BOOL)n	{
	//myNeedsDisplay = n;
	if (n)	{
		self.contentNeedsRedraw = YES;
		self.localVisibleRect = self.visibleRect;
	}
	[super setNeedsDisplay:n];
	if (n && self.delegate != nil)
		[self.delegate redrawView:self];
}
- (void) setNeedsDisplayInRect:(NSRect)n	{
	self.contentNeedsRedraw = YES;
	self.localVisibleRect = self.visibleRect;
	[super setNeedsDisplayInRect:n];
	if (self.delegate != nil)
		[self.delegate redrawView:self];
}
- (NSRect) convertRectToLocalBackingBounds:(NSRect)n	{
	return NSMakeRect(n.origin.x*_localToBackingBoundsMultiplier,n.origin.y*_localToBackingBoundsMultiplier,n.size.width*_localToBackingBoundsMultiplier,n.size.height*_localToBackingBoundsMultiplier);
}


#pragma mark - backend


- (void) setDevice:(id<MTLDevice>)n	{
	device = n;
	
	metalLayer.device = device;
	
	metalLayer.pixelFormat = self.pixelFormat;
	
	if (self.colorspace != NULL)
		metalLayer.colorspace = self.colorspace;
	
	//	subclasses should override this method, call the super, and then make the pso here.  it would look something like this:
	/*
	NSError				*nsErr = nil;
	NSBundle			*myBundle = [NSBundle bundleForClass:[CustomMetalView class]];
	id<MTLLibrary>		defaultLibrary = [device newDefaultLibraryWithBundle:myBundle error:&nsErr];
	id<MTLFunction>		vertFunc = [defaultLibrary newFunctionWithName:@"CustomMetalViewVertShader"];
	id<MTLFunction>		fragFunc = [defaultLibrary newFunctionWithName:@"CustomMetalViewFragShader"];

	psoDesc = [[MTLRenderPipelineDescriptor alloc] init];
	psoDesc.vertexFunction = vertFunc;
	psoDesc.fragmentFunction = fragFunc;
	psoDesc.colorAttachments[0].pixelFormat = metalLayer.pixelFormat;
	
	//	commented out- this was an attempt to make VVMTLTextureImageRectView "transparent" (0 alpha would display view behind it)
	psoDesc.alphaToCoverageEnabled = NO;
	psoDesc.colorAttachments[0].blendingEnabled = YES;
	
	psoDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
	psoDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
	
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
	
	pso = [device newRenderPipelineStateWithDescriptor:psoDesc error:&nsErr];
	*/
}
- (void) drawInCmdBuffer:(id<MTLCommandBuffer>)cmdBuffer	{
	//	intentionally blank, override this in your subclass
	//	IMPORTANT NOTE:
	//	always include the following line in your subclass overrides of this method:
	//self.contentNeedsRedraw = NO;
}
- (BOOL) reconfigureDrawable	{
	//NSLog(@"%s ... %@",__func__,self);
	
	//	we have to find the screen our window is on (so we can get its pixel density)...but there's a catch: 
	//	if the window isn't open, calling "self.window.screen" returns nil- even though the window has a 
	//	frame and can figure out what screen it's on.  so: if we can't find the screen, we work around this 
	//	by comparing the window and screen bounds and locating the screen manually.
	NSWindow		*tmpWin = self.window;
	NSScreen		*tmpScreen = tmpWin.screen;
	if (tmpScreen == nil)	{
		
		//	...this was lifted verbatim from VVCore's NSScreenAdditions, i just don't want to add the dependency and it's simple enough...
		NSScreen* (^ScreenForWindowFrame)(NSRect) = ^(NSRect n)	{
			//NSLog(@"%s ... %@",__func__,NSStringFromRect(n));
			if (n.size.width == 0. && n.size.height == 0.)
				return (NSScreen*)nil;
			
			NSMutableArray<NSScreen*>		*overlappedScreens = [NSMutableArray new];
			NSMutableArray<NSNumber*>		*overlappedScreenAmounts = [NSMutableArray new];
			
			for (NSScreen * screen in [NSScreen screens])	{
				NSRect		screenFrame = screen.frame;
				//NSLog(@"\t\tscreenFrame is %@",NSStringFromRect(screenFrame));
				NSRect		overlap = NSIntersectionRect(n, screenFrame);
				//NSLog(@"\t\toverlap is %@",NSStringFromRect(overlap));
				if (overlap.size.width==0. && overlap.size.height==0.)
					continue;
				[overlappedScreens addObject:screen];
				[overlappedScreenAmounts addObject:@( (overlap.size.width * overlap.size.height)/(n.size.width * n.size.height) )];
			}
			
			if (overlappedScreens.count < 1)
				return (NSScreen*)nil;
			NSScreen			*mainScreen = nil;
			NSNumber			*mainScreenAmount = nil;
			NSEnumerator		*screenIt = [overlappedScreens objectEnumerator];
			NSEnumerator		*screenAmountIt = [overlappedScreenAmounts objectEnumerator];
			NSScreen			*screenPtr = [screenIt nextObject];
			NSNumber			*screenAmountPtr = [screenAmountIt nextObject];
			while (screenPtr != nil && screenAmountPtr != nil)	{
				if (mainScreen == nil)	{
					mainScreen = screenPtr;
					mainScreenAmount = screenAmountPtr;
				}
				else	{
					if (screenAmountPtr.doubleValue > mainScreenAmount.doubleValue)	{
						mainScreen = screenPtr;
						mainScreenAmount = screenAmountPtr;
					}
				}
				
				screenPtr = [screenIt nextObject];
				screenAmountPtr = [screenAmountIt nextObject];
			}
			
			return mainScreen;
		};
		
		tmpScreen = ScreenForWindowFrame(tmpWin.frame);
	}
	
	if (tmpScreen == nil)	{
		self.localToBackingBoundsMultiplier = 1.0;
		return YES;
	}
	
	CGFloat			scale = tmpScreen.backingScaleFactor;
	self.localToBackingBoundsMultiplier = scale;
	
	//NSLog(@"\t\tscreen is %@, window is %@, scale is %0.2f", self.window.screen, self.window, scale);
	
	//NSLog(@"\t\tbounds are %@",NSStringFromRect(self.bounds));
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


@synthesize colorspace=_colorspace;
- (void) setColorspace:(CGColorSpaceRef)n	{
	if (_colorspace != NULL)
		CGColorSpaceRelease(_colorspace);
	_colorspace = (n==NULL) ? NULL : CGColorSpaceRetain(n);
	
	metalLayer.colorspace = n;
}
- (CGColorSpaceRef) colorspace	{
	return _colorspace;
}


- (NSSize) viewportSize	{
	return NSMakeSize( viewportSize[0], viewportSize[1] );
}
- (NSRect) viewportBounds	{
	return NSMakeRect(0,0,viewportSize[0],viewportSize[1]);
}


@synthesize layerBackgroundColor=_layerBackgroundColor;
- (void) setLayerBackgroundColor:(NSColor *)n	{
	_layerBackgroundColor = [n colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
	
	if (_layerBackgroundColor == nil)	{
		//	this makes the view "transparent" (areas with alpha of 0 will show the background of the enclosing view)
		self.layer.opaque = NO;
		self.layer.backgroundColor = [[NSColor clearColor] CGColor];
		passDescriptor = [MTLRenderPassDescriptor new];
		passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
		passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
		passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
	}
	else	{
		self.layer.opaque = YES;
		CGFloat			components[8];
		[_layerBackgroundColor getComponents:components];
		//NSLog(@"\t\tcolor was %@, comps are %0.2f, %0.2f, %0.2f",_layerBackgroundColor,components[0],components[1],components[2]);
		self.layer.backgroundColor = [_layerBackgroundColor CGColor];
		passDescriptor = [MTLRenderPassDescriptor new];
		passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
		passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake( components[0], components[1], components[2], components[3] );
		passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
	}
}
- (NSColor *) layerBackgroundColor	{
	return _layerBackgroundColor;
}


@end
