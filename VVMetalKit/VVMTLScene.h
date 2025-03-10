//
//  VVMTLScene.h
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <Cocoa/Cocoa.h>

#import <VVMetalKit/VVMTLTextureImage.h>

NS_ASSUME_NONNULL_BEGIN




@interface VVMTLScene : NSObject

- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice;

- (id<VVMTLTextureImage>) createAndRenderToTextureSized:(NSSize)inSize inCommandBuffer:(id<MTLCommandBuffer>)cb;
- (id<VVMTLTextureImage>) createAndRenderWithDepth:(BOOL)inDepth toTextureSized:(NSSize)inSize inCommandBuffer:(id<MTLCommandBuffer>)cb;
- (void) renderToTexture:(nullable id<VVMTLTextureImage>)n inCommandBuffer:(id<MTLCommandBuffer>)cb;
- (void) renderToTexture:(nullable id<VVMTLTextureImage>)n depthBuffer:(nullable id<VVMTLTextureImage>)d msaa:(nullable id<VVMTLTextureImage>)m inCommandBuffer:(id<MTLCommandBuffer>)cb;

/*		do all the rendering here.  when this method is called on a subclass, a pass 
descriptor and render encoder MUST already exist and have been configured.  do NOT end 
encoding or commit the cmd buffer in this method.			*/
- (void) renderCallback;

//	subclasses may want to override at least _renderSetup.  create vertex/MVP buffers in here in render scenes.  always call super.
- (void) _loadPSO;
- (void) _renderSetup;
- (void) _renderTeardown;

@property (readonly,nonatomic) id<MTLDevice> device;
@property (readonly,nonatomic) id<MTLCommandBuffer> commandBuffer;
@property (strong) NSString * label;

@property (readonly,nonatomic) id<VVMTLTextureImage> renderTarget;
@property (readonly,nonatomic) id<VVMTLTextureImage> depthTarget;
@property (readonly,nonatomic) id<VVMTLTextureImage> msaaTarget;
@property (readwrite,nonatomic) NSSize renderSize;
@property (readwrite,nonatomic) NSUInteger msaaSampleCount;
@property (readwrite,nonatomic) CGColorSpaceRef colorSpace;

//- (void) addScheduledHandler:(MTLCommandBufferHandler)n;
//- (void) addCompletedHandler:(MTLCommandBufferHandler)n;

@end




NS_ASSUME_NONNULL_END

