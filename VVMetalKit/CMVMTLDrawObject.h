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




///		Convenience class intended to simplify efficiently drawing arbitrary two-dimensional graphics in metal.
///		- Pools similarly-sized data buffers (geometry & index buffers) to minimize system impact and encourage use as a lightweight, throwaway class.
///		- Provides a single interface that manages and retains both data buffers (geometry & index) required to do indexed drawing.
///		- Simple interface: tell it to encode draw commands (draw rect/draw line/etc) which it converts to geometry behind the scenes.
///		## Notes:
///		- Not inherently threadsafe- assumed that it will be populated from a single thread!
///		- Not very flexible: basically a container class (ex: if you change the primitive type, the underlying geometry/index buffers are likely invalid, but aren't updated or cleared).
///		- Capable of drawing textured geometry, but requires an argument encoder during rendering to do so (``CMVMTLDrawObjectScene`` and ``CMVMTLDrawObjectView`` manage this automatically but if you want to use this class with an arbitrary Metal render command encoder you'll have to manage this yourself).
///		- Class uses the `CustomMetalView`'s vertex format (which is also identical to `VVSpriteMTLView`'s vertex format) when packing geometry data- this is only an issue if you want to render it in arbitrary Metal render command encoders.
///		- Indexes are 16-bit (`MTLIndexTypeUInt16`) unless the object is made with an index type: only ``initWithPrimitiveType:indexType:geometryBufferSizeInBytes:indexBufferSizeInBytes:`` and the two create methods that take an `indexType` can make a 32-bit (`MTLIndexTypeUInt32`) object, and every other create and init method makes the 16-bit object it always made.  The type is fixed for the object's life, and every encoder, `-appendDrawCommandsFrom:` and both `-executeInRenderEncoder:` methods index under it.  Each type's largest value (`restartIndex`, `0xFFFF` or `0xFFFFFFFF`) is the strip-restart value Metal documents on `-[MTLRenderCommandEncoder drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:]`, so it is reserved and is never a vertex number, which is why an object can name at most `maxVertexCount` vertices however large its geometry buffer is.
///		- An index is never truncated to fit the object's type: every encoder that numbers its own vertexes names only the vertexes it adds, and writes only the indexes its room check counted, so an encode that would write a vertex number the type cannot hold (the vertex count would pass `maxVertexCount`) is refused with `NO` before anything is written, its counts summed at 64 bits so that no count a caller passes can wrap one and pass the check.  A wrapped index draws some other shape's vertexes, where a refused shape is simply one that did not appear.  So the room a caller writing into the buffers directly must test is the smaller of `availableVertexes` and `maxVertexCount - geometryBufferVertexCount`: `availableVertexes` alone is not enough, because the pool rounds every buffer up to a multiple of 4096 bytes and a buffer can therefore hold vertexes no index can name.





@interface CMVMTLDrawObject : NSObject

///	Creates an instance of this class with a known buffer size in bytes.  Defaults to triangle strip drawing (`MTLPrimitiveTypeTriangleStrip`) and 16-bit indexes (`MTLIndexTypeUInt16`).
+ (instancetype) createWithGeometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize;
///	Creates an instance of this class with a known buffer size in bytes and the passed index type.  Defaults to triangle strip drawing (`MTLPrimitiveTypeTriangleStrip`).
+ (instancetype) createWithGeometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize indexType:(MTLIndexType)inIndexType;
///	If you know the number of vertexes and the number of indexes used to draw those vertexes, you can use this method to create an instance of this class.  Defaults to triangle strip drawing (`MTLPrimitiveTypeTriangleStrip`) and 16-bit indexes (`MTLIndexTypeUInt16`).
+ (instancetype) createWithGeometryBufferCount:(uint32_t)inVertCount indexBufferCount:(uint32_t)inIndexCount;
///	As ``createWithGeometryBufferCount:indexBufferCount:``, with the passed index type: the index buffer is sized at `inIndexCount` indexes of that type (2 or 4 bytes each).  Returns nil if either buffer's size in bytes would not fit in a `uint32_t`.
+ (instancetype) createWithGeometryBufferCount:(uint32_t)inVertCount indexBufferCount:(uint32_t)inIndexCount indexType:(MTLIndexType)inIndexType;

