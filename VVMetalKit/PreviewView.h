#import <Cocoa/Cocoa.h>
#import <VVMetalKit/CustomMetalView.h>
#import <VVMetalKit/MTLPool.h>

//NS_ASSUME_NONNULL_BEGIN




@interface PreviewView : CustomMetalView



//	texture containing the image we want to draw
@property (strong,nullable) MTLImgBuffer * imgBuffer;

//	a label that appears in command buffers and NSLog()
@property (strong,nullable) NSString * label;

@end




//NS_ASSUME_NONNULL_END
