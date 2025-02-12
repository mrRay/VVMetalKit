//
//  CMVMTLDrawObjectView.h
//  VVMetalKit
//
//  Created by testadmin on 2/6/25.
//

#import <VVMetalKit/VVMetalKit.h>

NS_ASSUME_NONNULL_BEGIN




@interface CMVMTLDrawObjectView : CustomMetalView

//	buffer containing the model/view/projection matrices that control display
@property (strong,nullable) id<MTLBuffer> mvpBuffer;

//	we store a local copy of the object to be drawn (which in turn retains all the geometry + textures)
@property (strong) CMVMTLDrawObject * drawObject;

- (void) drawNow;
- (void) drawInCommandBuffer:(id<MTLCommandBuffer>)inCmdBuffer;
- (void) drawObject:(CMVMTLDrawObject*)inDrawObj inCommandBuffer:(id<MTLCommandBuffer>)cmdBuffer;

@end




NS_ASSUME_NONNULL_END