///	This is the "main" init method- every other create/init method uses this "under the hood".  `inIndexType` must be `MTLIndexTypeUInt16` or `MTLIndexTypeUInt32`, and fixes the width of every index the object writes and the type it draws with (see `indexType`); returns nil for any other value, or if either size is 0.  Don't feel like you need to use this method directly, the 'create' methods are faster.
- (instancetype) initWithPrimitiveType:(MTLPrimitiveType)inPrimType indexType:(MTLIndexType)inIndexType geometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize;
///	Calls ``initWithPrimitiveType:indexType:geometryBufferSizeInBytes:indexBufferSizeInBytes:`` with 16-bit indexes (`MTLIndexTypeUInt16`).
- (instancetype) initWithPrimitiveType:(MTLPrimitiveType)inPrimType geometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize;

- (instancetype) initWithGeometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize;
- (instancetype) initWithGeometryBufferCount:(uint32_t)inVertCount indexBufferCount:(uint32_t)inIndexCount;

///	The type of every index in 'indexBuffer', fixed when the object is made: `MTLIndexTypeUInt16` unless it was made with an index type.  Both `-executeInRenderEncoder:` methods draw with it, and an external class drawing the buffers itself must pass it to `drawIndexedPrimitives` too.
@property (readonly) MTLIndexType indexType;
///	The size (in bytes) of one index in 'indexBuffer' under `indexType`: 2 or 4.
@property (readonly) uint32_t bytesPerIndex;
///	The strip-restart value under `indexType`- `0xFFFF` or `0xFFFFFFFF`- which ends a strip and is never a vertex number.  Write this, never a literal, when writing indexes directly.
@property (readonly) uint32_t restartIndex;
///	The highest number of vertexes an object of this `indexType` can name: 65,535 or `UINT32_MAX`, the vertex numbers running from 0 to one below `restartIndex`, which is reserved.  No encode takes `geometryBufferVertexCount` past it.
@property (readonly) uint32_t maxVertexCount;

///	'primitiveType' and 'indexType' (along with the id<MTLBuffer>s held by our id<VVMTLBuffer>s) are all you need for your external class to draw the primitives
///	WARNING: YOU MUST SET THIS **BEFORE** YOU ASK THE RECEIVER TO ENCODE ANYTHING- the primitive type is used internally to determine how to the quads/line strips/font atlas states will be stored internally and passed to the GPU!
@property (assign,readwrite) MTLPrimitiveType primitiveType;

///	Data buffer, basically cotains a contiguous array of vertex structs for whatever you want.  The "index" of the vertexes stored here are the indexes referred to in 'indexBuffer'.  This buffer is populated automatically via the various 'encode' methods.
@property (strong,readwrite) id<VVMTLBuffer> geometryBuffer;
///	Data buffer of vertex indexes- this is basically a buffer of draw commands.  The vertex indexes listed in this buffer are drawn using the associated primitive type.  For more info, check out the various "drawIndexedPrimitives" methods of MTLRenderCommandEncoder.  This buffer is populated automatically via the various 'encode' methods.
@property (strong,readwrite) id<VVMTLBuffer> indexBuffer;

///	The size (in bytes) of a single vertex in 'geometryBuffer'.  Defaults to `sizeof(CMVSimpleVertex)`.
@property (readwrite) uint32_t geometryBufferBytesPerVertex;

///	The number of vertices in 'geometryBuffer'.  Do not modify this value manually (it's updated via the various 'encode' methods).
@property (readwrite) uint32_t geometryBufferVertexCount;
///	The number of indexes in 'indexBuffer' that are being used, and will be executed when this object is drawn.  Do not modify this value manually (it's updated via the various 'encode' methods).
@property (readwrite) uint32_t indexBufferIndexCount;

///	The address in 'geometryBuffer' at which the next write should occur (updated automatically via the various 'encode' methods).
@property (readonly) void * geometryBufferHead;
///	The address in 'indexBuffer' at which the next write should occur (updated automatically via the various 'encode' methods).  Indexes are `bytesPerIndex` apart, so this is `indexBufferIndexCount` × `bytesPerIndex` bytes into the buffer.
@property (readonly) void * indexBufferHead;

///	The number of vertexes 'geometryBuffer' has room for beyond `geometryBufferVertexCount`.  This is buffer room, not nameable room: see `maxVertexCount`.
@property (readonly) uint32_t availableVertexes;
///	The number of indexes of `indexType` 'indexBuffer' has room for beyond `indexBufferIndexCount`.
@property (readonly) uint32_t availableIndexes;

///	Images that are encoded (via `-[CMVMTLDrawObject encodeQuad:withImage:texIndex:color:]`) are stored here for the lifetime of the receiver
@property (strong) NSMutableDictionary<NSNumber*,id<VVMTLTextureImage>> * images;

