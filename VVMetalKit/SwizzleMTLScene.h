#import <TargetConditionals.h>
#import <Foundation/Foundation.h>
#if TARGET_OS_IOS
#import <VVMetalKitTouch/MTLComputeScene.h>
#import <VVMetalKitTouch/SwizzleMTLSceneTypes.h>
#else
#import <VVMetalKit/MTLComputeScene.h>
#import <VVMetalKit/SwizzleMTLSceneTypes.h>
#endif

NS_ASSUME_NONNULL_BEGIN




#if defined __cplusplus
extern "C" {
#endif
	
	NSString * NSStringFromSwizzlePF(SwizzlePF inPF);
	
#if defined __cplusplus
};
#endif




@interface SwizzleMTLScene : MTLComputeScene

- (id<MTLBuffer>) bufferWithLengthNoCopy:(size_t)inLength basePtr:(nullable void*)b bufferDeallocator:(nullable void (^)(void *pointer, NSUInteger length))d;
- (id<MTLBuffer>) bufferWithLength:(size_t)inLength basePtr:(nullable void*)b;

- (void) convertSrcBuffer:(id<MTLBuffer>)inSrc dstBuffer:(nullable id<MTLBuffer>)inDst dstRGBTexture:(nullable MTLImgBuffer *)inRGB swizzleInfo:(SwizzleShaderOpInfo)inInfo inCommandBuffer:(id<MTLCommandBuffer>)inCB;

- (void) convertSrcRGBTexture:(MTLImgBuffer *)inSrc dstBuffer:(nullable id<MTLBuffer>)inDst dstRGBTexture:(nullable MTLImgBuffer *)inRGB swizzleInfo:(SwizzleShaderOpInfo)inInfo inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
