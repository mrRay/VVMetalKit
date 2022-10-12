//
//  MTLRenderScene.h
//  VVMetalKit
//
//  Created by testAdmin on 5/9/21.
//

#import <TargetConditionals.h>
#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
#import <VVMetalKitTouch/MTLScene.h>
#else
#import <VVMetalKit/MTLScene.h>
#endif

NS_ASSUME_NONNULL_BEGIN




@interface MTLRenderScene : MTLScene

@property (strong,nonatomic,nullable) id<MTLRenderPipelineState> renderPipelineStateObject;

@property (readonly,nonatomic) MTLRenderPassDescriptor * renderPassDescriptor;
@property (readonly,nonatomic) id<MTLRenderCommandEncoder> renderEncoder;

//	subclasses are expected to populate these because they will likely vary from implementation to implementation
@property (strong,nonatomic,nullable) id<MTLBuffer> vertBuffer;
@property (strong,nonatomic,nullable) id<MTLBuffer> mvpBuffer;

@end




NS_ASSUME_NONNULL_END
