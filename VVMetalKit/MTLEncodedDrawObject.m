//
//  MTLEncodedDrawObject.m
//  VVMetalKit
//
//  Created by testadmin on 5/15/23.
//

#import "MTLEncodedDrawObject.h"

#import "VVMTLPool.h"
#import "VVMTLBuffer.h"




@interface MTLEncodedDrawObject ()
@property (strong,readwrite) id<VVMTLBuffer> geometryBuffer;
@property (strong,readwrite) id<VVMTLBuffer> indexBuffer;
@end




@implementation MTLEncodedDrawObject

+ (instancetype) createWithGeometryBufferSize:(uint32_t)inGeoSize indexBufferSize:(uint32_t)inIndexSize	{
	return [[MTLEncodedDrawObject alloc] initWithGeometryBufferSize:inGeoSize indexBufferSize:inIndexSize];
}
+ (instancetype) createWithGeometryBuffer:(id<VVMTLBuffer>)inGeo indexBufferSize:(uint32_t)inIndexSize	{
	return [[MTLEncodedDrawObject alloc] initWithGeometryBuffer:inGeo indexBufferSize:inIndexSize];
}
+ (instancetype) createWithGeometryBufferSize:(uint32_t)inGeoSize indexBuffer:(id<VVMTLBuffer>)inIdx	{
	return [[MTLEncodedDrawObject alloc] initWithGeometryBufferSize:inGeoSize indexBuffer:inIdx];
}

- (instancetype) initWithGeometryBufferSize:(uint32_t)inGeoSize indexBufferSize:(uint32_t)inIndexSize	{
	self = [super init];
	if (inGeoSize < 1 || inIndexSize < 1)
		self = nil;
	if (self != nil)	{
		_primitiveType = MTLPrimitiveTypeTriangleStrip;
		_indexType = MTLIndexTypeUInt16;
		_geometryBuffer = [VVMTLPool.global bufferWithLength:inGeoSize storage:MTLStorageModeShared];
		_indexBuffer = [VVMTLPool.global bufferWithLength:inIndexSize storage:MTLStorageModeShared];
		_indexBufferIndexCount = 0;
	}
	return self;
}
- (instancetype) initWithGeometryBuffer:(id<VVMTLBuffer>)inGeo indexBufferSize:(uint32_t)inIndexSize	{
	self = [super init];
	if (inGeo == nil || inIndexSize < 1)
		self = nil;
	if (self != nil)	{
		_primitiveType = MTLPrimitiveTypeTriangleStrip;
		_indexType = MTLIndexTypeUInt16;
		_geometryBuffer = inGeo;
		_indexBuffer = [VVMTLPool.global bufferWithLength:inIndexSize storage:MTLStorageModeShared];
		_indexBufferIndexCount = 0;
	}
	return self;
}
- (instancetype) initWithGeometryBufferSize:(uint32_t)inGeoSize indexBuffer:(id<VVMTLBuffer>)inIdx	{
	self = [super init];
	if (inGeoSize < 1 || inIdx == nil)
		self = nil;
	if (self != nil)	{
		_primitiveType = MTLPrimitiveTypeTriangleStrip;
		_indexType = MTLIndexTypeUInt16;
		_geometryBuffer = [VVMTLPool.global bufferWithLength:inGeoSize storage:MTLStorageModeShared];
		_indexBuffer = inIdx;
		_indexBufferIndexCount = 0;
	}
	return self;
}

//	convenience method, gets the base ptr for the geometry buffer of vertex data
- (void *) geometryBufferPtr	{
	return _geometryBuffer.buffer.contents;
}

//	convenience method, gets the base ptr for the draw buffer of vertex indexes
- (void *) indexBufferPtr	{
	return _indexBuffer.buffer.contents;
}
/*
- (void) executeInEncoder:(id<MTLRenderCommandEncoder>)inEnc commandBuffer:(id<MTLCommandBuffer>)inCB	{
	if (inEnc == nil || inCB == nil)
		return;
	
	if (_indexBufferIndexCount < 1)
		return;
	
	[inEnc
		drawIndexedPrimitives:_primitiveType
		indexCount:_indexBufferIndexCount
		indexType:_indexType
		indexBuffer:_indexBuffer.buffer
		indexBufferOffset:0];
	
	[inCB addCompletedHandler:^(id<MTLCommandBuffer> completedCB)	{
		MTLEncodedDrawObject		*tmpSelf = self;
		tmpSelf = nil;
	}];
}
*/

@end
