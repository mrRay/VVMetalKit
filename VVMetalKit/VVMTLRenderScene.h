//
//  VVMTLRenderScene.h
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import <TargetConditionals.h>
#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
#import <VVMetalKitTouch/VVMTLScene.h>
#else
#import <VVMetalKit/VVMTLScene.h>
#endif

NS_ASSUME_NONNULL_BEGIN




@interface VVMTLRenderScene : VVMTLScene

@property (strong,nonatomic,nullable) MTLRenderPipelineDescriptor * renderPSODesc;
@property (strong,nonatomic,nullable) id<MTLRenderPipelineState> renderPSO;

@property (readonly,nonatomic) MTLRenderPassDescriptor * renderPassDescriptor;
@property (readonly,nonatomic) id<MTLRenderCommandEncoder> renderEncoder;

//	subclasses are expected to populate these because they will likely vary from implementation to implementation
@property (strong,nonatomic,nullable) id<MTLBuffer> mvpBuffer;

@end




NS_ASSUME_NONNULL_END
