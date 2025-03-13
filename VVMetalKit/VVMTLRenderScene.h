//
//  VVMTLRenderScene.h
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import <VVMetalKit/VVMTLScene.h>

NS_ASSUME_NONNULL_BEGIN




/*		Subclass VVMTLRenderScene if you want to get up and running with a render-based Metal pipeline
*/




@interface VVMTLRenderScene : VVMTLScene

@property (strong,nonatomic,nullable) MTLRenderPipelineDescriptor * renderPSODesc;
@property (strong,nonatomic,nullable) id<MTLRenderPipelineState> renderPSO;

@property (readonly,nonatomic) MTLRenderPassDescriptor * renderPassDescriptor;
@property (readonly,nonatomic) id<MTLRenderCommandEncoder> renderEncoder;

//	subclasses are expected to populate these because they will likely vary from implementation to implementation
@property (strong) id<MTLDepthStencilState> depthState;
@property (strong,nonatomic,nullable) id<MTLBuffer> mvpBuffer;

- (void) _setViewport;
- (void) _setMVPBuffer;

@end



#if defined __cplusplus
extern "C"	{
#endif

id<MTLBuffer> CreateOrthogonalMVPBufferForCanvas(NSRect inCanvasBounds, BOOL inFlipH, BOOL inFlipV, id<MTLDevice> inDevice);
//matrix_float4x4 CreatePerspectiveProjectionForCanvas(NSRect inCanvasBounds, double near, double far, id<MTLDevice> inDevice);


#if defined __cplusplus
}
#endif




NS_ASSUME_NONNULL_END
