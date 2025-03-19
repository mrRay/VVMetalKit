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





@interface CMVMTLDrawObject : NSObject

///	Creates an instance of this class with a known buffer size in bytes.  Defaults to triangle strip drawing (`MTLPrimitiveTypeTriangleStrip`).
+ (instancetype) createWithGeometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize;
///	If you know the number of vertexes and the number of indexes used to draw those vertexes, you can use this method to create an instance of this class.  Defaults to triangle strip drawing (`MTLPrimitiveTypeTriangleStrip`).
+ (instancetype) createWithGeometryBufferCount:(uint32_t)inVertCount indexBufferCount:(uint32_t)inIndexCount;

///	This is the "main" init method- other create/init methods use this "under the hood".  Don't feel like you need to use this method directly, the 'create' methods are faster.
- (instancetype) initWithPrimitiveType:(MTLPrimitiveType)inPrimType geometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize;

- (instancetype) initWithGeometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize;
- (instancetype) initWithGeometryBufferCount:(uint32_t)inVertCount indexBufferCount:(uint32_t)inIndexCount;

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
///	The address in 'indexBuffer' at which the next write should occur (updated automatically via the various 'encode' methods).
@property (readonly) void * indexBufferHead;

@property (readonly) uint32_t availableVertexes;
@property (readonly) uint32_t availableIndexes;

///	Images that are encoded (via `-[CMVMTLDrawObject encodeQuad:withImage:texIndex:color:]`) are stored here for the lifetime of the receiver
@property (strong) NSMutableDictionary<NSNumber*,id<VVMTLTextureImage>> * images;

///	Copies the draw data from the passed draw object into the receiver.  The passed draw object must have the same primitive type as the receiver!
- (BOOL) appendDrawCommandsFrom:(CMVMTLDrawObject *)n;

///	Generates geometry to draw a quad matching the passed values (using the receiver's primitive type) and appends it to the receiver's geometry and index buffers.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry or because the receiver's buffers aren't large enough).
- (BOOL) encodeQuad:(NSRect)inRect withColor:(NSColor *)inColor;
///	Generates geometry for drawing a quad with the passed rect that will draw using the passed texture.  Caller is responsible for incrementing and tracking 'inTexIndex', which should start at '0'.  The passed texture will be retained for the lifetime of the receiver, and will be associated with 'inTexIndex' for that duration.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry or because the receiver's buffers aren't large enough).
- (BOOL) encodeQuad:(NSRect)inRect withImage:(__nullable id<VVMTLTextureImage>)inImg texIndex:(int8_t)inTexIndex;
- (BOOL) encodeQuad:(NSRect)inRect withImage:(id<VVMTLTextureImage> __nullable)inImg texIndex:(int8_t)inTexIndex color:(NSColor * __nullable)inColor;
///	This method calculates the number of vertexes and indexes needed to draw the passed quad, and updates 'outVtxCount' and 'outIdxCount' accordingly.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry or because the receiver's buffers aren't large enough).
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forQuad:(NSRect)inRect primitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Generates geometry for drawing the outline of the passed quad using a line with the passed width and color.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry or because the receiver's buffers aren't large enough).
- (BOOL) encodeStrokedQuad:(NSRect)inRect strokeWidth:(float)inStrokeWidth strokeColor:(NSColor *)inColor;
///	This method calculates the number of vertexes and indexes needed to stroke the passed quad, and updates 'outVtxCount' and 'outIdxCount' accordingly.  Returns 'NO' if there's a problem calculating the number of vertexes/indexes.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forStrokedQuad:(NSRect)inRect primitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Generates geometry for drawing a diamond in the passed rect with the passed color as its fill.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry or because the receiver's buffers aren't large enough).
- (BOOL) encodeDiamond:(NSRect)inRect withColor:(NSColor *)inColor;
///	Generates geometry for stroking (drawing the outline of) the passed rec with a line of the passed width and color.
- (BOOL) encodeStrokedDiamond:(NSRect)inRect strokeWidth:(float)inStrokeWidth strokeColor:(NSColor *)inColor;


