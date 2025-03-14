#import <Metal/Metal.h>
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <simd/simd.h>
#import <VVMetalKit/CustomMetalViewShaderTypes.h>

@class CustomMetalView;

NS_ASSUME_NONNULL_BEGIN




///	Delegates of CustomMetalView should conform to this protocol.  CustomMetalView instances don't _need_ a delegate to do any drawing, but this code pattern is more convenient for some interaction models.
@protocol CustomMetalViewDelegate
///	This delegate method is called whenever the associated view wants to have its content redraw as a result of external modification (such as setNeedsDisplay:YES, a frame/bounds/backing change, etc)
- (void) redrawView:(CustomMetalView *)n;
@end




/**		NSView subclass that does Metal drawing.
		- Kinda like MTKView, but you have control over every aspect of it because you have access to the source.
		- Has thread-safe properties useful for configuring drawing- these properties are typically unavailable outside the main thread because of AppKit limitations
*/




@interface CustomMetalView : NSView <CALayerDelegate>	{
	@public
	id<MTLDevice>			device;
	MTLRenderPassDescriptor			*passDescriptor;
	MTLRenderPipelineDescriptor		*psoDesc;
	id<MTLRenderPipelineState>		pso;
	vector_uint2			viewportSize;
	CAMetalLayer			*metalLayer;
	id<CAMetalDrawable>		currentDrawable;
}

- (void) generalInit;

///	You MUST set the view's device to a valid value or it won't draw!
- (void) setDevice:(id<MTLDevice>)n;

///	Sets the view's delegate.
@property (weak) IBOutlet id<CustomMetalViewDelegate> delegate;

///	The color attachment for the view will use this pixel format.
@property (readwrite) MTLPixelFormat pixelFormat;
///	The view will draw using this colorspace- defaults to `RenderProperties.global.colorspace`, so it may be more convenient to set that property on app init and then let views pick up the value from there.
@property (readwrite,nullable) CGColorSpaceRef colorspace;

///	Set it to nil and any pixels with an alpha < 1 in the layer will be composited as transparent in the window hierarchy
@property (strong,nullable) NSColor * layerBackgroundColor;

///	Isn't used to do anything by the backend, but is set to YES every time reconfigureDrawable is called.  If you want to throttle drawing- as opposed to just drawing every time your proc hits- you should use this property to flag the image as needing redraw and check the flag to determine when to redraw.
@property (readwrite) BOOL contentNeedsRedraw;

///	Call this method to cause this view to draw itself
- (void) drawInCmdBuffer:(id<MTLCommandBuffer>)cmdBuffer;

///	Returns a YES if the dimensions of the drawable have changed- causes the view bounds and local-to-backing-bounds multiplier to be recalculated.
- (BOOL) reconfigureDrawable;

///	The viewport size takes into account the local-to-backing-bounds multiplier, which allows instances of this class to draw higher-res content on retina screens.
@property (readonly) NSSize viewportSize;
///	Calculated at runtime from 'viewportSize', which is updated every time the drawable is reconfigured.
@property (readonly) NSRect viewportBounds;

///	On non-retina screens, this is 1.0.  On retina screens (or screens displaying a lower apparent resolution than native), this is a value > 1.0.
@property (readonly) double localToBackingBoundsMultiplier;

///	Local, thread-safe version of NSView's 'boundsRotation' property.
@property (atomic,readwrite) CGFloat localBoundsRotation;
///	Local, thread-safe version of NSView's `bounds` property.
@property (atomic,readwrite) NSRect localBounds;
///	Local, thread-safe version of NSView's `backingBounds` property.
@property (atomic,readwrite) NSRect localBackingBounds;
///	Local, thread-safe version of NSView's `frame` property.
@property (atomic,readwrite) NSRect localFrame;
///	Local, thread-safe version of NSView's `window` property.
@property (atomic,readwrite,weak) NSWindow * localWindow;
///	Local, thread-safe version of NSView's `hidden` property.
@property (atomic,readwrite) BOOL localHidden;
///	Local, thread-safe version of NSView's `visibleRect` property.
@property (atomic,readwrite) NSRect localVisibleRect;	//	updated on setNeedsDisplay and on changes to bounds or frame
///	Local, thread-safe version of NSView's `convertRectToBacking:` method.
- (NSRect) convertRectToLocalBackingBounds:(NSRect)n;

@end




NS_ASSUME_NONNULL_END
