#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN




extern NSString * const kRenderPropertiesChangedNotificationName;




@interface RenderProperties : NSObject

+ (instancetype) global;

@property (readonly) id<MTLDevice> device;
@property (readonly) id<MTLCommandQueue> renderQueue;
@property (readonly) id<MTLCommandQueue> bgCmdQueue;
@property (readonly) id<MTLLibrary> defaultLibrary;

- (void) configureWithDevice:(id<MTLDevice>)n;

@end




NS_ASSUME_NONNULL_END
