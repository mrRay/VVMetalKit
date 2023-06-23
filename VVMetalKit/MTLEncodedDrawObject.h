//
//  MTLEncodedDrawObject.h
//  VVMetalKit
//
//  Created by testadmin on 5/15/23.
//

#import <Metal/Metal.h>
//#import <VVMetalKit/MTLImgBufferPool.h>

@class MTLImgBuffer;

NS_ASSUME_NONNULL_BEGIN




/*		convenience class intended to simplify a number of tasks:
		- pooling similarly-sized data buffers (geometry & index buffers) to minimize system impact
		- providing a single interface that retains both data buffers required to do indexed drawing
		- providing a single, simple base class that can be extended or subclassed if needed later
*/




@interface MTLEncodedDrawObject : NSObject

+ (instancetype) createWithGeometryBufferSize:(uint32_t)inDrawSize indexBufferSize:(uint32_t)inIndexSize;
+ (instancetype) createWithGeometryBuffer:(MTLImgBuffer*)inGeo indexBufferSize:(uint32_t)inIndexSize;
+ (instancetype) createWithGeometryBufferSize:(uint32_t)inDrawSize indexBuffer:(MTLImgBuffer *)inIdx;

- (instancetype) initWithGeometryBufferSize:(uint32_t)inDrawSize indexBufferSize:(uint32_t)inIndexSize;
- (instancetype) initWithGeometryBuffer:(MTLImgBuffer*)inGeo indexBufferSize:(uint32_t)inIndexSize;
- (instancetype) initWithGeometryBufferSize:(uint32_t)inDrawSize indexBuffer:(MTLImgBuffer *)inIdx;

//	'primitiveType' and 'indexType' (along with the id<MTLBuffer>s held by our MTLImgBuffers) are all you need for your external class to draw the primitives
@property (assign,readwrite) MTLPrimitiveType primitiveType;
@property (assign,readwrite) MTLIndexType indexType;

//	data buffer, basically cotains a contiguous array of vertex structs for whatever you want.  the "index" of the vertexes stored here are the indexes referred to in 'indexBuffer'
@property (strong,readonly) MTLImgBuffer * geometryBuffer;
//	data buffer of vertex indexes- this is basically a buffer of draw commands.  the vertex indexes listed in this buffer are drawn using the associated primitive type.  for more info, check out the various "drawIndexedPrimitives" methods of MTLRenderCommandEncoder
@property (strong,readonly) MTLImgBuffer * indexBuffer;

//	convenience method, gets the base ptr for the geometry buffer of vertex data
@property (readonly) void * geometryBufferPtr;

//	convenience method, gets the base ptr for the draw buffer of vertex indexes
@property (readonly) void * indexBufferPtr;

//	the number of indexes in 'indexBuffer' that are being used, and will be executed when this object is draw
@property (readwrite) uint32_t indexBufferIndexCount;

//	this command performs a 'drawIndexedPrimitives' call, encoding a draw command with the vertexes described by the receiver's "indexBuffer" and stored in its "geometryBuffer" into the passed command encoder.
//- (void) executeInEncoder:(id<MTLRenderCommandEncoder>)inEnc commandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
