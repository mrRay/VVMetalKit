//
//  VVMTLScene_priv.h
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#ifndef VVMTLScene_priv_h
#define VVMTLScene_priv_h


@interface VVMTLScene ()

@property (strong,nonatomic) id<MTLDevice> device;
@property (strong,nonatomic) id<MTLCommandBuffer> commandBuffer;

@property (strong,nonatomic) id<VVMTLTextureImage> renderTarget;
@property (strong,nonatomic) id<VVMTLTextureImage> depthTarget;
@property (strong,nonatomic) id<VVMTLTextureImage> msaaTarget;

- (void) _renderCallback;
- (void) _renderSetup;
- (void) _renderTeardown;

@end


#endif /* VVMTLScene_priv_h */
