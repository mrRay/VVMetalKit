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

- (id<MTLBuffer>) bufferWithLengthNoCopy:(size_t)inLength basePtr:(nullable void*)b bufferDeallocator:(nullable void (^)(void *pointer, NSUInteger length))d;
- (id<MTLBuffer>) bufferWithLength:(size_t)inLength basePtr:(nullable void*)b;

- (void) convertSrcBuffer:(id<MTLBuffer>)inSrc dstBuffer:(nullable id<MTLBuffer>)inDst dstRGBTexture:(nullable MTLImgBuffer *)inRGB swizzleInfo:(SwizzleShaderInfo)inInfo inCommandBuffer:(id<MTLCommandBuffer>)inCB;
- (void) convertSrcRGBTexture:(MTLImgBuffer *)inSrc dstBuffer:(id<MTLBuffer>)inDst swizzleInfo:(SwizzleShaderInfo)inInfo inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




@interface SwizzleShaderInfoObject : NSObject
+ (instancetype) createWithInfo:(SwizzleShaderImageInfo)n;
+ (instancetype) createWithPF:(SwizzlePF)inPF res:(CGSize)inRes bytesPerRow:(NSUInteger)inBytesPerRow;
- (instancetype) initWithInfo:(SwizzleShaderImageInfo)n;
- (instancetype) initWithPF:(SwizzlePF)inPF res:(CGSize)inSize bytesPerRow:(NSUInteger)inBytesPerRow;
@property (readwrite) SwizzleShaderImageInfo object;
@end




NS_ASSUME_NONNULL_END
