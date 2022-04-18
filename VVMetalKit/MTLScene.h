#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

@class MTLImgBuffer;

NS_ASSUME_NONNULL_BEGIN




@interface MTLScene : NSObject	{
	CGSize			renderSize;
}

- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice;

- (MTLImgBuffer *) createAndRenderToBufferSized:(CGSize)inSize inCommandBuffer:(id<MTLCommandBuffer>)cb;
- (void) renderToBuffer:(MTLImgBuffer *)n inCommandBuffer:(id<MTLCommandBuffer>)cb;

/*		do all the rendering here.  when this method is called on a subclass, a pass 
descriptor and render encoder MUST already exist and have been configured.  do NOT end 
encoding or commit the cmd buffer in this method.			*/
- (void) renderCallback;

//	subclasses may want to override at least _renderSetup.  create vertex/MVP buffers in here in render scenes.  always call super.
- (void) _renderSetup;
- (void) _renderTeardown;

@property (readonly,nonatomic) id<MTLDevice> device;
@property (readonly,nonatomic) id<MTLCommandBuffer> commandBuffer;
@property (strong) NSString * label;

@property (readonly,nonatomic) MTLImgBuffer * renderTarget;
@property (readwrite,nonatomic) CGSize renderSize;

- (void) addScheduledHandler:(MTLCommandBufferHandler)n;
- (void) addCompletedHandler:(MTLCommandBufferHandler)n;

@end




NS_ASSUME_NONNULL_END
