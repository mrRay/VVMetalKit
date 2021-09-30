//
//  MTLScene_priv.h
//  VVMetalKit
//
//  Created by testAdmin on 9/30/21.
//

#ifndef MTLScene_priv_h
#define MTLScene_priv_h


@interface MTLScene ()

@property (strong,nonatomic) id<MTLDevice> device;
@property (strong,nonatomic) id<MTLCommandBuffer> commandBuffer;

@property (strong,nonatomic) MTLImgBuffer * renderTarget;

- (void) _renderCallback;
- (void) _renderSetup;
- (void) _renderTeardown;

@end


#endif /* MTLScene_priv_h */
