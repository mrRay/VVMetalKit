//#import <Cocoa/Cocoa.h>
#import <TargetConditionals.h>
#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <CoreMedia/CoreMedia.h>
#import <MetalKit/MetalKit.h>

@class MTLImgBufferPool;
@class MTLImgBuffer;

struct MTLImgBufferStruct;

NS_ASSUME_NONNULL_BEGIN




//	this defines the signature of the callback block that you can provide which gets executed when an instance is destroyed
typedef void (^MTLImgBufferDestroyBlock)(MTLImgBuffer *);

//	this defines the signature of a general-purpose block that classes can use for async processing when a MTLImgBuffer has been made available
typedef void (^MTLImgBufferAvailableBlock)(MTLImgBuffer *);

//	we're declaring an addition to NSObject- all NSObjects now respond to the "isMTLImgBuffer" read-only property
@interface NSObject (MTLImgBufferNSObjectAdditions)
@property (readonly) BOOL isMTLImgBuffer;
@end




@interface MTLImgBuffer : NSObject <NSCopying>

@property (strong, nullable) id<MTLTexture> texture;
@property (strong, nullable) id<MTLBuffer> buffer;
@property (assign,readwrite) size_t bufferBytesPerRow;	//	the # of bytes per row for 'buffer'
@property (readwrite) NSUInteger width;
@property (readwrite) NSUInteger height;
@property (readwrite) CGSize size;
@property (readwrite) BOOL preferDeletion;
@property (readwrite) int checkCount;
@property (readwrite) CMTime time;
@property (readwrite) CMTime duration;

//	the region of the texture/buffer that contains the image that this instance represents
#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
@property (readwrite) CGRect srcRect;
#else
@property (readwrite) NSRect srcRect;
#endif
//	whether or not the image that this instance represents needs to be flipped vertically to be perceived as "right side up"
@property (readwrite) BOOL flipV;
//	whether or not the image that this instance represents needs to be flipped horizontally to be perceived as "not flipped horizontally"
@property (readwrite) BOOL flipH;

@property (strong, nullable) MTLImgBufferPool * parentPool;

//	arbitrary supporting object that gets freed when this object gets freed
@property (strong, nullable) id supportingObject;
//	arbitrary supporting context- does not get automatically retained, freed/released, or memory-managed in any way
@property (readwrite, nullable) void * supportingContext;

//	arbitrary block that gets executed when this object gets freed (before the supporting object is released)
@property (nonatomic, copy, nullable) MTLImgBufferDestroyBlock destroyBlock;

//	RETAINED, NULL by default/on init, only gets set to a non-NULL value if you employ methods that explicitly work with IOSurfaces
@property (assign,readwrite,nullable) IOSurfaceRef iosfc;
//	RETAINED, NULL by default/on init, only gets set to a non-NULL value if you create an IOSurface-backed texture
@property (assign,readwrite,nullable) CVPixelBufferRef cvpb;

//	populates the passed struct with the receiver's info.  does NOT populate the 'dstRect' or 'colorMultiplier' members of the struct!
- (void) populateStruct:(struct MTLImgBufferStruct *)n;

@end




NS_ASSUME_NONNULL_END
