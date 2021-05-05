#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <VVMetalKit/VVMetalKit.h>

NS_ASSUME_NONNULL_BEGIN




@interface MoviePlayer : NSObject	{
	id<MTLDevice>	device;
	CMClockRef		masterClock;
	AVPlayer		*player;
	AVPlayerItem	*playerItem;
	AVPlayerItemVideoOutput		*avfOutput;
	CVMetalTextureCacheRef		texCache;
}

- (id) initWithDevice:(id<MTLDevice>)inDevice;

- (void) loadFileAtURL:(NSURL *)n;

- (MTLImgBuffer *) getFrame;
- (void) upkeepForTime:(CVTimeStamp)inRenderTime;

@end




NS_ASSUME_NONNULL_END
