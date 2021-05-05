#import "DisplayLinkWindow.h"
//#import <CoreVideo/CoreVideo.h>




@interface DisplayLinkWindow ()	{
	CVDisplayLinkRef		displayLink;
	BOOL					running;
}
- (void) generalInit;
- (void) _displayLinkCallback:(CVTimeStamp)n;
@end




static CVReturn DisplayLinkWindowDisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp * now, const CVTimeStamp * outputTime, CVOptionFlags flagsIn, CVOptionFlags * flagsOut, void * displayLinkContext);




@implementation DisplayLinkWindow


- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag	{
	self = [super initWithContentRect:contentRect styleMask:style backing:backingStoreType defer:flag];
	if (self != nil)	{
		[self generalInit];
	}
	return self;
}
- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag screen:(NSScreen *)screen	{
	self = [super initWithContentRect:contentRect styleMask:style backing:backingStoreType defer:flag screen:screen];
	if (self != nil)	{
		[self generalInit];
	}
	return self;
}


- (void) generalInit	{
	displayLink = NULL;
	running = NO;
}


- (void) dealloc	{
	[self stopDisplayLink];
}


- (void) startDisplayLink	{
	@synchronized (self)	{
		if (running)
			return;
		NSScreen		*screen = self.screen;
		if (screen == nil)	{
			NSLog(@"ERR: unable to start displaylink, window is offscreen, %s",__func__);
			return;
		}
		
		CVReturn		cvErr;
		
		cvErr = CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
		if (cvErr != kCVReturnSuccess)	{
			NSLog(@"ERR: unable to create displaylink, %s (%d)",__func__,cvErr);
			return;
		}
		
		cvErr = CVDisplayLinkSetOutputCallback(displayLink, &DisplayLinkWindowDisplayLinkCallback, (__bridge void*)self);
		if (cvErr != kCVReturnSuccess)	{
			NSLog(@"ERR: unable to configure displaylink callback, %s (%d)",__func__,cvErr);
			CVDisplayLinkRelease(displayLink);
			displayLink = NULL;
			return;
		}
		
		CGDirectDisplayID		viewDisplayID = (CGDirectDisplayID)[self.screen.deviceDescription[@"NSScreenNumber"] unsignedIntegerValue];
		cvErr = CVDisplayLinkSetCurrentCGDisplay(displayLink, viewDisplayID);
		if (cvErr != kCVReturnSuccess)	{
			NSLog(@"ERR: unable to set displaylink display, %s (%d)",__func__,cvErr);
			CVDisplayLinkRelease(displayLink);
			displayLink = NULL;
			return;
		}
		
		CVDisplayLinkStart(displayLink);
		
		running = YES;
		
		//	kill the displaylink when the window's about to close
		[[NSNotificationCenter defaultCenter]
			addObserverForName:NSWindowWillCloseNotification
			object:self
			queue:nil
			usingBlock:^(NSNotification *note){
				[self stopDisplayLink];
			}];
	}
}
- (void) stopDisplayLink	{
	@synchronized (self)	{
		if (!running)
			return;
		
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:self];
		
		if (displayLink == NULL)	{
			NSLog(@"ERR: displaylink already nil in %s",__func__);
			return;
		}
		
		CVDisplayLinkStop(displayLink);
	}
}
- (BOOL) displayLinkRunning	{
	BOOL		returnMe = NO;
	@synchronized (self)	{
		returnMe = running;
	}
	return returnMe;
}


- (void) _displayLinkCallback:(CVTimeStamp)n	{
	id<DisplayLinkWindowDelegate>		tmpDelegate = self.displayLinkDelegate;
	if (tmpDelegate != nil)
		[tmpDelegate displayLinkForWindowAtTime:n];
}


@end









static CVReturn DisplayLinkWindowDisplayLinkCallback(
	CVDisplayLinkRef displayLink,
	const CVTimeStamp * now,
	const CVTimeStamp * outputTime,
	CVOptionFlags flagsIn,
	CVOptionFlags * flagsOut,
	void * displayLinkContext)
{
	@autoreleasepool	{
		DisplayLinkWindow		*window = (__bridge DisplayLinkWindow *)displayLinkContext;
		[window _displayLinkCallback:*outputTime];
	}
	return kCVReturnSuccess;
}
