//
//  MSLCompModeScene.h
//  MSLCompModes
//
//  Created by testadmin on 5/18/23.
//

#import <Foundation/Foundation.h>

#import <VVMetalKit/VVMetalKit.h>

@class MSLCompModeRecipe;

NS_ASSUME_NONNULL_BEGIN




@interface MSLCompModeScene : VVMTLRenderScene

//	this is the only method you should be using to render things with this scene
- (BOOL) renderRecipe:(MSLCompModeRecipe *)inRecipe inCanvasBounds:(NSRect)inCanvasBounds toTexture:(id<VVMTLTextureImage>)inTex inCommandBuffer:(id<MTLCommandBuffer>)cb;

//	NO, don't use these (publicly)
- (id<VVMTLTextureImage>) createAndRenderToTextureSized:(NSSize)inSize inCommandBuffer:(id<MTLCommandBuffer>)cb __attribute__((unavailable("No, don't do this")));;
- (void) renderToTexture:(id<VVMTLTextureImage>)n inCommandBuffer:(id<MTLCommandBuffer>)cb __attribute__((unavailable("No, don't do this")));;




@end




NS_ASSUME_NONNULL_END
