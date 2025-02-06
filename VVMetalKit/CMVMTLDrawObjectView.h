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

- (void) drawObject:(CMVMTLDrawObject*)inDrawObj inCmdBuffer:(id<MTLCommandBuffer>)cmdBuffer;

@end




NS_ASSUME_NONNULL_END
