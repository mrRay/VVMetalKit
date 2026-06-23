//
//  VVMTLSurfaceImageDescriptor.m
//  VVMetalKit
//
//  Created by testadmin on 6/22/26.
//

#import "VVMTLSurfaceImageDescriptor.h"




@implementation VVMTLSurfaceImageDescriptor


+ (instancetype) createWithWidth:(NSUInteger)inWidth height:(NSUInteger)inHeight cvPixelFormat:(OSType)inCVPixelFormat storage:(MTLStorageMode)inStorage	{
	return [[VVMTLSurfaceImageDescriptor alloc] initWithWidth:inWidth height:inHeight cvPixelFormat:inCVPixelFormat storage:inStorage];
}

- (instancetype) initWithWidth:(NSUInteger)inWidth height:(NSUInteger)inHeight cvPixelFormat:(OSType)inCVPixelFormat storage:(MTLStorageMode)inStorage	{
	self = [super init];
	if (self != nil)	{
		_width = inWidth;
		_height = inHeight;
		_cvPixelFormat = inCVPixelFormat;
		_storage = inStorage;
	}
	return self;
}

- (BOOL) isVVMTLSurfaceImageDescriptor	{
	return YES;
}


#pragma mark - NSCopying conformance


- (id) copyWithZone:(NSZone *)z	{
	VVMTLSurfaceImageDescriptor		*returnMe = [[VVMTLSurfaceImageDescriptor alloc] init];
	returnMe.width = _width;
	returnMe.height = _height;
	returnMe.cvPixelFormat = _cvPixelFormat;
	returnMe.storage = _storage;
	return returnMe;
}


#pragma mark - VVMTLRecycleableDescriptor conformance


- (BOOL) matchForRecycling:(id<VVMTLRecycleableDescriptor>)n	{
	if (n == nil || ![(NSObject*)n isVVMTLSurfaceImageDescriptor])
		return NO;
	VVMTLSurfaceImageDescriptor		*recast = (VVMTLSurfaceImageDescriptor *)n;
	if (_width != recast.width
	|| _height != recast.height
	|| _cvPixelFormat != recast.cvPixelFormat
	|| _storage != recast.storage)
	{
		return NO;
	}

	return YES;
}


@end




@implementation NSObject (VVMTLSurfaceImageDescriptorNSObjectAdditions)
- (BOOL) isVVMTLSurfaceImageDescriptor	{
	return NO;
}
@end
