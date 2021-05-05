#import "BasicPlaybackAppDelegate.h"
#import <VVMetalKit/VVMetalKit.h>
#import "DisplayLinkWindow.h"
#import "MoviePlayer.h"




@interface BasicPlaybackAppDelegate () <DisplayLinkWindowDelegate>
@property (strong) IBOutlet DisplayLinkWindow * window;
@property (weak) IBOutlet PreviewView * previewView;
@property (strong) MoviePlayer * moviePlayer;
@property (strong) CopierMTLScene * copier;
@end




@implementation BasicPlaybackAppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	RenderProperties		*rp = [RenderProperties global];
	if (rp == nil)	{
		NSLog(@"ERR: render properties nil, bailing, %s",__func__);
		return;
	}
	
	//	make the pool!
	[MTLPool createGlobalPoolWithDevice:rp.device];
	
	//	make the copier!
	self.copier = [[CopierMTLScene alloc] initWithDevice:rp.device];
	
	//	configure the preview view to use the same device we'll be using for rendering
	[self.previewView setDevice:rp.device];
	
	//	make the movie player, have it load the included movie
	self.moviePlayer = [[MoviePlayer alloc] initWithDevice:rp.device];
	NSURL			*movURL = [[NSBundle mainBundle] URLForResource:@"Blade Runner 2049-Scene-0968_analyzed" withExtension:@"mov"];
	[self.moviePlayer loadFileAtURL:movURL];
	
	//	configure and start the displaylink window
	[self.window startDisplayLink];
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {
	[self.window stopDisplayLink];
}


#pragma mark - DisplayLinkWindowDelegate protocol


- (void) displayLinkForWindowAtTime:(CVTimeStamp)outputTime	{
	//NSLog(@"%s",__func__);
	MTLImgBuffer		*newFrame = [self.moviePlayer getFrame];
	
	
	
	
#define CAPTURE 0
#if CAPTURE
	MTLCaptureManager		*cm = nil;
	if (newFrame != nil)
		cm = [MTLCaptureManager sharedCaptureManager];
	MTLCaptureDescriptor		*desc = [[MTLCaptureDescriptor alloc] init];
	desc.captureObject = [RenderProperties global].renderQueue;

	if (cm!=nil && ![cm startCaptureWithDescriptor:desc error:nil])
		NSLog(@"ERR: couldn't start capturing metal data");
#endif
	
	
	
	
	id<MTLCommandBuffer>		cmdBuffer = [[RenderProperties global].renderQueue commandBuffer];
	
	if (newFrame != nil)	{
		//NSLog(@"new frame is %@",newFrame);
		
		self.previewView.imgBuffer = newFrame;
		
		//newFrame.srcRect = NSMakeRect(0,0,512,512);
		//MTLImgBuffer		*copiedBuffer = [[MTLPool global] bgra8TexSized:NSMakeSize(512,512)];
		//[self.copier
		//	copyImg:newFrame
		//	toImg:copiedBuffer
		//	allowScaling:YES
		//	inCommandBuffer:cmdBuffer];
		//self.previewView.imgBuffer = copiedBuffer;
		//NSLog(@"copied buffer is %@",copiedBuffer);
		
		//MTLImgBuffer		*nsCopiedBuffer = [newFrame copy];
		//MTLImgBuffer		*nsCopiedBuffer = [copiedBuffer copy];
		//self.previewView.imgBuffer = nsCopiedBuffer;
		
		[self.previewView drawInCmdBuffer:cmdBuffer];
	}
	[self.previewView drawInCmdBuffer:cmdBuffer];
	
	[cmdBuffer commit];
	
	[self.moviePlayer upkeepForTime:outputTime];
	[[MTLPool global] housekeeping];
	
	
	
	
#if CAPTURE
	if (cm != nil)
		[cm stopCapture];
#endif

}


@end
