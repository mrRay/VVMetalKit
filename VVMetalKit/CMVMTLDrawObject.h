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

//	creates an instance of this class with a known buffer size in bytes.  defaults to triangle strip drawing.
+ (instancetype) createWithGeometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize;
//	if you know the number of vertexes and the number of indexes used to draw those vertexes, you can use this method to create an instance of this class.  defaults to triangle strip drawing.
+ (instancetype) createWithGeometryBufferCount:(uint32_t)inVertCount indexBufferCount:(uint32_t)inIndexCount;

//	this is the "main" init method- other create/init methods use this "under the hood".  don't feel like you need to use this method directly.
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
//	generates geometry for drawing a quad with the passed rect that will draw using the passed texture.  caller is responsible for incrementing and tracking 'inTexIndex', which should start at '0'.  the passed texture will be retained for the lifetime of the receiver, and will be associated with 'inTexIndex' for that duration.
- (BOOL) encodeQuad:(NSRect)inRect withImage:(__nullable id<VVMTLTextureImage>)inImg texIndex:(int8_t)inTexIndex;
- (BOOL) encodeQuad:(NSRect)inRect withImage:(id<VVMTLTextureImage> __nullable)inImg texIndex:(int8_t)inTexIndex color:(NSColor * __nullable)inColor;
//	this method calculates the number of vertexes and indexes needed to draw the passed quad, and updates 'outVtxCount' and 'outIdxCount' accordingly
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forQuad:(NSRect)inRect primitiveType:(MTLPrimitiveType)inPrimitiveType;


//	generates geometry for drawing the outline of the passed quad using a line with the passed width and color.
- (BOOL) encodeStrokedQuad:(NSRect)inRect strokeWidth:(float)inStrokeWidth strokeColor:(NSColor *)inColor;
//	this method calculates the number of vertexes and indexes needed to stroke the passed quad, and updates 'outVtxCount' and 'outIdxCount' accordingly
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forStrokedQuad:(NSRect)inRect primitiveType:(MTLPrimitiveType)inPrimitiveType;


//	generates geometry for drawing a diamond in the passed rect with the passed color as its fill
- (BOOL) encodeDiamond:(NSRect)inRect withColor:(NSColor *)inColor;
//	generates geometry for stroking (drawing the outline of) the passed rec with a line of the passed width and color.
- (BOOL) encodeStrokedDiamond:(NSRect)inRect strokeWidth:(float)inStrokeWidth strokeColor:(NSColor *)inColor;


//	generates geometry to draw a line matching the passed values (using the receiver's primitive type) and appends it to the receiver's gemoetry and index buffers.  returns NO if the data cannot be appended to the receiver's buffers.
- (BOOL) encodePointsAsLine:(NSPoint *)inPoints count:(uint32_t)inPointsCount lineWidth:(float)inLineWidth lineColor:(NSColor * __nullable)inColor;
//	this method calculates the number of vertexes and indexes required to draw an arbitrary number of points as a line using the passed primitive type
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forPointsAsLineCount:(uint32_t)inPointsCount primitiveType:(MTLPrimitiveType)inPrimitiveType;


//	makes sure the receiver can accommodate the passed data, then populated vertexes using the passed geometry and index data.  DOES NOT ADD A "STOP BIT" FOR ___-STRIP TYPE PRIMITIVES!
- (BOOL) encodeRawPoints:(NSPoint *)inPoints count:(uint32_t)inPointsCount indexes:(uint16_t*)inIndexes count:(uint32_t)inIndexesCount withColor:(NSColor *)inColor;


//	encodes drawing commands to draw the outline of an arc matching the passed description
- (BOOL) encodeStrokedArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians lineWidth:(float)inLineWidth strokeColor:(NSColor * __nullable)inColor;
//	this method calculates how many vertexes and indexes are required to draw the stroke of an arc with the passed dimensions, and updates 'outVtxCount' and 'outIdxCount' accordingly.  this method exists because you need to know the number of vertexes/indexes to make an instance of CMVMTLDrawObject.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forStrokedArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians forPrimitiveType:(MTLPrimitiveType)inPrimitiveType;


//	encodes drawing commands to draw a filled arc matching the passed description
- (BOOL) encodeFilledArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians fillColor:(NSColor * __nullable)inColor;
//	this method calculates how many vertexes and indexes are required to draw a filled arc with the passed dimensions, and updates 'outVtxCount' and 'outIdxCount' accordingly.  this method exists because you need to know the number of vertexes/indexes to make an instance of CMVMTLDrawObject.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forFilledArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians forPrimitiveType:(MTLPrimitiveType)inPrimitiveType;


//	encodes drawing commands to draw a stroked circle (or portion thereof) matching the passed description.
- (BOOL) encodeStrokedCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius lineWidth:(float)inLineWidth strokeColor:(NSColor * __nullable)inColor;
//	this method calculates how many vertexes and indexes are required to draw a stroked circle with the passed dimensions, and updates 'outVtxCount' and 'outIdxCount' accordingly.  this method exists because you need to know the number of vertexes/indexes to make an instance of CMVMTLDrawObject.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forStrokedCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius forPrimitiveType:(MTLPrimitiveType)inPrimitiveType;


//	encodes drawing commands to draw a filled circle (or portion thereof) matching the passed description.
- (BOOL) encodeFilledCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius fillColor:(NSColor * __nullable)inColor;
//	this method calculates how many vertexes and indexes are required to draw a filled circle with the passed dimensions, and updates 'outVtxCount' and 'outIdxCount' accordingly.  this method exists because you need to know the number of vertexes/indexes to make an instance of CMVMTLDrawObject.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forFilledCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius forPrimitiveType:(MTLPrimitiveType)inPrimitiveType;


//	adds a primitive restart index value to the indexes.
- (BOOL) encodePrimitiveRestartIndex;

//	the receiver will execute its drawing commands in the passed render encoder/command buffer.  note: this command will only produce the desired output if your drawing commands don't make use of textures!
- (void) executeInRenderEncoder:(id<MTLRenderCommandEncoder>)inEnc commandBuffer:(id<MTLCommandBuffer>)inCB;
//	the receiver will execute its drawing commands using the passed encoders.  if your draw object makes use of textures, you need to use this method- if you don't, the textures won't appear as intended.
- (void) executeInRenderEncoder:(id<MTLRenderCommandEncoder>)inEnc textureArgumentEncoder:(id<MTLArgumentEncoder>)inTexArgEnc commandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
