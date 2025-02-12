//#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <TargetConditionals.h>
#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#endif
#import <simd/simd.h>
#import <VVMetalKit/CustomMetalViewShaderTypes.h>

@class CustomMetalView;

NS_ASSUME_NONNULL_BEGIN




@protocol CustomMetalViewDelegate
- (void) redrawView:(CustomMetalView *)n;
@end




@interface CustomMetalView : 
#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
UIView
#else
NSView
#endif
<CALayerDelegate>	{
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

- (void) setDevice:(id<MTLDevice>)n;

@property (weak) IBOutlet id<CustomMetalViewDelegate> delegate;

@property (readwrite) MTLPixelFormat pixelFormat;
@property (readwrite,nullable) CGColorSpaceRef colorspace;

//	set it to nil and any pixels with an alpha < 1 in the layer will be composited as transparent in the window hierarchy
@property (strong,nullable) NSColor * layerBackgroundColor;

//	isn't used to do anything by the backend, but is set to YES every time reconfigureDrawable is called.  if you want to throttle drawing- as opposed to just drawing every time your proc hits- you should use this property to flag the image as needing redraw and check the flag to determine when to redraw.
@property (readwrite) BOOL contentNeedsRedraw;

//	call this method to cause this view to draw itself
- (void) drawInCmdBuffer:(id<MTLCommandBuffer>)cmdBuffer;

//	returns a YES if the dimensions of the drawable have changed
- (BOOL) reconfigureDrawable;
- (void) renderToCommandBuffer:(id<MTLCommandBuffer>)n;

@property (readonly) NSSize viewportSize;
@property (readonly) NSRect viewportBounds;	//	calculated at runtime from 'viewportSize', which is updated every time the drawable is reconfigured.

@property (readonly) double localToBackingBoundsMultiplier;

//	local, thread-safe version of NSView's 'boundsRotation' property (and other properties)
@property (atomic,readwrite) CGFloat localBoundsRotation;
@property (atomic,readwrite) NSRect localBounds;
@property (atomic,readwrite) NSRect localBackingBounds;
@property (atomic,readwrite) NSRect localFrame;
//@property (atomic,readwrite) NSSize localFrameSize;
@property (atomic,readwrite,weak) NSWindow * localWindow;
@property (atomic,readwrite) BOOL localHidden;
@property (atomic,readwrite) NSRect localVisibleRect;	//	updated on setNeedsDisplay and on changes to bounds or frame
- (NSRect) convertRectToLocalBackingBounds:(NSRect)n;

@end




NS_ASSUME_NONNULL_END
