//
//  MSLCompModeScene.h
//  MSLCompModes
//
//  Created by testadmin on 7/10/24.
//

#import <Foundation/Foundation.h>

#import <VVMetalKit/VVMetalKit.h>

@class MSLCompModeRecipe;
@class MSLCompModeResource;

NS_ASSUME_NONNULL_BEGIN




@interface MSLCompModeScene : VVMTLRenderScene

//	this is the only method you should be using to render things with this scene
- (BOOL) renderRecipe:(MSLCompModeRecipe *)inRecipe inCanvasBounds:(NSRect)inCanvasBounds toTexture:(id<VVMTLTextureImage>)inTex inCommandBuffer:(id<MTLCommandBuffer>)cb;

//	...okay, you can use this one, too, if you need to render a black frame in a pinch
- (BOOL) renderBlackFrameToTexture:(id<VVMTLTextureImage>)inTex inCommandBuffer:(id<MTLCommandBuffer>)cb;

//	NO, don't use these (publicly)
- (id<VVMTLTextureImage>) createAndRenderToTextureSized:(NSSize)inSize inCommandBuffer:(id<MTLCommandBuffer>)cb __attribute__((unavailable("No, don't do this")));;
- (void) renderToTexture:(id<VVMTLTextureImage>)n inCommandBuffer:(id<MTLCommandBuffer>)cb __attribute__((unavailable("No, don't do this")));;

@property (strong,readwrite,nullable) MSLCompModeRecipe * recipe;
@property (readwrite) NSRect canvasBounds;	//	the region of the canvas that we're rendering
@property (strong,readwrite) MSLCompModeResource * resource;

@end




NS_ASSUME_NONNULL_END
