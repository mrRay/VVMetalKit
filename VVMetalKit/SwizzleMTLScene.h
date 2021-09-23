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




@interface SwizzleMTLScene : MTLComputeScene

+ (BOOL) isMetalPF:(MTLPixelFormat)inMtlPF compatibleWithSwizzlePF:(SwizzlePF)inSwizzlePF;
+ (MTLPixelFormat) metalPFForSwizzlePF:(SwizzlePF)pf;

- (void) convertSrcImg:(MTLImgBuffer *)inSrcImg srcPixelFormat:(SwizzlePF)inSrcPF dstImg:(MTLImgBuffer *)inDstImg dstPixelFormat:(SwizzlePF)inDstPF inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
