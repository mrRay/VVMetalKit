#import <Foundation/Foundation.h>

#import <TargetConditionals.h>
#if TARGET_OS_IOS
#import <VVMetalKitTouch/MTLComputeScene.h>
//#import <VVMetalKitTouch/VVSizingTool.h>
#else
#import <VVMetalKit/MTLComputeScene.h>
//#import <VVMetalKit/VVSizingTool.h>
#import <VVMetalKit/SizingToolTypes.h>
#endif

NS_ASSUME_NONNULL_BEGIN




@interface CopierMTLScene : MTLComputeScene

- (void) copyImg:(MTLImgBuffer *)inSrc toImg:(MTLImgBuffer *)inDst allowScaling:(BOOL)inScale sizingMode:(SizingMode)inSM inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
