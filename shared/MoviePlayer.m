#import "MoviePlayer.h"




#define TIMEDESC(n) CMTimeCopyDescription(kCFAllocatorDefault,n)
#define FourCCLog(n,f) NSLog(@"%@, %c%c%c%c",n,(int)((f>>24)&0xFF),(int)((f>>16)&0xFF),(int)((f>>8)&0xFF),(int)((f>>0)&0xFF))




@interface MoviePlayer ()	{
	//CVPixelBufferRef		pbRef;
	//CVMetalTextureRef		texRef;
	//id<MTLTexture>			tex;
	MTLImgBuffer			*tex;
}
@end




@implementation MoviePlayer


- (id) initWithDevice:(id<MTLDevice>)inDevice	{
	NSLog(@"%s",__func__);
	self = [super init];
	if (self != nil)	{
		device = inDevice;
		
		masterClock = CMClockGetHostTimeClock();
		CFRetain(masterClock);
		
		player = [[AVPlayer alloc] init];
		player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
		player.automaticallyWaitsToMinimizeStalling = NO;
		player.masterClock = masterClock;
		[player
			addObserver:self
			forKeyPath:@"status"
			options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
			context:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(playerItemDidReachEnd:)
			name:AVPlayerItemDidPlayToEndTimeNotification
			object:nil];
		
		NSDictionary		*pba = @{
			(NSString*)kCVPixelBufferMetalCompatibilityKey: @YES,
			//(NSString*)kCVPixelBufferIOSurfaceCoreAnimationCompatibilityKey: @YES,
			(NSString*)kCVPixelBufferPixelFormatTypeKey: @( kCVPixelFormatType_32BGRA ),
			//(NSString*)kCVPixelBufferPixelFormatTypeKey: @( kCVPixelFormatType_422YpCbCr8 )
			//(NSString*)kCVPixelBufferPixelFormatTypeKey: @( kCVPixelFormatType_422YpCbCr8_yuvs ),
			//(NSString*)kCVPixelBufferPixelFormatTypeKey: @( kCVPixelFormatType_422YpCbCr8FullRange ),
		};
		avfOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pba];
		[avfOutput setSuppressesPlayerRendering:YES];
		if (avfOutput == nil)
			NSLog(@"ERR: unable to create player item output");
		
		playerItem = nil;
		
		CVReturn		cvErr = kCVReturnSuccess;
		cvErr = CVMetalTextureCacheCreate(
			NULL,
			NULL,
			device,
			NULL,
			&texCache
		);
		if (cvErr != kCVReturnSuccess)
			NSLog(@"ERR: unable to create metal texture cache (%d)",cvErr);
		
		//texRef = NULL;
		//tex = nil;
		tex = nil;
	}
	return self;
}


- (void) loadFileAtURL:(NSURL *)n	{
	NSLog(@"%s ... %@",__func__,n);
	
	[player replaceCurrentItemWithPlayerItem:nil];
	[playerItem removeOutput:avfOutput];
	playerItem = nil;
	
	AVAsset			*asset = [AVAsset assetWithURL:n];
	playerItem = [[AVPlayerItem alloc] initWithAsset:asset];
	[playerItem addOutput:avfOutput];
	
	[player replaceCurrentItemWithPlayerItem:playerItem];
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)changeDict context:(void *)context	{
	if ([keyPath isEqualToString:@"status"])	{
		if (object == player)	{
			NSLog(@"\tplayer status updated");
			if ([changeDict[NSKeyValueChangeNewKey] intValue] == AVPlayerStatusReadyToPlay)	{
				//[player setRate:1.0];
				[player setRate:1.0 time:kCMTimeZero atHostTime:CMClockGetTime(masterClock)];
			}
		}
	}
}
- (void) playerItemDidReachEnd:(NSNotification *)note	{
	[player setRate:1.0 time:kCMTimeZero atHostTime:CMClockGetTime(masterClock)];
}


/*
- (id<MTLTexture>) getFrame	{
	//NSLog(@"%s",__func__);
	@synchronized (self)	{
		return tex;
	}
}
*/
- (MTLImgBuffer *) getFrame	{
	@synchronized (self)	{
		return tex;
	}
}
- (void) upkeepForTime:(CVTimeStamp)inRenderTime	{
	//NSLog(@"%s",__func__);
	
	//CMTime			frameTime = [avfOutput itemTimeForCVTimeStamp:inRenderTime];
	CMTime			frameTime = [player currentTime];
	//NSLog(@"%@",TIMEDESC(frameTime));
	if ([avfOutput hasNewPixelBufferForItemTime:frameTime])	{
		CMTime				frameDisplayTime = kCMTimeNegativeInfinity;
		CVPixelBufferRef		pb = [avfOutput copyPixelBufferForItemTime:frameTime itemTimeForDisplay:&frameDisplayTime];
		if (pb != NULL)	{
			CVReturn				cvErr = kCVReturnSuccess;
			OSType					pbpf = CVPixelBufferGetPixelFormatType(pb);
			MTLPixelFormat			mpf;
			//FourCCLog(@"pixel buffer format is ",pbpf);
			//NSLog(@"\tpb size is %d x %d",CVPixelBufferGetWidth(pb),CVPixelBufferGetHeight(pb));
			
			switch (pbpf)	{
			//case '420v':	mpf = 
			case '2vuy':	mpf = MTLPixelFormatBGRG422;		break;
			case 'yuvs':	mpf = MTLPixelFormatGBGR422;		break;
			case 'yuvf':	mpf = MTLPixelFormatGBGR422;		break;
			case 'BGRA':	mpf = MTLPixelFormatBGRA8Unorm;		break;
			case 'RGBA':	mpf = MTLPixelFormatRGBA8Unorm;		break;
			}
			
			CVMetalTextureRef		metalTexRef = NULL;
			cvErr = CVMetalTextureCacheCreateTextureFromImage(
				kCFAllocatorDefault,
				texCache,
				pb,
				NULL,
				mpf,
				CVPixelBufferGetWidth(pb),
				CVPixelBufferGetHeight(pb),
				0,
				&metalTexRef
			);
			if (cvErr != kCVReturnSuccess && metalTexRef==NULL)	{
				NSLog(@"ERR: unable to create metal tex for pixel buffer (%d)",cvErr);
			}
			else	{
				@synchronized (self)	{
					tex = [[MTLPool global] bufferForCVMTLTex:metalTexRef sized:CGSizeMake(CVPixelBufferGetWidth(pb),CVPixelBufferGetHeight(pb))];
					CFRelease(metalTexRef);
				}
			}
			
			CFRelease(pb);
			pb = NULL;
		}
	}
	
	CVMetalTextureCacheFlush(texCache, 0);
}


@end
