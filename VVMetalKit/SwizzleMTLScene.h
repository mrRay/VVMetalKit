#import <Foundation/Foundation.h>
#import <VVMetalKit/MTLComputeScene.h>
#import <VVMetalKit/SwizzleMTLSceneTypes.h>

NS_ASSUME_NONNULL_BEGIN




#if defined __cplusplus
extern "C" {
#endif
	
	NSString * NSStringFromSwizzlePF(SwizzlePF inPF);
	
#if defined __cplusplus
};
#endif




/*							IMPORTANT!
				THIS CLASS IS NOT THREAD-SAFE!
	when asked to render, it references its ivars/properties			*/




@interface SwizzleMTLScene : MTLComputeScene

- (id<MTLBuffer>) bufferWithLength:(size_t)inLength basePtr:(void*)b bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d;

- (void) convertSrcBuffer:(id<MTLBuffer>)inSrc dstBuffer:(id<MTLBuffer>)inDst dstRGBTexture:(MTLImgBuffer *)inRGB swizzleInfo:(SwizzleShaderInfo)inInfo inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
