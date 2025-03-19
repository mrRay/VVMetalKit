//
//  VVMTLDrawObject.m
//  VVMetalKit
//
//  Created by testadmin on 5/15/23.
//

#import "CMVMTLDrawObject.h"

#import <Accelerate/Accelerate.h>

//#import "VVMTLPool.h"
//#import "VVMTLBuffer.h"

//#import <VVCore/VVCore.h>
//#import <VVFontAtlas/VVFontAtlas.h>
//#import <VVUIToolbox/VVUIToolbox.h>
//#import <VVUIToolbox/VVSpriteMTLViewShaderTypes.h>




//#define PI (3.1415926535897932384626433832795)
//const float DEG2RAD = (PI/180.);
//const float RAD2DEG = (180./PI);

//	change this to make the curves drawn by this class "smoother" (lower numbers are smoother), at the expense of 
//	requiring more geometry data- think we can probably just define a sane value here?
#define ARC_PIXELS_PER_SEGMENT 8.

//	these macros are ripped from VVCore- they're isolated, this isn't a header, and i don't want to add a dependency...
//	NSRect/Point/Size/etc and CGRect/Point/Size are functionally identical, but cast differently.  these macros provide a single interface for this functionality to simplify things.
#if TARGET_OS_IPHONE
#define VVPOINT CGPoint
#define VVMAKEPOINT CGPointMake
#define VVRECT CGRect
#define VVSIZE CGSize
#define VVMAKESIZE CGSizeMake
#else
#define VVPOINT NSPoint
#define VVMAKEPOINT NSMakePoint
#define VVINSETRECT NSInsetRect
#define VVRECT NSRect
#define VVSIZE NSSize
#define VVMAKESIZE NSMakeSize
#endif
//	macros for calculating rect coords
#define VVADDPOINT(a,b) (VVMAKEPOINT((a.x+b.x),(a.y+b.y)))
#define VVSUBPOINT(a,b) (VVMAKEPOINT((a.x-b.x),(a.y-b.y)))
//	when we're creating, moving, and sizing rects, it's useful to be able to specify the operations relative to anchor points on the rects.
typedef NS_ENUM(NSUInteger, VVRectAnchor)	{
	VVRectAnchor_Center = 0,
	VVRectAnchor_TL,	//	top-left corner
	VVRectAnchor_TR,	//	top-right corner
	VVRectAnchor_BL,	//	bottom-left corner
	VVRectAnchor_BR,	//	bottom-right corner
	VVRectAnchor_TM,	//	middle of top top side
	VVRectAnchor_RM,	//	middle of right side
	VVRectAnchor_BM,	//	middle of bottom side
	VVRectAnchor_LM		//	middle of left side
};
static inline VVPOINT VVRectGetAnchorPoint(VVRECT inRect, VVRectAnchor inAnchor);
static inline VVPOINT VVRectGetAnchorPoint(VVRECT inRect, VVRectAnchor inAnchor)	{
	VVPOINT		returnMe = inRect.origin;
	switch (inAnchor)	{
	case VVRectAnchor_Center:	returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(inRect.size.width/2.,inRect.size.height/2.) );		break;
	case VVRectAnchor_TL:		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(0., inRect.size.height) );		break;
	case VVRectAnchor_TR:		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(inRect.size.width, inRect.size.height) );		break;
	case VVRectAnchor_BL:
		//	do nothing- rect's origin is already the bottom left!
		break;
	case VVRectAnchor_BR:		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(inRect.size.width, 0.) );		break;
	case VVRectAnchor_TM:		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(inRect.size.width/2., inRect.size.height) );		break;
	case VVRectAnchor_RM:		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(inRect.size.width, inRect.size.height/2.) );		break;
	case VVRectAnchor_BM:		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(inRect.size.width/2., 0.) );		break;
	case VVRectAnchor_LM:		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(0., inRect.size.height/2.) );		break;
	}
	return returnMe;
}
//	simple bitmask check
#define A_HAS_B(a,b) (((a)&(b))==(b))




//	NSThread.currentThread.threadDictionary stores, at this key, an instance of NSMutableData that it uses to cache intermediate points
static const NSString * kCVMTLDrawObjectDataBuffer = @"kCVMTLDrawObjectDataBuffer";
//	...same as above, but we need another buffer for the 'arc' methods (because they call into another method which uses the normal, non-arc buffer)
static const NSString * kCVMTLDrawObjectArcDataBuffer = @"kCVMTLDrawObjectArcDataBuffer";








/*
	VVLWSegment = "vidvox line width segment".
	
	- Metal doesn't let you customize the width of the lines it draws- so if we want to draw fat lines, we need 
	to draw really thin quads instead of lines.
	- VVLWSegment is an intermediate processing struct for a single line segment drawn using a quad
	- "A" and "B" are the original points of the line segment
	
	WHEN INITIALLY POPULATED....
	- "P" and "Q" are equidistant from "A" and PQ is at right angles to AB.
	- "R" and "S" are equidistant from "B" and RS is at right angles to AB.
	- AP and AQ and BR and BS all have the same length
	
	P			   R
	|			   |
	A - - - - - - -B
	|			   |
	Q			   S
	
	PLEASE NOTE....
	- after being initially populated with coordinates that describe a rectangle, the array of VVLWSegments is 
	processed to find where the various lines intersect so the number of vertices can be reduced (adjacent line 
	segments share a vertetex- two vertexes, as we're drawing a quad for each line segment).
*/
typedef struct VVLWSegment	{
	NSPoint		a;	//	the original "starting point" of this line segment
	NSPoint		b;	//	the original "end point" of this line segment
	
	NSPoint		p;	//	the top starting vertex for this segment (TL)
	NSPoint		q;	//	the bottom starting vertex for this segment (BL)
	NSPoint		r;	//	the top ending vertex for this segment (TR)
	NSPoint		s;	//	the bottom ending vertex for this segment (BR)
} VVLWSegment;




/*
	Calculates geometry!
	
				   C
				   |
	A - - - - - - -B
				   |
				   D

	- Points "A" and "B" form a line segment
	- Point "C" is "inDistance" units away from point "B", at a right angle to the line segment AB (turning left)
	- Point "D" is "inDistance" units away from point "B", at a right angle to the line segment AB (turning right)
	- This function calculates point C and D, and populates the ptr passed in the function with this data
*/
BOOL LineSegmentAsQuadNormalsForLineSegmentPoints(NSPoint *inAPtr, NSPoint *inBPtr, float inDistance, NSPoint *outCPtr, NSPoint *outDPtr);




//	credit: taken from https://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect
//	original author said it's based on Andre LeMothe's "Tricks of the Windows Game Programming Gurus"
// Returns 1 if the lines intersect, otherwise 0. In addition, if the lines 
// intersect the intersection point may be stored in the floats i_x and i_y.
char get_line_intersection(
	float p0_x, float p0_y,
	float p1_x, float p1_y,
	float p2_x, float p2_y,
	float p3_x, float p3_y,
	float *i_x, float *i_y);




@implementation CMVMTLDrawObject

+ (instancetype) createWithGeometryBufferSizeInBytes:(uint32_t)inGeoSize indexBufferSizeInBytes:(uint32_t)inIndexSize	{
	return [[CMVMTLDrawObject alloc] initWithGeometryBufferSizeInBytes:inGeoSize indexBufferSizeInBytes:inIndexSize];
}
+ (instancetype) createWithGeometryBufferCount:(uint32_t)inVertCount indexBufferCount:(uint32_t)inIndexCount	{
	return [[CMVMTLDrawObject alloc] initWithGeometryBufferCount:inVertCount indexBufferCount:inIndexCount];
}

- (instancetype) initWithPrimitiveType:(MTLPrimitiveType)inPrimType geometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize	{
	self = [super init];
	if (inDrawSize < 1 || inIndexSize < 1)
		self = nil;
	if (self != nil)	{
		_primitiveType = inPrimType;
		_geometryBuffer = [VVMTLPool.global bufferWithLength:inDrawSize storage:MTLStorageModeShared];
		_indexBuffer = [VVMTLPool.global bufferWithLength:inIndexSize storage:MTLStorageModeShared];
		_geometryBufferBytesPerVertex = 0;
		_geometryBufferVertexCount = 0;
		_indexBufferIndexCount = 0;
		
		_images = [[NSMutableDictionary alloc] init];
		self.geometryBufferBytesPerVertex = sizeof(CMVSimpleVertex);
	}
	return self;
}

- (instancetype) initWithGeometryBufferSizeInBytes:(uint32_t)inDrawSize indexBufferSizeInBytes:(uint32_t)inIndexSize	{
	return [self initWithPrimitiveType:MTLPrimitiveTypeTriangleStrip geometryBufferSizeInBytes:inDrawSize indexBufferSizeInBytes:inIndexSize];
}
- (instancetype) initWithGeometryBufferCount:(uint32_t)inVertCount indexBufferCount:(uint32_t)inIndexCount	{
	return [self
		initWithPrimitiveType:MTLPrimitiveTypeTriangleStrip
		geometryBufferSizeInBytes:sizeof(CMVSimpleVertex)*inVertCount
		indexBufferSizeInBytes:sizeof(uint16_t)*inIndexCount];
}

