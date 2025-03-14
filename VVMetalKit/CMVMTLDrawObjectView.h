//
//  CMVMTLDrawObjectView.h
//  VVMetalKit
//
//  Created by testadmin on 2/6/25.
//

#import <VVMetalKit/VVMetalKit.h>

NS_ASSUME_NONNULL_BEGIN




/**		Subclass of NSView that uses Metal to draw instances of CMVMTLDrawObject.
*/




@interface CMVMTLDrawObjectView : CustomMetalView

///	Buffer containing the model/view/projection matrices that control display.  You do not need to set or adjust this manually.
@property (strong,nullable) id<MTLBuffer> mvpBuffer;

///	Draw objects are stored here- it's probably easiest to just call `-[CMVMTLDrawObjectView addDrawObject:]`.
@property (strong) NSMutableArray<CMVMTLDrawObject*> * drawObjects;

///	Clears all draw objects currently associated with the receiver.
- (void) clearDrawObjects;
///	Adds the passed draw object to the receiver so that its contents will be drawn every time the receiver draws.
- (void) addDrawObject:(CMVMTLDrawObject *)n;

///	Causes the reciver to draw its associated draw objects immediately (it will generate its own command buffer to do so)
- (void) drawNow;
///	Causes the receiver to draw its associated draw objects in the passed command buffer.
- (void) drawInCommandBuffer:(id<MTLCommandBuffer>)inCmdBuffer;
///	Causes the receiver to draw the passed draw object in the passed command buffer.  The draw object will not be retained by the receiver.
- (void) drawObject:(CMVMTLDrawObject*)inDrawObj inCommandBuffer:(id<MTLCommandBuffer>)cmdBuffer;
///	Causes the receiver to draw the passed array of draw objects in the passed command buffer.  The draw object will not be retained by the receiver.
- (void) drawObjects:(NSArray<CMVMTLDrawObject*> *)inDrawObjs inCommandBuffer:(id<MTLCommandBuffer>)cmdBuffer;

@end




NS_ASSUME_NONNULL_END
