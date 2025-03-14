//
//  VVMTLComputeScene.h
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import <VVMetalKit/VVMTLScene.h>

NS_ASSUME_NONNULL_BEGIN




/*		Subclass VVMTLComputScene if you want to get up and running with a compute-based Metal pipeline quickly.  Examples in VVMetalKit/vvcore_glue_code/test apps repo.
*/




@interface VVMTLComputeScene : VVMTLScene

@property (strong,nonatomic,nullable) MTLComputePipelineDescriptor * computePSODesc;
@property (strong,nonatomic,nullable) id<MTLComputePipelineState> computePipelineStateObject;

@property (readonly,nonatomic) id<MTLComputeCommandEncoder> computeEncoder;
@property (readonly,nonatomic) NSUInteger threadGroupSizeVal;

//	the # of pixels the shader should evaluate at a time.  is usually 1/1/1 (the shader is evaluated for every pixel in the output image)
@property (readwrite) MTLSize shaderEvalSize;

//	calculates the number of groups to execute during rendering, using 'threadGroupSizeVal' (which is only populated during _renderSetup!) and 'shaderEvalSize'
- (MTLSize) calculateNumberOfGroups;

@end




NS_ASSUME_NONNULL_END
