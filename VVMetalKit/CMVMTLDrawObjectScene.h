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




/**		Metal rendering setup with orthographic projection used to render the contents of CMVMTLDrawObject to a texture.  Assign a `CMVMTLDrawObject` instance to its `drawObject` property, and use one of its superclass' methods to render that to a texture.
*/




@interface CMVMTLDrawObjectScene : VVMTLOrthoRenderScene

///	This object will draw its contents in the scene every time it renders.
@property (strong,nullable) CMVMTLDrawObject * drawObject;

@end




NS_ASSUME_NONNULL_END
