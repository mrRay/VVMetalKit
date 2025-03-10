#import <Foundation/Foundation.h>

#import <VVMetalKit/VVMTLComputeScene.h>
//#import <VVMetalKit/VVSizingTool.h>
#import <VVMetalKit/SizingToolTypes.h>

NS_ASSUME_NONNULL_BEGIN




@interface CopierMTLScene : VVMTLComputeScene

- (void) copyImg:(id<VVMTLTextureImage>)inSrc toImg:(id<VVMTLTextureImage>)inDst allowScaling:(BOOL)inScale sizingMode:(SizingMode)inSM inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
