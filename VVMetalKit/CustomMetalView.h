//#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#endif
#import <simd/simd.h>

@class CustomMetalView;

NS_ASSUME_NONNULL_BEGIN




@protocol CustomMetalViewDelegate
- (void) redrawView:(CustomMetalView *)n;
@end




@interface CustomMetalView : 
#if TARGET_OS_IOS
UIView
#else
NSView
#endif
<CALayerDelegate>	{
	id<MTLDevice>			device;
	MTLRenderPassDescriptor			*passDescriptor;
	id<MTLRenderPipelineState>		_pso;
	vector_uint2			viewportSize;
	CAMetalLayer			*metalLayer;
	id<CAMetalDrawable>		currentDrawable;
}

- (void) generalInit;

- (void) setDevice:(id<MTLDevice>)n;

@property (weak) IBOutlet id<CustomMetalViewDelegate> delegate;

@property (readwrite) MTLPixelFormat pixelFormat;
@property (readwrite,nullable) CGColorSpaceRef colorspace;

//	isn't used to do anything by the backend, but is set to YES every time reconfigureDrawable is called.  if you want to throttle drawing- as opposed to just drawing every time your proc hits- you should use this property to flag the image as needing redraw and check the flag to determine when to redraw.
@property (readwrite) BOOL contentNeedsRedraw;

//	call this method to cause this view to draw itself
- (void) drawInCmdBuffer:(id<MTLCommandBuffer>)cmdBuffer;

//	returns a YES if the dimensions of the drawable have changed
- (BOOL) reconfigureDrawable;
- (void) renderToCommandBuffer:(id<MTLCommandBuffer>)n;

@end




NS_ASSUME_NONNULL_END
