//
//  VVMTLDrawObject.h
//  VVMetalKit
//
//  Created by testadmin on 5/15/23.
//

#import <Metal/Metal.h>
#import <simd/simd.h>
#import <VVMetalKit/VVMetalKit.h>

//@class VVFontAtlasLabelState;

NS_ASSUME_NONNULL_BEGIN




/*		convenience class intended to simplify a number of tasks:
		- pooling similarly-sized data buffers (geometry & index buffers) to minimize system impact and encourage use as a lightweight, throwaway class
		- providing a single interface that retains both data buffers (geometry & index) required to do indexed drawing
		- not inherently threadsafe- assumed that it will be populated from a single thread!
		- not very flexible: basically a container class (ex: if you change the primitive type, the underlying geometry/index buffers are likely invalid, but aren't updated or cleared)
		- class uses the CustomMetalView's vertex format (which is also identical to VVSpriteMTLView's vertex format) when packing geometry data
*/




@interface CMVMTLDrawObject : NSObject

+ (instancetype) createWithGeometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize;
+ (instancetype) createWithGeometryBufferCount:(uint32_t)inVertCount indexBufferCount:(uint32_t)inIndexCount;

- (instancetype) initWithPrimitiveType:(MTLPrimitiveType)inPrimType geometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize;

- (instancetype) initWithGeometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize;
- (instancetype) initWithGeometryBufferCount:(uint32_t)inVertCount indexBufferCount:(uint32_t)inIndexCount;

//	'primitiveType' and 'indexType' (along with the id<MTLBuffer>s held by our id<VVMTLBuffer>s) are all you need for your external class to draw the primitives
//	WARNING: YOU MUST SET THIS **BEFORE** YOU ASK THE RECEIVER TO ENCODE ANYTHING- the primitive type is used internally to determine how to the quads/line strips/font atlas states will be stored internally and passed to the GPU!
@property (assign,readwrite) MTLPrimitiveType primitiveType;

//	data buffer, basically cotains a contiguous array of vertex structs for whatever you want.  the "index" of the vertexes stored here are the indexes referred to in 'indexBuffer'
@property (strong,readwrite) id<VVMTLBuffer> geometryBuffer;
//	data buffer of vertex indexes- this is basically a buffer of draw commands.  the vertex indexes listed in this buffer are drawn using the associated primitive type.  for more info, check out the various "drawIndexedPrimitives" methods of MTLRenderCommandEncoder
@property (strong,readwrite) id<VVMTLBuffer> indexBuffer;

//	the size (in bytes) of a single vertex in 'geometryBuffer'.
@property (readwrite) uint32_t geometryBufferBytesPerVertex;

//	the number of vertices in 'geometryBuffer'.
@property (readwrite) uint32_t geometryBufferVertexCount;
//	the number of indexes in 'indexBuffer' that are being used, and will be executed when this object is drawn
@property (readwrite) uint32_t indexBufferIndexCount;

//	the address in 'geometryBuffer' at which the next write should occur
@property (readonly) void * geometryBufferHead;
//	the address in 'indexBuffer' at which the next write should occur
@property (readonly) void * indexBufferHead;

@property (readonly) uint32_t availableVertexes;
@property (readonly) uint32_t availableIndexes;

//	images that are encoded are stored here for the lifetime of the receiver
@property (strong) NSMutableDictionary<NSNumber*,id<VVMTLTextureImage>> * images;

//	the passed draw object must have the same primitive type as the receiver!
- (BOOL) appendDrawCommandsFrom:(CMVMTLDrawObject *)n;

//	generates geometry to draw a quad matching the passed values (using the receiver's primitive type) and appends it to the receiver's geometry and index buffers.  returns NO if the data cannot be appended to the receiver's buffers.
- (BOOL) encodeQuad:(NSRect)inRect withColor:(NSColor *)inColor;
- (BOOL) encodeQuad:(NSRect)inRect withImage:(__nullable id<VVMTLTextureImage>)inImg texIndex:(int8_t)inTexIndex;
- (BOOL) encodeQuad:(NSRect)inRect withImage:(id<VVMTLTextureImage> __nullable)inImg texIndex:(int8_t)inTexIndex color:(NSColor * __nullable)inColor;

- (BOOL) encodeStrokedQuad:(NSRect)inRect strokeWidth:(float)inStrokeWidth strokeColor:(NSColor *)inColor;

- (BOOL) encodeDiamond:(NSRect)inRect withColor:(NSColor *)inColor;
- (BOOL) encodeStrokedDiamond:(NSRect)inRect strokeWidth:(float)inStrokeWidth strokeColor:(NSColor *)inColor;

//	generates geometry to draw a line matching the passed values (using the receiver's primitive type) and appends it to the receiver's gemoetry and index buffers.  returns NO if the data cannot be appended to the receiver's buffers.
- (BOOL) encodePointsAsLine:(NSPoint *)inPoints count:(uint32_t)inPointsCount lineWidth:(float)inLineWidth lineColor:(NSColor * __nullable)inColor;

//	makes sure the receiver can accommodate the passed data, then populated vertexes using the passed geometry and index data.  DOES NOT ADD A "STOP BIT" FOR ___-STRIP TYPE PRIMITIVES!
- (BOOL) encodeRawPoints:(NSPoint *)inPoints count:(uint32_t)inPointsCount indexes:(uint16_t*)inIndexes count:(uint32_t)inIndexesCount withColor:(NSColor *)inColor;

- (BOOL) encodePrimitiveRestartIndex;

- (void) executeInRenderEncoder:(id<MTLRenderCommandEncoder>)inEnc commandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
