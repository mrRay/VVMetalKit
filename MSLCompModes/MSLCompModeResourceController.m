//
//  MSLCompModeResourceController.m
//  MSLCompModes
//
//  Created by testadmin on 7/10/24.
//

#import "MSLCompModeResourceController.h"

#import "MSLCompModeController.h"
#import "MSLCompModeResource.h"
#import "MSLCompMode.h"




@interface MSLCompModeResourceController ()
@property (strong) NSArray<MSLCompModeResource*> * resources;
@property (strong,readwrite,nullable) NSString * shaderSrc;

//	Potentially faster than 'reload' because it only generates the shader source code if it's nil (if the receiver's 'shaderSrc' has already been generated, it will use it to generate metal libraries for all existing MTLDevice instances)
- (void) reloadResources;

- (void) _reloadShaderSrc;	//	ONLY reloads the shader src (backend method)
- (void) _reloadResources;	//	ONLY reloads the resources (backend method)
@end




@implementation MSLCompModeResourceController


+ (instancetype) create	{
	return [[MSLCompModeResourceController alloc] init];
}
- (instancetype) init	{
	self = [super init];
	if (self != nil)	{
		_resources = @[];
		_shaderSrc = nil;
	}
	return self;
}


- (void) reload	{
	@synchronized (self)	{
		[self _reloadShaderSrc];
		[self _reloadResources];
	}
}
- (void) reloadResources	{
	@synchronized (self)	{
		if (_shaderSrc == nil)	{
			[self _reloadShaderSrc];
		}
		[self _reloadResources];
	}
}
- (void) _reloadShaderSrc	{
	//	get the array of MSLCompModes from the global controller
	NSArray<MSLCompMode*>		*compModes = MSLCompModeController.global.compModes;
	NSString		*newShaderSrc = nil;
	//	execute the reload block, passing it the array of comp modes, and updating the shader src correspondingly
	if (_reloadBlock != nil)	{
		newShaderSrc = _reloadBlock(compModes);
	}
	self.shaderSrc = newShaderSrc;
	//NSLog(@"%s *****************************************",__func__);
	//NSLog(@"%@",newShaderSrc);
	//NSLog(@"*****************************************");
}
- (void) _reloadResources	{
	NSMutableArray		*localResources = [[NSMutableArray alloc] init];
	if (_shaderSrc != nil)	{
		NSArray<id<MTLDevice>>		*metalDevices = MTLCopyAllDevices();
		//NSLog(@"metal devices are %@",metalDevices);
		for (id<MTLDevice> metalDevice in metalDevices)	{
			MSLCompModeResource		*resource = [MSLCompModeResource createWithDevice:metalDevice shaderSrc:_shaderSrc];
			if (resource != nil)
				[localResources addObject:resource];
		}
	}
	self.resources = [NSArray arrayWithArray:localResources];
}

- (MSLCompModeResource *) resourceForDevice:(id<MTLDevice>)n	{
	if (n == nil)
		return nil;
	NSArray		*localResources = nil;
	@synchronized (self)	{
		localResources = [NSArray arrayWithArray:_resources];
	}
	for (MSLCompModeResource * resource in localResources)	{
		id<MTLDevice>	localDevice = resource.device;
		if (localDevice == n || [localDevice isEqual:n])	{
			return resource;
		}
	}
	NSLog(@"****** ERR: no rsrc found, %s",__func__);
	return nil;
}


@end
