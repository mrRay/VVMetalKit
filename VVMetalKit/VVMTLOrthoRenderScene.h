//
//  VVMTLOrthoRenderScene.h
//  VVMetalKit
//
//  Created by testadmin on 11/1/23.
//

#import <VVMetalKit/VVMTLRenderScene.h>

NS_ASSUME_NONNULL_BEGIN




/*		Intended to provide a simple base class for performing orthographic rendering- something I do a fair bit of for various 2D graphics.
		- Basically, this class just populates its superclass' "mvpBuffer" property with a 4x4 single-precision floating-point matrix that contains the cumulative model/view/projection matrix transform
		- YOU STILL NEED TO APPLY THE MVP BUFFER TO YOUR RENDER ENCODER
*/




@interface VVMTLOrthoRenderScene : VVMTLRenderScene

@end




NS_ASSUME_NONNULL_END