- (void *) geometryBufferHead	{
	void		*base = _geometryBuffer.buffer.contents;
	return (base + (_geometryBufferVertexCount * _geometryBufferBytesPerVertex));
}
- (void *) indexBufferHead	{
	void		*base = _indexBuffer.buffer.contents;
	return (base + (_indexBufferIndexCount * sizeof(uint16_t)));
}
- (uint32_t) availableVertexes	{
	uint32_t		maxVertexCount = (uint32_t)_geometryBuffer.buffer.length / _geometryBufferBytesPerVertex;
	return maxVertexCount - _geometryBufferVertexCount;
}
- (uint32_t) availableIndexes	{
	uint32_t		maxIndexCount = (uint32_t)_indexBuffer.buffer.length / 2;
	return maxIndexCount - _indexBufferIndexCount;
}
- (BOOL) appendDrawCommandsFrom:(CMVMTLDrawObject *)n	{
	if (n == nil)	{
		return NO;
	}
	if (n.primitiveType != self.primitiveType)	{
		NSLog(@"ERR: primitive type mismatch, %s",__func__);
		return NO;
	}
	uint32_t		incomingVertexCount = n.geometryBufferVertexCount;
	uint32_t		incomingIndexCount = n.indexBufferIndexCount;
	if (self.availableVertexes < incomingVertexCount)	{
		NSLog(@"ERR: not enough space in geometry buffer, %s",__func__);
		return NO;
	}
	if (self.availableIndexes < incomingIndexCount)	{
		NSLog(@"ERR: not enough space in index buffer, %s",__func__);
		return NO;
	}
	
	//	the index buffers in the draw object we were passed are relative to the draw object's indexes- we have to offset to get the indexes relative to the receiver!
	uint32_t		incomingVertexOffset = self.geometryBufferVertexCount;
	
	memcpy( self.geometryBufferHead, n.geometryBuffer.buffer.contents, incomingVertexCount * n.geometryBufferBytesPerVertex );
	
	//memcpy( self.indexBufferHead, n.indexBuffer.buffer.contents, incomingIndexCount * 2 );
	uint16_t		*wPtr = self.indexBufferHead;
	uint16_t		*rPtr = n.indexBuffer.buffer.contents;
	for (int i=0; i<incomingIndexCount; ++i)	{
		if (*rPtr == 0xFFFF)
			*wPtr = 0xFFFF;
		else
			*wPtr = ((*rPtr) + incomingVertexOffset);
		++rPtr;
		++wPtr;
	}
	
	self.geometryBufferVertexCount = self.geometryBufferVertexCount + incomingVertexCount;
	self.indexBufferIndexCount = self.indexBufferIndexCount + incomingIndexCount;
	
	return YES;
}

