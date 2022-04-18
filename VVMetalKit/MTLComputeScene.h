#import <TargetConditionals.h>
#if TARGET_OS_IOS
#import <VVMetalKitTouch/MTLScene.h>
#else
#import <VVMetalKit/MTLScene.h>
#endif

NS_ASSUME_NONNULL_BEGIN




@interface MTLComputeScene : MTLScene

@property (strong,nonatomic,nullable) id<MTLComputePipelineState> computePipelineStateObject;

@property (readonly,nonatomic) id<MTLComputeCommandEncoder> computeEncoder;
@property (readonly,nonatomic) NSUInteger threadGroupSizeVal;

//	the # of pixels the shader should evaluate at a time.  is usually 1/1/1 (the shader is evaluated for every pixel in the output image)
@property (readwrite) MTLSize shaderEvalSize;

//	calculates the number of groups to execute during rendering, using 'threadGroupSizeVal' (which is only populated during _renderSetup!) and 'shaderEvalSize'
- (MTLSize) calculateNumberOfGroups;

@end




NS_ASSUME_NONNULL_END
