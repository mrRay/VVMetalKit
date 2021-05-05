#import <Cocoa/Cocoa.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN




@protocol DisplayLinkWindowDelegate
- (void) displayLinkForWindowAtTime:(CVTimeStamp)outputTime;
@end




@interface DisplayLinkWindow : NSWindow

@property (weak) IBOutlet id<DisplayLinkWindowDelegate> displayLinkDelegate;

- (void) startDisplayLink;
- (void) stopDisplayLink;
- (BOOL) displayLinkRunning;

@end




NS_ASSUME_NONNULL_END