///	Generates geometry to draw a line matching the passed values (using the receiver's primitive type) and appends it to the receiver's gemoetry and index buffers.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry or because the receiver's buffers aren't large enough).
- (BOOL) encodePointsAsLine:(NSPoint *)inPoints count:(uint32_t)inPointsCount lineWidth:(float)inLineWidth lineColor:(NSColor * __nullable)inColor;
///	This method calculates the number of vertexes and indexes required to draw an arbitrary number of points as a line using the passed primitive type.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forPointsAsLineCount:(uint32_t)inPointsCount primitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Makes sure the receiver can accommodate the passed data, then populated vertexes using the passed geometry and index data.  DOES NOT ADD A "STOP BIT" FOR ___-STRIP TYPE PRIMITIVES!
- (BOOL) encodeRawPoints:(NSPoint *)inPoints count:(uint32_t)inPointsCount indexes:(uint16_t*)inIndexes count:(uint32_t)inIndexesCount withColor:(NSColor *)inColor;


///	Encodes drawing commands to draw the outline of an arc matching the passed description.  Start and end value units are in radians.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry or because the receiver's buffers aren't large enough).
- (BOOL) encodeStrokedArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians lineWidth:(float)inLineWidth strokeColor:(NSColor * __nullable)inColor;
///	This method calculates how many vertexes and indexes are required to draw the stroke of an arc with the passed dimensions, and updates 'outVtxCount' and 'outIdxCount' accordingly.  This method exists because you need to know the number of vertexes/indexes to make an instance of CMVMTLDrawObject.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forStrokedArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians forPrimitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Encodes drawing commands to draw a filled arc matching the passed description.  Start and end value units are in radians.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry or because the receiver's buffers aren't large enough).
- (BOOL) encodeFilledArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians fillColor:(NSColor * __nullable)inColor;
///	This method calculates how many vertexes and indexes are required to draw a filled arc with the passed dimensions, and updates 'outVtxCount' and 'outIdxCount' accordingly.  This method exists because you need to know the number of vertexes/indexes to make an instance of CMVMTLDrawObject.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forFilledArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians forPrimitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Encodes drawing commands to draw a stroked circle (or portion thereof) matching the passed description.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry or because the receiver's buffers aren't large enough).
- (BOOL) encodeStrokedCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius lineWidth:(float)inLineWidth strokeColor:(NSColor * __nullable)inColor;
///	This method calculates how many vertexes and indexes are required to draw a stroked circle with the passed dimensions, and updates 'outVtxCount' and 'outIdxCount' accordingly.  This method exists because you need to know the number of vertexes/indexes to make an instance of CMVMTLDrawObject.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forStrokedCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius forPrimitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Encodes drawing commands to draw a filled circle matching the passed description.  Returns NO if the data cannot be appended to the receiver's buffers (because there was an issue generating the geometry or because the receiver's buffers aren't large enough).
- (BOOL) encodeFilledCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius fillColor:(NSColor * __nullable)inColor;
///	This method calculates how many vertexes and indexes are required to draw a filled circle with the passed dimensions, and updates 'outVtxCount' and 'outIdxCount' accordingly.  This method exists because you need to know the number of vertexes/indexes to make an instance of CMVMTLDrawObject.
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forFilledCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius forPrimitiveType:(MTLPrimitiveType)inPrimitiveType;


///	Adds a primitive restart index value to the indexes.
- (BOOL) encodePrimitiveRestartIndex;

///	The receiver will execute its drawing commands in the passed render encoder/command buffer.  Note: this command will only produce the desired output if your drawing commands don't make use of multiple textures, and the render pipeline declares a single texture input.
- (void) executeInRenderEncoder:(id<MTLRenderCommandEncoder>)inEnc commandBuffer:(id<MTLCommandBuffer>)inCB;
///	The receiver will execute its drawing commands using the passed encoders.  If your draw object makes use of multiple textures, you need to use this method and ensure that your render pipeline is expecting an array of textures on a single argument to your shader- if you don't, the textures won't appear as intended.
- (void) executeInRenderEncoder:(id<MTLRenderCommandEncoder>)inEnc textureArgumentEncoder:(id<MTLArgumentEncoder>)inTexArgEnc commandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
