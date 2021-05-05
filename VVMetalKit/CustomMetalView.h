#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <Quartz/Quartz.h>
#import <simd/simd.h>

@class CustomMetalView;

NS_ASSUME_NONNULL_BEGIN




@protocol CustomMetalViewDelegate
- (void) redrawView:(CustomMetalView *)n;
@end




@interface CustomMetalView : NSView <CALayerDelegate>	{
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

//	call this method to cause this view to draw itself
- (void) drawInCmdBuffer:(id<MTLCommandBuffer>)cmdBuffer;

//	returns a YES if the dimensions of the drawable have changed
- (BOOL) reconfigureDrawable;
- (void) renderToCommandBuffer:(id<MTLCommandBuffer>)n;

@end




NS_ASSUME_NONNULL_END
