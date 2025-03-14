#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN




extern NSString * const kRenderPropertiesChangedNotificationName;




/**		Singleton class that stores a number of objects that are commonly shared by many drawing classes.  Making an instance of this is probably one of the first things you'll want to do.  Automatically populates its properties on init- just fetch the `global` instance and it'll create itself.
*/




@interface RenderProperties : NSObject

///	Returns the shared instance of this class.
+ (instancetype) global;

///	The default Metal device via `MTLCreateSystemDefaultDevice()`.
@property (readonly) id<MTLDevice> device;
///	A Metal command queue you can use for rendering.
@property (readonly) id<MTLCommandQueue> renderQueue;
///	A Metal command queue you can use for doing background processing.
@property (readonly) id<MTLCommandQueue> bgCmdQueue;
///	A Metal command queue you can use for display commands.
@property (readonly) id<MTLCommandQueue> displayCmdQueue;
///	The default Metal library for the host app's default Metal library.
@property (readonly) id<MTLLibrary> defaultLibrary;

///	Defaults to kCGColorSpaceSRGB
@property (readwrite,nullable) CGColorSpaceRef colorSpace;

///	The max supported resolution for a two-dimensional Metal texture.
@property (assign,readonly) NSSize max2DTextureSize;

///	By default, an instance of RenderProperties is automatically configured to use the Metal device returned by `MTLCreateSystemDefaultDevice()`.  If you want to use a different device, call this method- this will also automatically re-populate the command queues and default library.
- (void) configureWithDevice:(id<MTLDevice>)n;

@end




NS_ASSUME_NONNULL_END
