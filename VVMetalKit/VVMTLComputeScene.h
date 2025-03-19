//
//  VVMTLComputeScene.h
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import <VVMetalKit/VVMTLScene.h>

NS_ASSUME_NONNULL_BEGIN




/**		Subclass VVMTLComputScene if you want to get up and running with a compute-based Metal pipeline quickly.  Examples in VVMetalKit/vvcore_glue_code/test apps repo.
*/




@interface VVMTLComputeScene : VVMTLScene

@property (strong,nonatomic,nullable) MTLComputePipelineDescriptor * computePSODesc;
@property (strong,nonatomic,nullable) id<MTLComputePipelineState> computePSO;

///	This property is only valid during the render callback, and is set to nil as soon as the encoder's been shut down
@property (readonly,nonatomic) id<MTLComputeCommandEncoder> computeEncoder;

///	The shader will evaluate this many pixels with each thread- 1/1/1 by default
@property (readwrite) MTLSize shaderEvalSize;

///	Uses `shaderEvalSize` to calculate the number of groups to execute during rendering.
- (MTLSize) calculateNumThreadgroups;

@end




NS_ASSUME_NONNULL_END