///	Copies the draw data from the passed draw object into the receiver.  The passed draw object must have the same primitive type as the receiver, and may have either index type: its indexes are read under its own type, offset past the receiver's vertexes and written under the receiver's, its restart value written as the receiver's.  Returns NO, with nothing written, if the receiver's buffers lack room, or if the passed object's vertexes or any of its indexes, once offset, would pass the receiver's `maxVertexCount`- an index is never truncated to fit.
- (BOOL) appendDrawCommandsFrom:(CMVMTLDrawObject *)n;

///	Generates geometry to draw a quad matching the passed values (using the receiver's primitive type) and appends it to the receiver's geometry and index buffers.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry, because the receiver's buffers aren't large enough, or because the new vertexes would pass the receiver's `maxVertexCount`).
- (BOOL) encodeQuad:(NSRect)inRect withColor:(NSColor *)inColor;
///	Generates geometry for drawing a quad with the passed rect that will draw using the passed texture.  Caller is responsible for incrementing and tracking 'inTexIndex', which should start at '0'.  The passed texture will be retained for the lifetime of the receiver, and will be associated with 'inTexIndex' for that duration.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry, because the receiver's buffers aren't large enough, or because the new vertexes would pass the receiver's `maxVertexCount`).
- (BOOL) encodeQuad:(NSRect)inRect withImage:(__nullable id<VVMTLTextureImage>)inImg texIndex:(int8_t)inTexIndex;
- (BOOL) encodeQuad:(NSRect)inRect withImage:(id<VVMTLTextureImage> __nullable)inImg texIndex:(int8_t)inTexIndex color:(NSColor * __nullable)inColor;
///	This method calculates the number of vertexes and indexes needed to draw the passed quad, and updates 'outVtxCount' and 'outIdxCount' accordingly.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry or because the receiver's buffers aren't large enough).
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forQuad:(NSRect)inRect primitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Generates geometry for drawing the outline of the passed quad using a line with the passed width and color.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry, because the receiver's buffers aren't large enough, or because the new vertexes would pass the receiver's `maxVertexCount`).
- (BOOL) encodeStrokedQuad:(NSRect)inRect strokeWidth:(float)inStrokeWidth strokeColor:(NSColor *)inColor;
///	This method calculates the number of vertexes and indexes needed to stroke the passed quad, and updates 'outVtxCount' and 'outIdxCount' accordingly.  Returns 'NO' if there's a problem calculating the number of vertexes/indexes.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forStrokedQuad:(NSRect)inRect primitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Generates geometry for drawing a diamond in the passed rect with the passed color as its fill.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry, because the receiver's buffers aren't large enough, or because the new vertexes would pass the receiver's `maxVertexCount`).
- (BOOL) encodeDiamond:(NSRect)inRect withColor:(NSColor *)inColor;
///	Generates geometry for stroking (drawing the outline of) the passed rec with a line of the passed width and color.
- (BOOL) encodeStrokedDiamond:(NSRect)inRect strokeWidth:(float)inStrokeWidth strokeColor:(NSColor *)inColor;


///	Generates geometry to draw a line matching the passed values (using the receiver's primitive type) and appends it to the receiver's gemoetry and index buffers.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry, because the receiver's buffers aren't large enough, or because the new vertexes would pass the receiver's `maxVertexCount`).
- (BOOL) encodePointsAsLine:(NSPoint *)inPoints count:(uint32_t)inPointsCount lineWidth:(float)inLineWidth lineColor:(NSColor * __nullable)inColor;
///	This method calculates the number of vertexes and indexes required to draw an arbitrary number of points as a line using the passed primitive type.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forPointsAsLineCount:(uint32_t)inPointsCount primitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Makes sure the receiver can accommodate the passed data, then populated vertexes using the passed geometry and index data.  DOES NOT ADD A "STOP BIT" FOR ___-STRIP TYPE PRIMITIVES!  The passed indexes are 16-bit whatever the receiver's `indexType`, and are written as given, not offset; a passed `0xFFFF` always means restart, since 65,535 can be no vertex of a 16-bit caller's, and is written as the receiver's `restartIndex` (`0xFFFFFFFF` in a 32-bit object).  Returns NO, with nothing written, if the receiver's buffers lack room for the points or the indexes, or if the points would take `geometryBufferVertexCount` past `maxVertexCount`.
- (BOOL) encodeRawPoints:(NSPoint *)inPoints count:(uint32_t)inPointsCount indexes:(uint16_t*)inIndexes count:(uint32_t)inIndexesCount withColor:(NSColor *)inColor;


