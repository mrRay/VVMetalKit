#import <Foundation/Foundation.h>
#import <VVMetalKit/MTLComputeScene.h>

NS_ASSUME_NONNULL_BEGIN




@interface SwizzleMTLScene : MTLComputeScene

- (void) convertSrcImg:(MTLImgBuffer *)inSrcImg srcPixelFormat:(OSType)inSrcPF dstImg:(MTLImgBuffer *)inDstImg dstPixelFormat:(OSType)inDstPF;

@end




NS_ASSUME_NONNULL_END
