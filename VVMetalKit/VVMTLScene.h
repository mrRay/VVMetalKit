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




/**		A collection of resources used to perform rendering using Metal.
		Base class, you probably won't be making instances of this- instead, look at ``VVMTLComputeScene`` and ``VVMTLRenderScene`` (and its descendants, ``VVMTLOrthoRenderScene`` and ``VVMTLPerspRenderScene``)
*/




@interface VVMTLScene : NSObject

- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice;

///	Creates (asks the pool to vend) an 8-bit BGRA texture matching the passed dimensions, renders to it in the passed command buffer, and returns the passed texture.  No depth buffer is used.
- (id<VVMTLTextureImage>) createAndRenderToTextureSized:(NSSize)inSize inCommandBuffer:(id<MTLCommandBuffer>)cb;
///	Creates (asks the pool to vend) an 8-bit BGRA texture matching the passed dimensions as well as a depth buffer, renders to them in the passed command buffer, and returns the passed texture.
- (id<VVMTLTextureImage>) createAndRenderWithDepth:(BOOL)inDepth toTextureSized:(NSSize)inSize inCommandBuffer:(id<MTLCommandBuffer>)cb;

///	Renders to the passed texture in the passed command buffer
- (void) renderToTexture:(nullable id<VVMTLTextureImage>)n inCommandBuffer:(id<MTLCommandBuffer>)cb;
///	Renders to the passed textures and depth buffer in the passed command buffer
- (void) renderToTexture:(nullable id<VVMTLTextureImage>)n depthBuffer:(nullable id<VVMTLTextureImage>)d msaa:(nullable id<VVMTLTextureImage>)m inCommandBuffer:(id<MTLCommandBuffer>)cb;

/// Override this method in subclasses and do your rendering in it.  It's expected that the rendering backend (PSO/encoder/etc) will have already been created before this method is called.
- (void) renderCallback;

///	Override this method in subclasses and create your pipeline state object here
- (void) _loadPSO;
///	Subclasses may want to override this method to provide specific functionality/create other resources required to render, but should always call the super!
- (void) _renderSetup;
///	Subclasses may want to override this method to provide specific functionality, but should always call the super!
- (void) _renderTeardown;

///	The Metal device used to perform rendering- set on instance init, cannot be changed after the fact.
@property (readonly,nonatomic) id<MTLDevice> device;
///	The command buffer being used for rendering.  This is a transient property- it's only non-nil while rendering is being performed, and is set back to nil upon completion.
@property (readonly,nonatomic) id<MTLCommandBuffer> commandBuffer;
///	This label is applied to render encoders generated by the scene, and is useful for debugging.
@property (strong) NSString * label;

@property (readonly,nonatomic) id<VVMTLTextureImage> renderTarget;
@property (readonly,nonatomic) id<VVMTLTextureImage> depthTarget;
@property (readonly,nonatomic) id<VVMTLTextureImage> msaaTarget;
@property (readwrite,nonatomic) NSSize renderSize;
@property (readwrite,nonatomic) NSUInteger msaaSampleCount;
@property (readwrite,nonatomic) CGColorSpaceRef colorSpace;

@end




NS_ASSUME_NONNULL_END

