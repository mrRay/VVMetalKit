#import <Foundation/Foundation.h>

#import <VVMetalKit/VVMTLComputeScene.h>
//#import <VVMetalKit/VVSizingTool.h>
#import <VVMetalKit/SizingToolTypes.h>

NS_ASSUME_NONNULL_BEGIN




///	Class that uses a Metal compute encoder to copy the contents of one image to another.
///	Other methods of copying textures- such as a blit encoder- may be more performant, but are more stringent and may not work under all circumstances.




@interface CopierMTLScene : VVMTLComputeScene

///	Copies the contents of one image to another, optionally performing scaling/resizing.  The 'srcRect' property of the passed image is respected during the copy.
- (void) copyImg:(id<VVMTLTextureImage>)inSrc toImg:(id<VVMTLTextureImage>)inDst allowScaling:(BOOL)inScale sizingMode:(SizingMode)inSM inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