///	Encodes drawing commands to draw the outline of an arc matching the passed description.  Start and end value units are in radians.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry, because the receiver's buffers aren't large enough, or because the new vertexes would pass the receiver's `maxVertexCount`).
- (BOOL) encodeStrokedArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians lineWidth:(float)inLineWidth strokeColor:(NSColor * __nullable)inColor;
///	This method calculates how many vertexes and indexes are required to draw the stroke of an arc with the passed dimensions, and updates 'outVtxCount' and 'outIdxCount' accordingly.  This method exists because you need to know the number of vertexes/indexes to make an instance of CMVMTLDrawObject.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forStrokedArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians forPrimitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Encodes drawing commands to draw a filled arc matching the passed description.  Start and end value units are in radians.  The arc takes its share, rounded up and at least one, of the segments the whole circle is cut into, one per 8 pixels of circumference rounded up; its vertexes are the segments' ends, and under the two triangle types its center is one more vertex after them.  As points each vertex is one index, as lines each segment is two, as a line strip the vertexes run in turn and end in a restart, as triangles each segment is one triangle of its two ends and the center with no restart, and as a triangle strip the center and each vertex alternate and end in a restart.  It writes exactly the vertexes and indexes ``updateVertexCount:indexCount:forFilledArcWithCenter:radius:start:end:forPrimitiveType:`` counts, and names only the vertexes it adds.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry, because the receiver's buffers aren't large enough, or because the new vertexes would pass the receiver's `maxVertexCount`).
- (BOOL) encodeFilledArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians fillColor:(NSColor * __nullable)inColor;
///	This method calculates how many vertexes and indexes are required to draw a filled arc with the passed dimensions, exactly as many as ``encodeFilledArcWithCenter:radius:start:end:fillColor:`` writes under the passed primitive type, and adds them to 'outVtxCount' and 'outIdxCount'.  This method exists because you need to know the number of vertexes/indexes to make an instance of CMVMTLDrawObject.  Returns NO, with neither count changed, if the radius is not positive, if the arc has no finite number of segments, or if either total would not fit in a `uint32_t`.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forFilledArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians forPrimitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Encodes drawing commands to draw a stroked circle (or portion thereof) matching the passed description.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry, because the receiver's buffers aren't large enough, or because the new vertexes would pass the receiver's `maxVertexCount`).
- (BOOL) encodeStrokedCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius lineWidth:(float)inLineWidth strokeColor:(NSColor * __nullable)inColor;
///	This method calculates how many vertexes and indexes are required to draw a stroked circle with the passed dimensions, and updates 'outVtxCount' and 'outIdxCount' accordingly.  This method exists because you need to know the number of vertexes/indexes to make an instance of CMVMTLDrawObject.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forStrokedCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius forPrimitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Encodes drawing commands to draw a filled circle matching the passed description.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry, because the receiver's buffers aren't large enough, or because the new vertexes would pass the receiver's `maxVertexCount`).
- (BOOL) encodeFilledCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius fillColor:(NSColor * __nullable)inColor;
///	This method calculates how many vertexes and indexes are required to draw a filled circle with the passed dimensions, and updates 'outVtxCount' and 'outIdxCount' accordingly.  This method exists because you need to know the number of vertexes/indexes to make an instance of CMVMTLDrawObject.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forFilledCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius forPrimitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Adds a primitive restart index value (`restartIndex`, under the receiver's `indexType`) to the indexes.
- (BOOL) encodePrimitiveRestartIndex;

///	The receiver will execute its drawing commands in the passed render encoder/command buffer, under its `indexType`.  Note: this method is ONLY safe to use if your frag shader accepts a single texture argument (like "texture2d<float,access::sample> inTexVar [[ texture(XXX) ]]")
- (void) executeInRenderEncoder:(id<MTLRenderCommandEncoder>)inEnc commandBuffer:(id<MTLCommandBuffer>)inCB;
///	The receiver will execute its drawing commands using the passed encoders, under its `indexType`.  Note: this method is ONLY safe to use if your frag shader accepts a single texture POINTER argument (like "device CustomMetalViewTexture * inTextures [[buffer(XXX)]]", where "CustomMetalTextureView" is defined as a struct with a texture member...)
- (void) executeInRenderEncoder:(id<MTLRenderCommandEncoder>)inEnc textureArgumentEncoder:(id<MTLArgumentEncoder>)inTexArgEnc commandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