- (BOOL) encodeQuad:(NSRect)inRect withColor:(NSColor *)inColor	{
	return [self encodeQuad:inRect withImage:nil texIndex:-1 color:inColor];
}
- (BOOL) encodeQuad:(NSRect)inRect withImage:(id<VVMTLTextureImage>)inImg texIndex:(int8_t)inTexIndex	{
	return [self encodeQuad:inRect withImage:inImg texIndex:inTexIndex color:nil];
}
- (BOOL) encodeQuad:(NSRect)inRect withImage:(id<VVMTLTextureImage>)inImg texIndex:(int8_t)inTexIndex color:(NSColor *)inColor	{
	//	figure out how large the geometry and index buffers will need to be to accommodate these draw calls
	uint32_t		geometryBufferVertexCount = self.geometryBufferVertexCount;
	uint32_t		newGeometryBufferVertexCount = geometryBufferVertexCount;
	uint32_t		indexBufferIndexCount = self.indexBufferIndexCount;
	uint32_t		newIndexBufferIndexCount = indexBufferIndexCount;
	uint32_t		bytesPerIndex = 2;
	
	switch (self.primitiveType)	{
	case MTLPrimitiveTypePoint:
		{
			newGeometryBufferVertexCount = geometryBufferVertexCount + 4;
			newIndexBufferIndexCount = indexBufferIndexCount + 4;	//	4 idxs
		}
		break;
	case MTLPrimitiveTypeLine:
		{
			newGeometryBufferVertexCount = geometryBufferVertexCount + 4;
			newIndexBufferIndexCount = indexBufferIndexCount + 8;	//	(2 idxs) x 4
		}
		break;
	case MTLPrimitiveTypeLineStrip:
		{
			newGeometryBufferVertexCount = geometryBufferVertexCount + 4;
			newIndexBufferIndexCount = indexBufferIndexCount + 6;	//	4 idxs + 1 idx (back to first point) + 1 stop bit
		}
		break;
	case MTLPrimitiveTypeTriangle:
		{
			newGeometryBufferVertexCount = geometryBufferVertexCount + 4;
			//newIndexBufferIndexCount = _indexBufferIndexCount + 8;	//	3 idxs + 1 stop bit + 3 idxs + 1 stop bit = 8 idxs
			newIndexBufferIndexCount = indexBufferIndexCount + 6;	//	3 idxs + 3 idxs = 6 idxs
		}
		break;
	case MTLPrimitiveTypeTriangleStrip:
		{
			newGeometryBufferVertexCount = geometryBufferVertexCount + 4;
			newIndexBufferIndexCount = indexBufferIndexCount + 5;	//	4 idxs + 1 stop bit
		}
		break;
	}
	
	//	make sure that our geometry and index buffers are large enough to accommodate the additional data
	uint32_t		tmpMaxGeoSize = newGeometryBufferVertexCount * self.geometryBufferBytesPerVertex;
	uint32_t		tmpMaxIndexSize = newIndexBufferIndexCount * bytesPerIndex;
	if (tmpMaxGeoSize > self.geometryBuffer.buffer.length)	{
		NSLog(@"ERR: encode would be beyond buffer length, %s",__func__);
		return NO;
	}
	if (tmpMaxIndexSize > self.indexBuffer.buffer.length)	{
		NSLog(@"ERR: encode would be beyond index length, %s",__func__);
		return NO;
	}
	
	//	assemble data structures required to describe the quad's geometry and texture coordinates
	NSRect			inImgSrcRect = NSMakeRect(0,0,1,1);	//	set to these vals so if there's a nil img we default to populating tex coords with normalized vals
	
	const VVRectAnchor		normalOrder[] = { VVRectAnchor_TL, VVRectAnchor_BL, VVRectAnchor_TR, VVRectAnchor_BR };
	const VVRectAnchor		flipVOrder[] = { VVRectAnchor_BL, VVRectAnchor_TL, VVRectAnchor_BR, VVRectAnchor_TR };
	const VVRectAnchor		flipHOrder[] = { VVRectAnchor_TR, VVRectAnchor_BR, VVRectAnchor_TL, VVRectAnchor_BL };
	const VVRectAnchor		flipHAndVOrder[] = { VVRectAnchor_BR, VVRectAnchor_TR, VVRectAnchor_BL, VVRectAnchor_TL };
	
	const VVRectAnchor		*geoRPtr = normalOrder;
	const VVRectAnchor		*texRPtr = normalOrder;
	
	//	get the color vals
	vector_float4		colors_vec = Vec4FromNSColor(inColor);
	
	//	get the properties needed to populate the vertex's texture data
	if (inImg != nil)	{
		//	make sure it's retained (along with the index at which it needs to be attached to the shader)
		[_images setObject:inImg forKey:@(inTexIndex)];
		
		inImgSrcRect = inImg.srcRect;
		
		//	figure out whether or not the image in the buffer is flipped
		BOOL		bufferVFlippedness = inImg.flipV;
		bufferVFlippedness = !bufferVFlippedness;	//	flip the buffer vertically because access to textures in metal has the origin at the top left corner
		BOOL		bufferHFlippedness = inImg.flipH;
		
		//	select the array of anchors in the appropriate order to display the image correctly
		if (bufferVFlippedness && bufferHFlippedness)	{
			texRPtr = flipHAndVOrder;
		}
		else if (bufferVFlippedness)	{
			texRPtr = flipVOrder;
		}
		else if (bufferHFlippedness)	{
			texRPtr = flipHOrder;
		}
	}
	
	//	get the base geometry buffer ptr, figure out where to write into it
	CMVSimpleVertex		*rawGeoVert = (CMVSimpleVertex *)self.geometryBuffer.buffer.contents;
	CMVSimpleVertex		*baseGeoVert = rawGeoVert + geometryBufferVertexCount;
	
	//	get the base index buffer ptr, figure out where to write into it
	uint16_t		*rawIdxPtr = (uint16_t *)self.indexBuffer.buffer.contents;
	uint16_t		*baseIdxPtr = rawIdxPtr + indexBufferIndexCount;
	
	//	populate geometry buffer with data that describes this quad/img- this is consistent for all primitive types...
	for (int i=0; i<4; ++i)	{
		NSPoint		tmpPoint;
		CMVSimpleVertex		*wPtr = baseGeoVert + i;
		
		tmpPoint = VVRectGetAnchorPoint(inRect, *(geoRPtr+i));
		wPtr->position = simd_make_float4(tmpPoint.x, tmpPoint.y, 0., 1.);
		
		tmpPoint = VVRectGetAnchorPoint(inImgSrcRect, *(texRPtr+i));
		wPtr->texCoord = simd_make_float2(tmpPoint.x, tmpPoint.y);
		
		wPtr->color = colors_vec;
		wPtr->texIndex = inTexIndex;
	}
	
	//	populate the indexes that describe the order in which to draw the geometry data we just calculated
	switch (self.primitiveType)	{
	case MTLPrimitiveTypePoint:
		{
			//	populate the index buffers
			*(baseIdxPtr + 0) = (geometryBufferVertexCount + 0);
			*(baseIdxPtr + 1) = (geometryBufferVertexCount + 1);
			*(baseIdxPtr + 2) = (geometryBufferVertexCount + 2);
			*(baseIdxPtr + 3) = (geometryBufferVertexCount + 3);
			
			//	update the respective vertex counts
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	case MTLPrimitiveTypeLine:
		{
			//	populate the index buffers
			*(baseIdxPtr + 0) = (geometryBufferVertexCount + 0);	//	TL
			*(baseIdxPtr + 1) = (geometryBufferVertexCount + 1);	//	BL
			
			*(baseIdxPtr + 2) = (geometryBufferVertexCount + 1);	//	BL
			*(baseIdxPtr + 3) = (geometryBufferVertexCount + 3);	//	BR
			
			*(baseIdxPtr + 4) = (geometryBufferVertexCount + 3);	//	BR
			*(baseIdxPtr + 5) = (geometryBufferVertexCount + 2);	//	TR
			
			*(baseIdxPtr + 6) = (geometryBufferVertexCount + 2);	//	TR
			*(baseIdxPtr + 7) = (geometryBufferVertexCount + 0);	//	TL
			
			//	update the respective vertex counts
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	case MTLPrimitiveTypeLineStrip:
		{
			//	populate the index buffers
			*(baseIdxPtr + 0) = (geometryBufferVertexCount + 0);
			*(baseIdxPtr + 1) = (geometryBufferVertexCount + 1);
			*(baseIdxPtr + 2) = (geometryBufferVertexCount + 3);
			*(baseIdxPtr + 3) = (geometryBufferVertexCount + 2);
			*(baseIdxPtr + 4) = (geometryBufferVertexCount + 0);
			*(baseIdxPtr + 5) = 0xFFFF;
			
			//	update the respective vertex counts
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	case MTLPrimitiveTypeTriangle:
		{
			//	populate the index buffers
			*(baseIdxPtr + 0) = (geometryBufferVertexCount + 0);
			*(baseIdxPtr + 1) = (geometryBufferVertexCount + 1);
			*(baseIdxPtr + 2) = (geometryBufferVertexCount + 2);
			
			*(baseIdxPtr + 3) = (geometryBufferVertexCount + 1);
			*(baseIdxPtr + 4) = (geometryBufferVertexCount + 2);
			*(baseIdxPtr + 5) = (geometryBufferVertexCount + 3);
			
			//	update the respective vertex counts
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
			
			////	populate the index buffers
			//*(baseIdxPtr + 0) = (_geometryBufferVertexCount + 0);
			//*(baseIdxPtr + 1) = (_geometryBufferVertexCount + 1);
			//*(baseIdxPtr + 2) = (_geometryBufferVertexCount + 2);
			//
			//*(baseIdxPtr + 3) = 0xFFFF;
			//
			//*(baseIdxPtr + 4) = (_geometryBufferVertexCount + 1);
			//*(baseIdxPtr + 5) = (_geometryBufferVertexCount + 2);
			//*(baseIdxPtr + 6) = (_geometryBufferVertexCount + 3);
			//
			//*(baseIdxPtr + 7) = 0xFFFF;
			//
			////	update the respective vertex counts
			//_geometryBufferVertexCount = newGeometryBufferVertexCount;
			//_indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	case MTLPrimitiveTypeTriangleStrip:
		{
			//	populate the index buffers
			*(baseIdxPtr + 0) = (geometryBufferVertexCount + 0);
			*(baseIdxPtr + 1) = (geometryBufferVertexCount + 1);
			*(baseIdxPtr + 2) = (geometryBufferVertexCount + 2);
			*(baseIdxPtr + 3) = (geometryBufferVertexCount + 3);
			*(baseIdxPtr + 4) = 0xFFFF;
			
			//	update the respective vertex counts
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	}
	
	return YES;
}
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forQuad:(NSRect)inRect primitiveType:(MTLPrimitiveType)inPrimitiveType	{
	uint32_t		vtxCount = *outVtxCount;
	uint32_t		idxCount = *outIdxCount;
	switch (inPrimitiveType)	{
	case MTLPrimitiveTypePoint:
		vtxCount += 4;
		idxCount += 4;
		break;
	case MTLPrimitiveTypeLine:
		vtxCount += 4;
		idxCount += 8;
		break;
	case MTLPrimitiveTypeLineStrip:
		vtxCount += 4;
		idxCount += 5;
		break;
	case MTLPrimitiveTypeTriangle:
		vtxCount += 4;
		idxCount += 6;
		break;
	case MTLPrimitiveTypeTriangleStrip:
		vtxCount += 4;
		idxCount += 5;
		break;
	}
	*outVtxCount = vtxCount;
	*outIdxCount = idxCount;
	return YES;
}


- (BOOL) encodeStrokedQuad:(NSRect)inRect strokeWidth:(float)inStrokeWidth strokeColor:(NSColor *)inColor	{
	//NSLog(@"%s ... %@",__func__,NSStringFromRect(inRect));
	//vector_float4		vecColor = Vec4FromNSColor(inColor);
	NSPoint			points[5] = {
		VVRectGetAnchorPoint(inRect, VVRectAnchor_TL),
		VVRectGetAnchorPoint(inRect, VVRectAnchor_BL),
		VVRectGetAnchorPoint(inRect, VVRectAnchor_BR),
		VVRectGetAnchorPoint(inRect, VVRectAnchor_TR),
		VVRectGetAnchorPoint(inRect, VVRectAnchor_TL)
	};
	return [self encodePointsAsLine:points count:5 lineWidth:inStrokeWidth lineColor:inColor];
}
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forStrokedQuad:(NSRect)inRect primitiveType:(MTLPrimitiveType)inPrimitiveType	{
	return [self updateVertexCount:outVtxCount indexCount:outIdxCount forPointsAsLineCount:5 primitiveType:inPrimitiveType];
}


- (BOOL) encodeDiamond:(NSRect)inRect withColor:(NSColor *)inColor	{
	if (self.availableVertexes < 4)	{
		NSLog(@"ERR: not enough room, %s",__func__);
		return NO;
	}
	if (self.availableIndexes < 5)	{
		NSLog(@"ERR: not enough room B, %s",__func__);
		return NO;
	}
	
	VVRectAnchor		anchorsToFetch[] = {
		VVRectAnchor_TM,
		VVRectAnchor_LM,
		VVRectAnchor_RM,
		VVRectAnchor_BM
	};
	uint16_t			baseIndexOffset = self.geometryBufferVertexCount;
	vector_float4		colorsVec = Vec4FromNSColor(inColor);
	
	CMVSimpleVertex		*vtxPtr = self.geometryBufferHead;
	uint16_t			*indexPtr = self.indexBufferHead;
	for (int i=0; i<4; ++i)	{
		NSPoint		tmpPoint = VVRectGetAnchorPoint( inRect, anchorsToFetch[i] );
		vtxPtr->color = colorsVec;
		vtxPtr->position = simd_make_float4( tmpPoint.x, tmpPoint.y, 0., 1. );
		vtxPtr->texIndex = -1;
		
		*indexPtr = baseIndexOffset + i;
		
		++vtxPtr;
		++indexPtr;
	}
	*indexPtr = 0xFFFF;
	
	self.geometryBufferVertexCount = self.geometryBufferVertexCount + 4;
	self.indexBufferIndexCount = self.indexBufferIndexCount + 5;
	
	return YES;
}
- (BOOL) encodeStrokedDiamond:(NSRect)inRect strokeWidth:(float)inStrokeWidth strokeColor:(NSColor *)inColor	{
	VVRectAnchor		anchorsToFetch[] = {
		VVRectAnchor_TM,
		VVRectAnchor_LM,
		VVRectAnchor_BM,
		VVRectAnchor_RM,
		VVRectAnchor_TM
	};
	NSPoint				pointsToStroke[5];
	for (int i=0; i<5; ++i)	{
		pointsToStroke[i] = VVRectGetAnchorPoint(inRect, anchorsToFetch[i]);
	}
	BOOL		returnMe = [self encodePointsAsLine:pointsToStroke count:5 lineWidth:inStrokeWidth lineColor:inColor];
	if (!returnMe)	{
		NSLog(@"ERR: can't encode stroke in %s",__func__);
	}
	return returnMe;
}


- (BOOL) encodePointsAsLine:(NSPoint *)inPoints count:(uint32_t)inPointsCount lineWidth:(float)inLineWidth lineColor:(NSColor * __nullable)inColor	{
	//NSLog(@"%s ... %d",__func__,inPointsCount);
	
	//NSMutableString		*mutString = [[NSMutableString alloc] init];
	//for (int i=0; i<inPointsCount; ++i)	{
	//	[mutString appendFormat:@" %@",NSStringFromPoint(*(inPoints+i))];
	//}
	//NSLog(@"\t\tpoints are %@",mutString);
	
	if (inPoints == NULL)
		return NO;
	if (inPointsCount < 2)	{
		NSLog(@"ERR: not enough points (%d), %s",inPointsCount,__func__);
		return NO;
	}
	
	//{
	//	NSMutableString		*tmpString = nil;
	//	for (int i=0; i<inPointsCount; ++i)	{
	//		NSString		*lineString = [NSString stringWithFormat:@"\t\t\t[%2.2d]- %@",i,NSStringFromPoint(*(inPoints+i))];
	//		if (tmpString == nil)	{
	//			tmpString = [[NSMutableString alloc] init];
	//		}
	//		[tmpString appendFormat:@"\r%@",lineString];
	//	}
	//	NSLog(@"\t\ton inputs, points are: %@",tmpString);
	//}
	
	//	figure out how large the geometry and index buffers will need to be to accommodate the passed geometry
	uint32_t		geometryBufferVertexCount = self.geometryBufferVertexCount;
	uint32_t		indexBufferIndexCount = self.indexBufferIndexCount;
	
	uint32_t		newGeometryBufferVertexCount = geometryBufferVertexCount;
	uint32_t		newIndexBufferIndexCount = indexBufferIndexCount;
	uint32_t		bytesPerIndex = 2;
	
	float			strokeOffset = inLineWidth / 2.0;
	
	switch (self.primitiveType)	{
	case MTLPrimitiveTypePoint:
		{
			newGeometryBufferVertexCount = geometryBufferVertexCount + inPointsCount;
			newIndexBufferIndexCount = indexBufferIndexCount + inPointsCount;	//	'inPointsCount' idxs
		}
		break;
	case MTLPrimitiveTypeLine:
		{
			newGeometryBufferVertexCount = geometryBufferVertexCount + inPointsCount;
			newIndexBufferIndexCount = indexBufferIndexCount + ((inPointsCount - 1) * 2);	//	(inPointsCount - 1) * 2 idxs
		}
		break;
	case MTLPrimitiveTypeLineStrip:
		{
			newGeometryBufferVertexCount = geometryBufferVertexCount + inPointsCount;
			newIndexBufferIndexCount = indexBufferIndexCount + inPointsCount + 1;	//	inPointsCount idxs + 1 stop bit
		}
		break;
	case MTLPrimitiveTypeTriangle:
		{
			//	draw the line as pairs of triangles making really thin quads
			newGeometryBufferVertexCount = geometryBufferVertexCount + (inPointsCount * 2);	//	we only need 2x the number of points to describe every vertex
			newIndexBufferIndexCount = indexBufferIndexCount + ((inPointsCount - 1) * 6);	//	draw one quad (3 idxs + 3 idxs) per line segment
		}
		break;
	case MTLPrimitiveTypeTriangleStrip:
		{
			//	draw the line as pairs of triangles making really thin quads.  tri strip, so we can eliminate a lot of duplicate vertices from the index buffer.
			newGeometryBufferVertexCount = geometryBufferVertexCount + (inPointsCount * 2);
			newIndexBufferIndexCount = indexBufferIndexCount + (inPointsCount * 2) + 1;	//	draw one quad (4 idxs) per line segment + 1 "stop bit" for the whole line
		}
		break;
	}
	
	//	make sure that our geometry and index buffers are large enough to accommodate the additional data
	uint32_t		tmpMaxGeoSize = newGeometryBufferVertexCount * self.geometryBufferBytesPerVertex;
	uint32_t		tmpMaxIndexSize = newIndexBufferIndexCount * bytesPerIndex;
	if (tmpMaxGeoSize > self.geometryBuffer.buffer.length)	{
		NSLog(@"ERR: encode would be beyond buffer length, %s",__func__);
		return NO;
	}
	if (tmpMaxIndexSize > self.indexBuffer.buffer.length)	{
		NSLog(@"ERR: encode would be beyond index length, %s",__func__);
		return NO;
	}
	
	//	get the color vals
	vector_float4		colors_vec = Vec4FromNSColor(inColor);
	//NSLog(@"\t\tcolors_vec is %0.2f, %0.2f, %0.2f, %0.2f",colors_vec.r,colors_vec.g,colors_vec.b,colors_vec.a);
	
	//	get the base geometry buffer ptr, figure out where to write into it
	CMVSimpleVertex		*rawGeoVert = (CMVSimpleVertex *)self.geometryBuffer.buffer.contents;
	CMVSimpleVertex		*baseGeoVert = rawGeoVert + geometryBufferVertexCount;
	
	//	get the base index buffer ptr, figure out where to write into it
	uint16_t		*rawIdxPtr = (uint16_t *)self.indexBuffer.buffer.contents;
	uint16_t		*baseIdxPtr = rawIdxPtr + indexBufferIndexCount;
	
	//	populate the geometry buffer- this differs depending on whether we need to draw lines as "thin quads" or not
	switch (self.primitiveType)	{
	case MTLPrimitiveTypePoint:
	case MTLPrimitiveTypeLine:
	case MTLPrimitiveTypeLineStrip:
		{
			for (int i=0; i<inPointsCount; ++i)	{
				NSPoint			*rPtr = inPoints + i;
				CMVSimpleVertex		*wPtr = baseGeoVert + i;
				
				wPtr->position = simd_make_float4( rPtr->x, rPtr->y, 0., 1. );
				wPtr->color = colors_vec;
				wPtr->texIndex = -1;
			}
		}
		break;
	case MTLPrimitiveTypeTriangle:
	case MTLPrimitiveTypeTriangleStrip:
		{
			/*
					- we have to draw a bunch of quads that act as line segments, because metal's line primitives don't support line widths.
					- think of the array of points as an array of line segments
					
					P			   R			P'			   R'
					|			   |			|			   |
					A - - - - - - -B			A'- - - - - - -B'
					|			   |			|			   |
					Q			   S			Q'			   S'
						segment A					segment B
					
					
					- each line segment (AB) can be drawn as a quad using verts P, Q, R, S
					- ultimately, we want to draw all these quads connected end-on-end as bunch of triangles (or triangle strip, depending on the primitive)
					- first step is breaking up the array of NSPoints into an array of quad coords
					- next step: the segments/qauds are supposed to be connected, end-on-end, so they draw as a single line.
						- find where lines PR and P'R' intersect.  this is the "top" vertex corresponding to point B/point A'
						- find where lines QS and Q'S' intersect.  this is the "bottom" vertex corresponding to point B/point A'
			*/
			
			size_t		minBackingSize = sizeof(VVLWSegment) * (inPointsCount + 1);
			NSMutableData		*backingData = NSThread.currentThread.threadDictionary[kCVMTLDrawObjectDataBuffer];
			if (backingData != nil && backingData.length < minBackingSize)	{
				backingData = nil;
			}
			if (backingData == nil)	{
				backingData = [NSMutableData dataWithLength:minBackingSize];
				NSThread.currentThread.threadDictionary[kCVMTLDrawObjectDataBuffer] = backingData;
			}
			VVLWSegment		*tmpSegments = backingData.mutableBytes;
			
			uint32_t		segmentsCount = inPointsCount - 1;
			uint32_t		lastSegmentIndex = segmentsCount - 1;
			
			//	run through and populate one VVLWSegment struct for each line segment we're going to want to draw
			for (int i=0; i<segmentsCount; ++i)	{
				//	these are the raw points we were passed
				NSPoint			*a = inPoints + i;
				NSPoint			*b = inPoints + i + 1;
				
				VVLWSegment		*wPtr = tmpSegments + i;
				wPtr->a = *a;
				wPtr->b = *b;
				//	calculate P, Q, R, and S- do so using A and B.  this gives us absolute minimum area to paint when depicting the stroke.
				LineSegmentAsQuadNormalsForLineSegmentPoints( &wPtr->a, &wPtr->b, strokeOffset, &wPtr->r, &wPtr->s );
				LineSegmentAsQuadNormalsForLineSegmentPoints( &wPtr->b, &wPtr->a, strokeOffset, &wPtr->q, &wPtr->p );
			}
			
			//	run through the segment structs again, populating them with the geometry that describes the stroke we want to draw
			{
				//	this loop looks at pairs of segments, populating the geometry where they intersect.
				for (int i=0; i<(segmentsCount-1); ++i)	{
					VVLWSegment		*current = tmpSegments + i;
					VVLWSegment		*next = current + 1;
					
					//	first figure out what the angle difference is between the segments (if it's too great we'll have to look for intersections in the stroke, otherwise we can just get away with averaging)
					//	represent both segments as vectors, so we can calculate the angle between them
					double		angleBetweenVecsDeg = 0.;
					{
						//	given: vectors u and v, with the angle between them as theta
						//	theta = cos-1( (dot product of u and v) / (magnitude of u * magnitude of v) )
						double		currentAB[2] = { current->b.x - current->a.x, current->b.y - current->a.y };
						double		nextAB[2] = { next->b.x - next->a.x, next->b.y - next->a.y };	//	NOT BA, AB.
						
						double		currentABdotNextAB;
						vDSP_dotprD(
							currentAB,
							1,
							nextAB,
							1,
							&currentABdotNextAB,
							2);
						
						double		currentAB_mag = sqrt( pow( currentAB[0], 2.0 ) + pow( currentAB[1], 2.0 ) );
						double		nextAB_mag = sqrt( pow( nextAB[0], 2.0 ) + pow( nextAB[1], 2.0 ) );
						
						double		angleBetweenVecsRad = acos( (currentABdotNextAB)/(currentAB_mag*nextAB_mag) );
						angleBetweenVecsDeg = angleBetweenVecsRad * 180. / PI;
						//NSLog(@"\t\tangleBetweenVecsDeg is %0.4f",angleBetweenVecsDeg);
					}
					
					//	if the difference in angles is < 10 degrees, calculate the intersection point by simply averaging current->r and next->p (or current->s and next->q for the bottom)
					if (fabs(angleBetweenVecsDeg) < 10.)
					{
						NSPoint		shared_RP;	//	the point shared by current segment's R and next segment's P
						NSPoint		shared_SQ;	//	the point shared by current segment's S and next segment's Q
						
						//	the intersection points are calculated by averaging the values for current->r and next->p, and current->s and next->q, respectively!
						shared_RP = NSMakePoint( (current->r.x + next->p.x) / 2.0, (current->r.y + next->p.y) / 2.0 );
						shared_SQ = NSMakePoint( (current->s.x + next->q.x) / 2.0, (current->s.y + next->q.y) / 2.0 );
						
						current->r = shared_RP;
						current->s = shared_SQ;
						
						//	don't forget to copy the current segment's R and S to the next segment's P and Q!
						next->p = shared_RP;
						next->q = shared_SQ;
					}
					//	else the difference in angles is > 10 degrees
					else	{
						NSPoint		extendedA;
						NSPoint		extendedB;
						
						//	big picture:
						//	extend the current segment's "B" along its axis by 8x the stroke width ("extendedB"), use this to calculate its R and S
						//	extend the next segment's "A" along its axis by 8x the stroke width ("extendedA"), use this to calculate its P and Q
						//	calculate the intersections of these pairs of line segments (current PR and next PR, current QS and next QS)
						double		multiplier = 8. * strokeOffset;
						
						//	populate the current segment's R and S (using an extended point B from the current segment)
						{
							//	points A and B expressed as vectors
							float		current_A[2] = { current->a.x, current->a.y };
							float		current_B[2] = { current->b.x, current->b.y };
							//	line segment AB as a vector
							float		current_AB[2] = { current_B[0] - current_A[0], current_B[1] - current_A[1] };
							//	the unit vector for AB (divide each component of the vector by the vector's magnitude)
							float		current_AB_mag = sqrt( pow( current_AB[0], 2. ) + pow( current_AB[1], 2. ) );
							float		current_AB_unit[2] = { current_AB[0] / current_AB_mag, current_AB[1] / current_AB_mag };
							//	extendedB = (8 * unit vector) + B
							extendedB = NSMakePoint( (multiplier * current_AB_unit[0]) + current->b.x, (multiplier * current_AB_unit[1]) + current->b.y );
							//	populate the current segment's R and S using current A and extended B
							LineSegmentAsQuadNormalsForLineSegmentPoints( &current->a, &extendedB, strokeOffset, &current->r, &current->s );
						}
						
						//	populate the next segment's P and Q (using an extended point A from the next segment)
						{
							//	points A and B expressed as vectors
							float		next_A[2] = { next->a.x, next->a.y };
							float		next_B[2] = { next->b.x, next->b.y };
							//	line segment BA as a vector
							float		next_BA[2] = { next_A[0] - next_B[0], next_A[1] - next_B[1] };
							//	the unit vector for BA
							double		next_BA_mag = sqrt( pow( next_BA[0], 2. ) + pow( next_BA[1], 2. ) );
							float		next_BA_unit[2] = { next_BA[0] / next_BA_mag, next_BA[1] / next_BA_mag };
							//	extendedA = (8 * unit vector) + A
							extendedA = NSMakePoint( (multiplier * next_BA_unit[0]) + next->a.x, (multiplier * next_BA_unit[1]) + next->a.y );
							//	populate the next segment's P and Q using next B and extendedA
							LineSegmentAsQuadNormalsForLineSegmentPoints( &next->b, &extendedA, strokeOffset, &next->q, &next->p );
						}
						
						//	the shared vertexes are where the line segments (current PR and next PR) and (current QS and next QS) intersect
						float			isect_PR_x, isect_PR_y;
						float			isect_QS_x, isect_QS_y;
						//	check for the intersection of the current segment's PR and the next segment's PR
						if (!get_line_intersection( current->p.x, current->p.y, current->r.x, current->r.y, next->p.x, next->p.y, next->r.x, next->r.y, &isect_PR_x, &isect_PR_y))	{
							//NSLog(@"**** warning, couldn't calculate intersection on PR seg, %s",__func__);
							//	 ...if we're here, we couldn't calculate an intersection- recalculate current's R and S from original AB, recalculate next's P and Q from original BA.  intersection is avg of these vals.
							NSPoint		tmpPoint;	//	used to ensure we only affect on member of the struct
							LineSegmentAsQuadNormalsForLineSegmentPoints( &current->a, &current->b, strokeOffset, &current->r, &tmpPoint );
							LineSegmentAsQuadNormalsForLineSegmentPoints( &next->b, &next->a, strokeOffset, &tmpPoint, &next->p );
							isect_PR_x = (current->r.x + next->p.x) / 2.0;
							isect_PR_y = (current->r.y + next->p.y) / 2.0;
						}
						
						//	check for the intersection of the current segment's QS and the next segment's QS
						if (!get_line_intersection( current->q.x, current->q.y, current->s.x, current->s.y, next->q.x, next->q.y, next->s.x, next->s.y, &isect_QS_x, &isect_QS_y))	{
							//NSLog(@"**** warning, couldn't calculate intersection on QS seg, %s",__func__);
							//	 ...if we're here, we couldn't calculate an intersection- recalculate current's R and S from original AB, recalculate next's P and Q from original BA.  intersection is avg of these vals.
							NSPoint		tmpPoint;	//	used to ensure we only affect on member of the struct
							LineSegmentAsQuadNormalsForLineSegmentPoints( &current->a, &current->b, strokeOffset, &tmpPoint, &current->s );
							LineSegmentAsQuadNormalsForLineSegmentPoints( &next->b, &next->a, strokeOffset, &next->q, &tmpPoint );
							isect_QS_x = (current->s.x + next->q.x) / 2.0;
							isect_QS_y = (current->s.y + next->q.y) / 2.0;
						}
						
						//	apply the intersection vals we calculated to both the current and next segments
						current->r = NSMakePoint( isect_PR_x, isect_PR_y );
						current->s = NSMakePoint( isect_QS_x, isect_QS_y );
						
						next->p = current->r;
						next->q = current->s;
					}
				}
				//	the previous 'for' loop didn't process the first segment's P and Q members, nor the last segments R and S members- do that now
				VVLWSegment		*first = tmpSegments;
				LineSegmentAsQuadNormalsForLineSegmentPoints(&first->b, &first->a, strokeOffset, &first->q, &first->p);
				VVLWSegment		*last = tmpSegments + (segmentsCount - 1);
				LineSegmentAsQuadNormalsForLineSegmentPoints(&last->a, &last->b, strokeOffset, &last->r, &last->s);
			}
			
			//	run through the segments one final time, populating the vertex geometry with the values we just calculated
			for (int i=0; i<segmentsCount; ++i)	{
				VVLWSegment		*rPtr = tmpSegments + i;
				CMVSimpleVertex		*wPtr = baseGeoVert + (2 * i);
				
				wPtr->position = simd_make_float4( rPtr->p.x, rPtr->p.y, 0., 1. );
				wPtr->color = colors_vec;
				wPtr->texIndex = -1;
				
				++wPtr;
				
				wPtr->position = simd_make_float4( rPtr->q.x, rPtr->q.y, 0., 1. );
				wPtr->color = colors_vec;
				wPtr->texIndex = -1;
				
				++wPtr;
				
				//	if this is the last segment, we need to copy 'r' and 's', too!
				if (i == lastSegmentIndex)	{
					wPtr->position = simd_make_float4( rPtr->r.x, rPtr->r.y, 0., 1. );
					wPtr->color = colors_vec;
					wPtr->texIndex = -1;
					
					++wPtr;
					
					wPtr->position = simd_make_float4( rPtr->s.x, rPtr->s.y, 0., 1. );
					wPtr->color = colors_vec;
					wPtr->texIndex = -1;
					
					//++wPtr;
				}
			}
		}
		break;
	}
	
	//	populate the indexes that describe the order in which to draw the geometry data we just calculated
	switch (self.primitiveType)	{
	case MTLPrimitiveTypePoint:
		{
			//	populate the index buffers
			for (int i=0; i<inPointsCount; ++i)	{
				*(baseIdxPtr + i) = (geometryBufferVertexCount + i);
			}
			
			//	update the respective vertex counts
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	case MTLPrimitiveTypeLine:
		{
			//	populate the index buffers
			/*									points:
					A		B		C		D
												point idxs in geo buffer
					0		1		2		3
												segments:
						AB		BC		CD
												per-segment point idxs in geo buffer
						01		12		23
			*/
			uint32_t		segmentsCount = inPointsCount - 1;
			for (int i=0; i<segmentsCount; ++i)	{
				*(baseIdxPtr + 2*i) = (geometryBufferVertexCount + i);
				*(baseIdxPtr + 2*i + 1) = (geometryBufferVertexCount + i + 1);
			}
			//	update the respective vertex counts
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	case MTLPrimitiveTypeLineStrip:
		{
			//	populate the index buffers
			for (int i=0; i<inPointsCount; ++i)	{
				*(baseIdxPtr + i) = (geometryBufferVertexCount + i);
			}
			//	add the stop bit!
			*(baseIdxPtr + inPointsCount) = 0xFFFF;
			
			//	update the respective vertex counts
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	case MTLPrimitiveTypeTriangle:
		{
			//	populate the index buffers
			uint32_t		segmentsCount = inPointsCount - 1;
			for (int i=0; i<segmentsCount; ++i)	{
				*(baseIdxPtr + 6*i + 0) = (geometryBufferVertexCount + 2*i + 0);
				*(baseIdxPtr + 6*i + 1) = (geometryBufferVertexCount + 2*i + 1);
				*(baseIdxPtr + 6*i + 2) = (geometryBufferVertexCount + 2*i + 2);
				
				*(baseIdxPtr + 6*i + 3) = (geometryBufferVertexCount + 2*i + 1);
				*(baseIdxPtr + 6*i + 4) = (geometryBufferVertexCount + 2*i + 2);
				*(baseIdxPtr + 6*i + 5) = (geometryBufferVertexCount + 2*i + 3);
			}
			
			//	update the respective vertex counts
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	case MTLPrimitiveTypeTriangleStrip:
		{
			//	populate the index buffers
			for (int i=0; i<inPointsCount; ++i)	{
				*(baseIdxPtr + 2*i + 0) = (geometryBufferVertexCount + 2*i + 0);
				*(baseIdxPtr + 2*i + 1) = (geometryBufferVertexCount + 2*i + 1);
			}
			//	add the stop bit!
			*(baseIdxPtr + 2*inPointsCount) = 0xFFFF;
			
			//uint32_t		segmentsCount = inPointsCount - 1;
			//uint32_t		lastSegmentIndex = segmentsCount - 1;
			//for (int i=0; i<segmentsCount; ++i)	{
			//	*(baseIdxPtr + 2*i + 0) = (geometryBufferVertexCount + 2*i + 0);
			//	*(baseIdxPtr + 2*i + 1) = (geometryBufferVertexCount + 2*i + 1);
			//	if (i == lastSegmentIndex)	{
			//		*(baseIdxPtr + 2*i + 2) = (geometryBufferVertexCount + 2*i + 2);
			//		*(baseIdxPtr + 2*i + 3) = (geometryBufferVertexCount + 2*i + 3);
			//	}
			//}
			////	add the stop bit!
			//*(baseIdxPtr + 2*segmentsCount + 2) = 0xFFFF;
			
			//	update the respective vertex counts
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	}
	
	return YES;
}
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forPointsAsLineCount:(uint32_t)inPointsCount primitiveType:(MTLPrimitiveType)inPrimitiveType	{
	uint32_t		vtxCount = *outVtxCount;
	uint32_t		idxCount = *outIdxCount;
	switch (inPrimitiveType)	{
	case MTLPrimitiveTypePoint:
		vtxCount += inPointsCount;
		idxCount += inPointsCount;
		break;
	case MTLPrimitiveTypeLine:
		vtxCount += inPointsCount;
		idxCount += ((inPointsCount - 1) * 2);
		break;
	case MTLPrimitiveTypeLineStrip:
		vtxCount += inPointsCount;
		idxCount += (inPointsCount + 1);	//	+1 is stop bit
		break;
	case MTLPrimitiveTypeTriangle:
		vtxCount += (inPointsCount * 2);
		idxCount += ((inPointsCount - 1) * 6);
		break;
	case MTLPrimitiveTypeTriangleStrip:
		vtxCount += (inPointsCount * 2);
		idxCount += ((inPointsCount * 2) + 1);	//	one quad (4 idxs) per line segment +1 stop bit
		break;
	}
	*outVtxCount = vtxCount;
	*outIdxCount = idxCount;
	return YES;
}


- (BOOL) encodeRawPoints:(NSPoint *)inPoints count:(uint32_t)inPointsCount indexes:(uint16_t*)inIndexes count:(uint32_t)inIndexesCount withColor:(NSColor *)inColor	{
	uint32_t		geometryBufferVertexCount = self.geometryBufferVertexCount;
	uint32_t		newGeometryBufferVertexCount = geometryBufferVertexCount + inPointsCount;
	uint32_t		indexBufferIndexCount = self.indexBufferIndexCount;
	uint32_t		newIndexBufferIndexCount = indexBufferIndexCount + inIndexesCount;
	uint32_t		bytesPerIndex = 2;
	
	
	//	make sure that our geometry and index buffers are large enough to accommodate the additional data
	uint32_t		tmpMaxGeoSize = newGeometryBufferVertexCount * self.geometryBufferBytesPerVertex;
	uint32_t		tmpMaxIndexSize = newIndexBufferIndexCount * bytesPerIndex;
	if (tmpMaxGeoSize > self.geometryBuffer.buffer.length)	{
		NSLog(@"ERR: encode would be beyond buffer length, %s",__func__);
		return NO;
	}
	if (tmpMaxIndexSize > self.indexBuffer.buffer.length)	{
		NSLog(@"ERR: encode would be beyond index length, %s",__func__);
		return NO;
	}
	
	//	get the color vals
	vector_float4		colors_vec = Vec4FromNSColor(inColor);
	
	//	get the base geometry buffer ptr, figure out where to write into it
	CMVSimpleVertex		*rawGeoVert = (CMVSimpleVertex *)self.geometryBuffer.buffer.contents;
	CMVSimpleVertex		*baseGeoVert = rawGeoVert + geometryBufferVertexCount;
	
	//	get the base index buffer ptr, figure out where to write into it
	uint16_t		*rawIdxPtr = (uint16_t *)self.indexBuffer.buffer.contents;
	uint16_t		*baseIdxPtr = rawIdxPtr + indexBufferIndexCount;
	
	//	get a pointer to the array of points we were passed
	NSPoint			*pointPtr = inPoints;
	
	//	populate structs in the geometry buffer using the passed array of points
	for (int i=0; i<inPointsCount; ++i)	{
		baseGeoVert->position = simd_make_float4( pointPtr->x, pointPtr->y, 0., 1. );
		baseGeoVert->color = colors_vec;
		baseGeoVert->texIndex = -1;
		
		++pointPtr;
		
		++baseGeoVert;
	}
	
	//	populate the passed indexes
	uint16_t		*inIndexPtr = inIndexes;
	for (int i=0; i<inIndexesCount; ++i)	{
		*baseIdxPtr = *inIndexPtr;
		
		++inIndexPtr;
		++baseIdxPtr;
	}
	
	self.geometryBufferVertexCount = newGeometryBufferVertexCount;
	self.indexBufferIndexCount = newIndexBufferIndexCount;
	
	return YES;
}


- (BOOL) encodeStrokedArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians lineWidth:(float)inLineWidth strokeColor:(NSColor * __nullable)inColor	{
	//NSLog(@"%s ... %0.2f, %0.2f -> %0.2f",__func__,inRadius,RAD2DEG*inStartRadians,RAD2DEG*inEndRadians);
	if (inStartRadians == inEndRadians)	{
		NSLog(@"ERR: zero-length arc, %s",__func__);
		return NO;
	}
	if (inRadius <= 0.0)	{
		NSLog(@"ERR: zero radius, %s",__func__);
		return NO;
	}
	//	calculate the circumference of the circle (in pixels) and use that to calculate the # of segments required to generate a smooth-looking curve without going overboard
	double		circumferenceInPixels = PI * 2. * inRadius;
	double		numSegmentsInCircumference = ceil(circumferenceInPixels/ARC_PIXELS_PER_SEGMENT);
	
	double		arcProportionOfCircumference = (inEndRadians - inStartRadians)/(2*PI);
	double		numSegmentsInArc = ceil( fabs(arcProportionOfCircumference) * numSegmentsInCircumference );
	if (numSegmentsInArc < 1)
		numSegmentsInArc = 1.;
	uint32_t	numVerticesInArc = numSegmentsInArc + 1;
	
	//	get a backing buffer that we can use as scratch memory for assembling point data
	size_t		minBackingSize = sizeof(NSPoint) * numVerticesInArc;
	NSMutableData		*backingData = NSThread.currentThread.threadDictionary[kCVMTLDrawObjectArcDataBuffer];
	if (backingData != nil && backingData.length < minBackingSize)	{
		backingData = nil;
	}
	if (backingData == nil)	{
		backingData = [NSMutableData dataWithLength:minBackingSize];
		NSThread.currentThread.threadDictionary[kCVMTLDrawObjectArcDataBuffer] = backingData;
	}
	NSPoint		*pointBuffer = (NSPoint*)backingData.mutableBytes;
	
	//	populate the backing buffer with some point values
	NSPoint		*wPtr = pointBuffer;
	double		radiansPerSegment = (inEndRadians - inStartRadians) / numSegmentsInArc;
	double		cumulativeAngle = inStartRadians;
	for (int i=0; i<numVerticesInArc; ++i)	{
		*wPtr = NSMakePoint( cos(cumulativeAngle) * inRadius + inCenter.x, sin(cumulativeAngle) * inRadius + inCenter.y );
		cumulativeAngle += radiansPerSegment;
		++wPtr;
	}
	
	BOOL		returnMe = [self encodePointsAsLine:pointBuffer count:numVerticesInArc lineWidth:inLineWidth lineColor:inColor];
	
	return returnMe;
}
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forStrokedArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians forPrimitiveType:(MTLPrimitiveType)inPrimitiveType	{
	if (outVtxCount==nil || outIdxCount==nil)	{
		NSLog(@"ERR: %s, prereq nil, %p, %p",__func__,outVtxCount,outIdxCount);
		return NO;
	}
	
	//	get local copies of the vars we're being asked to update
	uint32_t		vtxCount = *outVtxCount;
	uint32_t		idxCount = *outIdxCount;
	
	//	calculate the diameter of the circle (in pixels) and use that to calculate the # of segments required to generate a smooth-looking curve without going overboard
	double		circumferenceInPixels = PI * 2. * inRadius;
	double		numSegmentsInCircumference = ceil(circumferenceInPixels/ARC_PIXELS_PER_SEGMENT);
	
	double		arcProportionOfCircumference = (inEndRadians - inStartRadians)/(2*PI);
	double		numSegmentsInArc = ceil( fabs(arcProportionOfCircumference) * numSegmentsInCircumference );
	if (numSegmentsInArc < 1)
		numSegmentsInArc = 1.;
	uint32_t	numVerticesInArc = numSegmentsInArc + 1;
	
	switch (inPrimitiveType)	{
	case MTLPrimitiveTypePoint:
		{
			vtxCount += numVerticesInArc;
			idxCount += numVerticesInArc;
		}
		break;
	case MTLPrimitiveTypeLine:
		{
			vtxCount += numVerticesInArc;
			idxCount += (numSegmentsInArc * 2);
		}
		break;
	case MTLPrimitiveTypeLineStrip:
		{
			vtxCount += numVerticesInArc;
			idxCount += (numVerticesInArc + 1);
		}
		break;
	case MTLPrimitiveTypeTriangle:
		{
			vtxCount += (numVerticesInArc * 2);
			idxCount += (numSegmentsInArc * 2 * 3);
		}
		break;
	case MTLPrimitiveTypeTriangleStrip:
		{
			vtxCount += (numVerticesInArc * 2);
			idxCount += ((numVerticesInArc * 2) + 1);
		}
		break;
	}
	
	*outVtxCount = vtxCount;
	*outIdxCount = idxCount;
	
	return YES;
}


- (BOOL) encodeFilledArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians fillColor:(NSColor * __nullable)inColor	{
	//NSLog(@"%s ... %@, %0.2f",__func__,NSStringFromPoint(inCenter),inRadius);
	if (inRadius <= 0.0)	{
		NSLog(@"ERR: zero radius, %s",__func__);
		return NO;
	}
	//	calculate the circumference of the circle (in pixels) and use that to calculate the # of segments required to generate a smooth-looking curve without going overboard
	double		circumferenceInPixels = PI * 2. * inRadius;
	uint32_t	numSegmentsInCircumference = ceil(circumferenceInPixels/ARC_PIXELS_PER_SEGMENT);
	
	if (numSegmentsInCircumference < 1)
		numSegmentsInCircumference = 1.;
	
	uint32_t	numSegmentsInArc = ceil( (inEndRadians-inStartRadians)/(2.*PI) * (double)numSegmentsInCircumference );
	if (numSegmentsInArc < 1)
		numSegmentsInArc = 1.;
	
	uint32_t		numVerticesInArc = numSegmentsInArc + 1;
	
	//	get a backing buffer that we can use as scratch memory for assembling point data
	size_t		minBackingSize = sizeof(NSPoint) * (numVerticesInArc + 1);	//	the "+1" is for the center of the circle
	NSMutableData		*backingData = NSThread.currentThread.threadDictionary[kCVMTLDrawObjectArcDataBuffer];
	if (backingData != nil && backingData.length < minBackingSize)	{
		backingData = nil;
	}
	if (backingData == nil)	{
		backingData = [NSMutableData dataWithLength:minBackingSize];
		NSThread.currentThread.threadDictionary[kCVMTLDrawObjectArcDataBuffer] = backingData;
	}
	NSPoint		*pointBuffer = (NSPoint*)backingData.mutableBytes;
	
	//	populate the backing buffer with point values
	NSPoint		*tmpWPtr = pointBuffer;
	double		radiansPerSegment = (inEndRadians-inStartRadians) / numSegmentsInArc;
	double		cumulativeAngle = inStartRadians;
	//	now add the vertices that lay around the circumference of the circle
	for (int i=0; i<numVerticesInArc; ++i)	{
		*tmpWPtr = NSMakePoint( cos(cumulativeAngle) * inRadius + inCenter.x, sin(cumulativeAngle) * inRadius + inCenter.y );
		//NSLog(@"\t\t%d - %@",i,NSStringFromPoint(*tmpWPtr));
		cumulativeAngle += radiansPerSegment;
		++tmpWPtr;
	}
	//	add the center point last!
	*tmpWPtr = inCenter;
	++tmpWPtr;
	
	//	figure out how large the geometry and index buffers will need to be to draw this
	uint32_t		geometryBufferVertexCount = self.geometryBufferVertexCount;
	uint32_t		newGeometryBufferVertexCount = geometryBufferVertexCount;
	uint32_t		indexBufferIndexCount = self.indexBufferIndexCount;
	uint32_t		newIndexBufferIndexCount = indexBufferIndexCount;
	uint32_t		bytesPerIndex = 2;
	
	if (![CMVMTLDrawObject updateVertexCount:&newGeometryBufferVertexCount indexCount:&newIndexBufferIndexCount forFilledArcWithCenter:inCenter radius:inRadius start:inStartRadians end:inEndRadians forPrimitiveType:self.primitiveType])	{
		NSLog(@"ERR: unable to calculate geometry or idx buffer size in %s",__func__);
		return NO;
	}
	
	//	make sure that our geometry and index buffers are large enough to accommodate the additional data
	uint32_t		tmpMaxGeoSize = newGeometryBufferVertexCount * self.geometryBufferBytesPerVertex;
	uint32_t		tmpMaxIndexSize = newIndexBufferIndexCount * bytesPerIndex;
	if (tmpMaxGeoSize > self.geometryBuffer.buffer.length)	{
		NSLog(@"ERR: encode would be beyond buffer length, %s",__func__);
		return NO;
	}
	if (tmpMaxIndexSize > self.indexBuffer.buffer.length)	{
		NSLog(@"ERR: encode would be beyond index length, %s",__func__);
		return NO;
	}
	
	//	at this point we've got the geometry for the circle calculated out- populate the geometry and index buffers
	
	//	get the color vals
	vector_float4		colors_vec = Vec4FromNSColor(inColor);
	
	//	get the base geometry buffer ptr, figure out where to write into it
	CMVSimpleVertex		*rawGeoPtr = (CMVSimpleVertex *)self.geometryBuffer.buffer.contents;
	CMVSimpleVertex		*baseGeoVert = rawGeoPtr + geometryBufferVertexCount;
	//	get the base index buffer ptr, figure out where to write into it
	uint16_t		*rawIdxPtr = (uint16_t *)self.indexBuffer.buffer.contents;
	uint16_t		*baseIdxPtr = rawIdxPtr + indexBufferIndexCount;
	
	//	populate the geometry buffer
	switch (self.primitiveType)	{
	case MTLPrimitiveTypePoint:
	case MTLPrimitiveTypeLine:
	case MTLPrimitiveTypeLineStrip:
		{
			//	geometry doesn't include the center point
			for (int i=0; i<numVerticesInArc; ++i)	{
				NSPoint		*rPtr = pointBuffer + i;
				CMVSimpleVertex		*wPtr = baseGeoVert + i;
				
				wPtr->position = simd_make_float4( rPtr->x, rPtr->y, 0., 1. );
				wPtr->color = colors_vec;
				wPtr->texIndex = -1;
			}
		}
		break;
	case MTLPrimitiveTypeTriangle:
	case MTLPrimitiveTypeTriangleStrip:
		{
			for (int i=0; i<numVerticesInArc; ++i)	{
				NSPoint		*rPtr = pointBuffer + i;
				CMVSimpleVertex		*wPtr = baseGeoVert + i;
				
				//NSLog(@"\t\t%d - %@",i,NSStringFromPoint(*rPtr));
				wPtr->position = simd_make_float4( rPtr->x, rPtr->y, 0., 1. );
				wPtr->color = colors_vec;
				wPtr->texIndex = -1;
			}
			//	center point is last!
			CMVSimpleVertex		*wPtr = baseGeoVert + numVerticesInArc;
			
			wPtr->position = simd_make_float4( inCenter.x, inCenter.y, 0., 1. );
			wPtr->color = colors_vec;
			wPtr->texIndex = -1;
		}
		break;
	}
	
	//	populate the index buffer
	switch (self.primitiveType)	{
	case MTLPrimitiveTypePoint:
		{
			//	geometry doesn't include the center point
			for (int i=0; i<numVerticesInArc; ++i)	{
				*(baseIdxPtr + i) = (geometryBufferVertexCount + i);
			}
			
			//	update the respective vertex/idx counts;
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	case MTLPrimitiveTypeLine:
		{
			//	geometry doesn't include the center point
			for (int i=0; i<numSegmentsInArc; ++i)	{
				*(baseIdxPtr + 2*i) = (geometryBufferVertexCount + i);
				*(baseIdxPtr + 2*i + 1) = (geometryBufferVertexCount + i + 1);
			}
			
			//	update the respective vertex/idx counts;
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	case MTLPrimitiveTypeLineStrip:
		{
			//	geometry doesn't include the center point
			for (int i=0; i<numVerticesInArc; ++i)	{
				*(baseIdxPtr + i) = (geometryBufferVertexCount + i);
			}
			//	we're going to include the first point again (to close the circle)
			//*(baseIdxPtr + numVerticesInArc) = geometryBufferVertexCount;
			//	stop bit!
			//*(baseIdxPtr + numVerticesInArc + 1) = 0xFFFF;
			*(baseIdxPtr + numVerticesInArc) = 0xFFFF;
			
			//	update the respective vertex/idx counts;
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	case MTLPrimitiveTypeTriangle:
		{
			//	geometry for the triangles
			for (int i=0; i<numSegmentsInCircumference; ++i)	{
				*(baseIdxPtr + 3*i + 0) = (geometryBufferVertexCount + (i + 0)%numSegmentsInCircumference);
				*(baseIdxPtr + 3*i + 1) = (geometryBufferVertexCount + (i + 1)%numSegmentsInCircumference);
				*(baseIdxPtr + 3*i + 2) = (geometryBufferVertexCount + numVerticesInArc);
			}
			//	stop bit!
			*(baseIdxPtr + 3*numSegmentsInCircumference) = 0xFFFF;
			
			//	update the respective vertex/idx counts;
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	case MTLPrimitiveTypeTriangleStrip:
		{
			//	geometry for the triangles
			for (int i=0; i<numVerticesInArc; ++i)	{
				*(baseIdxPtr + 2*i + 0) = (geometryBufferVertexCount + numVerticesInArc);	//	center...
				*(baseIdxPtr + 2*i + 1) = (geometryBufferVertexCount + i);
			}
			//	one more to close the circle
			//*(baseIdxPtr + 2*numVerticesInArc + 0) = (geometryBufferVertexCount + numVerticesInArc);
			//*(baseIdxPtr + 2*numVerticesInArc + 1) = (geometryBufferVertexCount);
			//	stop bit!
			//*(baseIdxPtr + 2*numVerticesInArc + 2) = 0xFFFF;
			*(baseIdxPtr + 2*numVerticesInArc + 0) = 0xFFFF;
			
			//	update the respective vertex/idx counts;
			self.geometryBufferVertexCount = newGeometryBufferVertexCount;
			self.indexBufferIndexCount = newIndexBufferIndexCount;
		}
		break;
	}
	
	return YES;
}
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forFilledArcWithCenter:(NSPoint)inCenter radius:(double)inRadius start:(double)inStartRadians end:(double)inEndRadians forPrimitiveType:(MTLPrimitiveType)inPrimitiveType	{
	if (inRadius <= 0.0)	{
		NSLog(@"ERR: zero radius, %s",__func__);
		return NO;
	}
	//	calculate the circumference of the circle (in pixels) and use that to calculate the # of segments required to generate a smooth-looking curve without going overboard
	double		circumferenceInPixels = PI * 2. * inRadius;
	double		numSegmentsInCircumference = ceil(circumferenceInPixels/ARC_PIXELS_PER_SEGMENT);
	
	if (numSegmentsInCircumference < 1)
		numSegmentsInCircumference = 1.;
	
	//uint32_t		numVerticesInCircle = numSegmentsInCircumference;
	uint32_t	numSegmentsInArc = ceil( (inEndRadians-inStartRadians)/(2.*PI) * (double)numSegmentsInCircumference );
	if (numSegmentsInArc < 1)
		numSegmentsInArc = 1.;
	
	uint32_t		numVerticesInArc = numSegmentsInArc + 1;
	
	//	figure out how large the geometry and index buffers will need to be to draw this
	uint32_t		geometryBufferVertexCount = *outVtxCount;
	uint32_t		newGeometryBufferVertexCount = geometryBufferVertexCount;
	uint32_t		indexBufferIndexCount = *outIdxCount;
	uint32_t		newIndexBufferIndexCount = indexBufferIndexCount;
	
	switch (inPrimitiveType)	{
	case MTLPrimitiveTypePoint:
		{
			newGeometryBufferVertexCount += (numVerticesInArc);
			newIndexBufferIndexCount += (numVerticesInArc + 1);	//	the "+1" is the stop bit
		}
		break;
	case MTLPrimitiveTypeLine:
		{
			newGeometryBufferVertexCount += (numVerticesInArc);
			newIndexBufferIndexCount += ((numSegmentsInArc * 2) + 1);	//	the "+1" is the stop bit
		}
		break;
	case MTLPrimitiveTypeLineStrip:
		{
			newGeometryBufferVertexCount += (numVerticesInArc);
			//newIndexBufferIndexCount += (numVerticesInArc + 1 + 1);	//	the first "+1" closes the circle, the second is the stop bit
			newIndexBufferIndexCount += (numVerticesInArc + 1);	//	the "+1" is the stop bit
		}
		break;
	case MTLPrimitiveTypeTriangle:
		{
			newGeometryBufferVertexCount += (numVerticesInArc + 1);	//	the "+1" is for the center
			newIndexBufferIndexCount += (numSegmentsInArc * 3);
		}
		break;
	case MTLPrimitiveTypeTriangleStrip:
		{
			newGeometryBufferVertexCount += (numVerticesInArc + 1);	//	the "+1" is for the center
			//newIndexBufferIndexCount += (((numVerticesInArc + 1) * 2) + 1);	//	the first "+1" closes the circle, the second is the stop bit
			newIndexBufferIndexCount += ((numVerticesInArc * 2) + 1);	//	the "+1" is the stop bit
		}
		break;
	}
	
	*outVtxCount = newGeometryBufferVertexCount;
	*outIdxCount = newIndexBufferIndexCount;
	
	return YES;
}


- (BOOL) encodeStrokedCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius lineWidth:(float)inLineWidth strokeColor:(NSColor * __nullable)inColor	{
	return [self encodeStrokedArcWithCenter:inCenter radius:inRadius start:0. end:2.*PI lineWidth:inLineWidth strokeColor:inColor];
}
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forStrokedCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius forPrimitiveType:(MTLPrimitiveType)inPrimitiveType	{
	return [self updateVertexCount:outVtxCount indexCount:outIdxCount forStrokedArcWithCenter:inCenter radius:inRadius start:0. end:2.*PI forPrimitiveType:inPrimitiveType];
}


- (BOOL) encodeFilledCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius fillColor:(NSColor * __nullable)inColor	{
	return [self encodeFilledArcWithCenter:inCenter radius:inRadius start:0. end:2.*PI fillColor:inColor];
}
+ (BOOL) updateVertexCount:(uint32_t *)outVtxCount indexCount:(uint32_t *)outIdxCount forFilledCircleWithCenter:(NSPoint)inCenter radius:(double)inRadius forPrimitiveType:(MTLPrimitiveType)inPrimitiveType	{
	return [self updateVertexCount:outVtxCount indexCount:outIdxCount forFilledArcWithCenter:inCenter radius:inRadius start:0. end:2.*PI forPrimitiveType:inPrimitiveType];
}


- (BOOL) encodePrimitiveRestartIndex	{
	if (self.availableIndexes < 1)	{
		NSLog(@"ERR: unable to encode restart index, %s",__func__);
		return NO;
	}
	uint16_t		*indexWPtr = (uint16_t*)self.indexBufferHead;
	*indexWPtr = 0xFFFF;
	self.indexBufferIndexCount++;
	return YES;
}

- (void) executeInRenderEncoder:(id<MTLRenderCommandEncoder>)inRenderEnc commandBuffer:(id<MTLCommandBuffer>)inCB	{
	if (inRenderEnc == nil || inCB == nil)	{
		return;
	}
	
	if (self.indexBufferIndexCount < 1)	{
		return;
	}
	
	
	[self.images enumerateKeysAndObjectsUsingBlock:^(NSNumber *imgIdx, id<VVMTLTextureImage> imgTex, BOOL *stop)	{
		[inRenderEnc
			setFragmentTexture:imgTex.texture
			atIndex:imgIdx.intValue];
	}];
	
	
	[inCB addCompletedHandler:^(id<MTLCommandBuffer> completedCB)	{
		CMVMTLDrawObject		*tmpSelf = self;
		tmpSelf = nil;
	}];
	
	[inRenderEnc
		setVertexBuffer:self.geometryBuffer.buffer
		offset:0
		atIndex:CMV_VS_IDX_Verts];
	
	[inRenderEnc
		drawIndexedPrimitives:self.primitiveType
		indexCount:self.indexBufferIndexCount
		indexType:MTLIndexTypeUInt16
		indexBuffer:self.indexBuffer.buffer
		indexBufferOffset:0];
}
- (void) executeInRenderEncoder:(id<MTLRenderCommandEncoder>)inRenderEnc textureArgumentEncoder:(id<MTLArgumentEncoder>)inTexArgEnc commandBuffer:(id<MTLCommandBuffer>)inCB	{
	if (inRenderEnc == nil || inCB == nil)	{
		return;
	}
	
	if (self.indexBufferIndexCount < 1)	{
		return;
	}
	
	//	make an array of image textures that have been sorted by comparing their keys (which are expected to be NSNumbers)
	//if (self.images.count > 0)	{
		NSArray<NSNumber*>		*sortedKeys = [self.images.allKeys sortedArrayUsingSelector:@selector(compare:)];
		NSMutableArray		*sortedImages = [NSMutableArray arrayWithCapacity:0];
		for (NSNumber * key in sortedKeys)	{
			id<VVMTLTextureImage>		tex = [_images objectForKey:key];
			if (tex != nil)	{
				[sortedImages addObject:tex];
			}
		}
		
		size_t		texStructLength = inTexArgEnc.encodedLength;
		size_t		texArrayBufferSize = texStructLength * sortedImages.count;
		if (texArrayBufferSize < 1)
			texArrayBufferSize = texStructLength * 1;
		
		texArrayBufferSize = fmax(texArrayBufferSize, 16);
		id<VVMTLBuffer>		texArrayBuffer = [VVMTLPool.global bufferWithLength:texArrayBufferSize storage:MTLStorageModeShared];
		
		//	if there aren't any images, attach an empty buffer to the shader (so we don't crash in debug builds)
		if (sortedImages.count < 1)	{
			[inTexArgEnc setArgumentBuffer:texArrayBuffer.buffer offset:0];
		}
		//	make an argument encoder, populate it with the array of textures
		else	{
			//id<MTLFunction>		localFragFunc = XXX;
			//id<MTLArgumentEncoder>		argEncoder = [localFragFunc newArgumentEncoderWithBufferIndex:CMV_FS_Idx_Tex];
			int		texIndex = 0;
			for (id<VVMTLTextureImage> image in sortedImages)	{
				[inTexArgEnc setArgumentBuffer:texArrayBuffer.buffer offset:(texIndex * texStructLength)];
				[inTexArgEnc setTexture:image.texture atIndex:0];	//	the '0' here is the id of the var in the struct (which is auto-generated by the compiler here)
				
				[inRenderEnc useResource:image.texture usage:MTLResourceUsageRead stages:MTLRenderStageFragment];
				
				++texIndex;
			}
		}
		
		[inRenderEnc setFragmentBuffer:texArrayBuffer.buffer offset:0 atIndex:CMV_FS_Idx_Tex];
	//}
	
	[inCB addCompletedHandler:^(id<MTLCommandBuffer> completedCB)	{
		id<VVMTLBuffer>		tmpBuffer = texArrayBuffer;
		CMVMTLDrawObject		*tmpSelf = self;
		NSMutableArray		*tmpSortedArray = sortedImages;
		[tmpSortedArray removeAllObjects];
		tmpSortedArray = nil;
		tmpSelf = nil;
		tmpBuffer = nil;
	}];
	
	[inRenderEnc
		setVertexBuffer:self.geometryBuffer.buffer
		offset:0
		atIndex:CMV_VS_IDX_Verts];
	
	[inRenderEnc
		drawIndexedPrimitives:self.primitiveType
		indexCount:self.indexBufferIndexCount
		indexType:MTLIndexTypeUInt16
		indexBuffer:self.indexBuffer.buffer
		indexBufferOffset:0];
}

@end








BOOL LineSegmentAsQuadNormalsForLineSegmentPoints(NSPoint *inAPtr, NSPoint *inBPtr, float inDistance, NSPoint *outCPtr, NSPoint *outDPtr)	{
	if (inAPtr == NULL || inBPtr == NULL)	{
		NSLog(@"ERR: a or b nil (%p, %p), %s",inAPtr,inBPtr,__func__);
		return NO;
	}
	if (outCPtr == NULL || outDPtr == NULL)	{
		NSLog(@"ERR: c or d nil (%p, %p), %s",outCPtr,outDPtr,__func__);
		return NO;
	}
	//if (inDistance <= 0.0)	{
	//	NSLog(@"ERR: incorrect distance (%f), %s",inDistance,__func__);
	//	return NO;
	//}
	
	//	points A and B expressed as vectors
	float		vec_A[2] = { inAPtr->x, inAPtr->y };
	float		vec_B[2] = { inBPtr->x, inBPtr->y };
	
	//	the line segment AB, expressed as a vector
	float		vec_AB[2];
	vec_AB[0] = vec_B[0] - vec_A[0];
	vec_AB[1] = vec_B[1] - vec_A[1];
	
	//	the normal vectors
	float		norm_vec_AB_L[2] = { -vec_AB[1], vec_AB[0] };
	float		norm_vec_AB_R[2] = { vec_AB[1], -vec_AB[0] };
	
	//	the magnitude of the normal vectors (needed for unit vectors)
	float		mag_norm_vec_AB_L = sqrt( pow(norm_vec_AB_L[0], 2) + pow(norm_vec_AB_L[1], 2) );
	float		mag_norm_vec_AB_R = sqrt( pow(norm_vec_AB_R[0], 2) + pow(norm_vec_AB_R[1], 2) );
	
	//	the unit vectors of the normal vectors of AB are calculated by dividing each component of the normal vectors by the vector's magnitude
	float		unit_norm_vec_AB_L[2];
	float		unit_norm_vec_AB_R[2];
	vDSP_vsdiv(
		norm_vec_AB_L,
		1,
		&mag_norm_vec_AB_L,
		unit_norm_vec_AB_L,
		1,
		2);
	vDSP_vsdiv(
		norm_vec_AB_R,
		1,
		&mag_norm_vec_AB_R,
		unit_norm_vec_AB_R,
		1,
		2);
	
	//	'C' is distance * unit vector L + B
	float		vec_C[2];
	vDSP_vsma(
		unit_norm_vec_AB_L,
		1,
		&inDistance,
		vec_B,
		1,
		vec_C,
		1,
		2);
	//	'D' is distance * unit vector R + B
	float		vec_D[2];
	vDSP_vsma(
		unit_norm_vec_AB_R,
		1,
		&inDistance,
		vec_B,
		1,
		vec_D,
		1,
		2);
	
	*(outCPtr) = NSMakePoint( vec_C[0], vec_C[1] );
	*(outDPtr) = NSMakePoint( vec_D[0], vec_D[1] );
	
	return YES;
}








char get_line_intersection(
	float p0_x, float p0_y,
	float p1_x, float p1_y,
	float p2_x, float p2_y,
	float p3_x, float p3_y,
	float *i_x, float *i_y)
{
	float s1_x, s1_y, s2_x, s2_y;
	s1_x = p1_x - p0_x;
	s1_y = p1_y - p0_y;
	
	s2_x = p3_x - p2_x;
	s2_y = p3_y - p2_y;
	
	float s, t;
	s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y);
	t = ( s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / (-s2_x * s1_y + s1_x * s2_y);
	
	if (s >= 0 && s <= 1 && t >= 0 && t <= 1)
	{
		// Collision detected
		if (i_x != NULL)
			*i_x = p0_x + (t * s1_x);
		if (i_y != NULL)
			*i_y = p0_y + (t * s1_y);
		return 1;
	}
	
	return 0; // No collision
}
