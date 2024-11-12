//
//  CMVMTLDrawObjectScene.h
//  VVMetalKit
//
//  Created by testadmin on 11/12/24.
//

#import <Foundation/Foundation.h>

#import <VVMetalKit/VVMTLOrthoRenderScene.h>
//#import <VVMetalKit/CMVMTLDrawObject.h>
@class CMVMTLDrawObject;

NS_ASSUME_NONNULL_BEGIN




/*		Metal rendering setup with orthographic projection used to render the contents of CMVMTLDrawObject to texture
		- Assign a drawObject
		- Tell it to render using the usual means
*/




@interface CMVMTLDrawObjectScene : VVMTLOrthoRenderScene

//	this object will draw its contents in the scene every time it renders
@property (strong,nullable) CMVMTLDrawObject * drawObject;

@end




NS_ASSUME_NONNULL_END
