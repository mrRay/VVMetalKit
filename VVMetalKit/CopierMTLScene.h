#import <Foundation/Foundation.h>

#import <VVMetalKit/MTLComputeScene.h>

NS_ASSUME_NONNULL_BEGIN




@interface CopierMTLScene : MTLComputeScene

- (void) copyImg:(MTLImgBuffer *)inSrc toImg:(MTLImgBuffer *)inDst allowScaling:(BOOL)inScale inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
