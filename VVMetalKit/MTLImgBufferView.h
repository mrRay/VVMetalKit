#import <Cocoa/Cocoa.h>
#import <VVMetalKit/CustomMetalView.h>
#import <VVMetalKit/MTLPool.h>

//NS_ASSUME_NONNULL_BEGIN




@interface MTLImgBufferView : CustomMetalView


//	buffer of the vertices that are drawn
@property (strong,nullable) id<MTLBuffer> vertBuffer;
//	buffer containing the model/view/projection matrices that control display
@property (strong,nullable) id<MTLBuffer> mvpBuffer;
//	buffer containing the src rect and anamorphic ratio of the images we're asked to display
@property (strong,nullable) id<MTLBuffer> geoBuffer;

//	texture containing the image we want to draw
@property (strong,nullable,atomic) MTLImgBuffer * imgBuffer;

//	a label that appears in command buffers and NSLog()
@property (strong,nullable) NSString * label;


@end




//NS_ASSUME_NONNULL_END
