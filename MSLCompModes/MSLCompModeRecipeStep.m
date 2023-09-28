//
//  MSLCompModeRecipeStep.m
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import "MSLCompModeRecipeStep.h"
#import "VVMacros.h"
#import <VVMetalKit/VVMetalKit.h>
#import "MSLCompModeController.h"
#import "MSLCompMode.h"




//	expects to be passed a ptr to a float[2] describing the x,y location of the point
static inline float ComputeDistance(float *pt1, float *pt2);
//	i think i originally found these on an openframeworks forum a long time ago?
//	's' is a ptr to four float[2]s (four x/y locations)
void FindHomography(float *s, float *d, float homography[16]);
static inline void GaussianElimination(float *input, int in);




@implementation MSLCompModeRecipeStep

- (id) copyWithZone:(NSZone *)z	{
	MSLCompModeRecipeStep		*returnMe = [[MSLCompModeRecipeStep alloc] init];
	memcpy( returnMe->verts, verts, sizeof(verts) );
	returnMe.img = self.img;
	return returnMe;
}

- (BOOL) isEqual:(id)n	{
	if (n == nil)
		return NO;
	if (![(NSObject*)n isMSLCompModeRecipeStep])
		return NO;
	MSLCompModeRecipeStep		*recast = (MSLCompModeRecipeStep *)n;
	for (int i=0; i<4; ++i)	{
		MSLCompModeQuadVertex		*myVert = verts + i;
		MSLCompModeQuadVertex		*otherVert = recast->verts + i;
		
		for (int j=0; j<2; ++j)	{
			if (myVert->position[j] != otherVert->position[j])
				return NO;
			if (myVert->texCoord[j] != otherVert->texCoord[j])
				return NO;
		}
		if (myVert->opacity != otherVert->opacity
		|| myVert->texIndex != otherVert->texIndex
		|| myVert->compModeIndex != otherVert->compModeIndex)
		{
			return NO;
		}
	}
	return YES;
}
- (BOOL) isEqualTo:(id)n	{
	return [self isEqual:n];
}

- (BOOL) isMSLCompModeRecipeStep	{
	return YES;
}
- (void) dumpVertexDataToBuffer:(id<MTLBuffer>)outBuffer atOffset:(size_t)inOffset	{
	//NSLog(@"%s ... %d",__func__,inOffset);
	//[self calculateProjectionMatrix];
	//	don't check, just dump- the recipe would have already checked...
	uint8_t			*baseWPtr = outBuffer.contents;
	uint8_t			*wPtr = baseWPtr + inOffset;
	size_t			localOffset = inOffset;
	size_t			vertexSize = sizeof(MSLCompModeQuadVertex);
	for (int i=0; i<4; ++i)	{
		memcpy( wPtr, &verts[i], vertexSize );
		wPtr += vertexSize;
		localOffset += vertexSize;
	}
}
- (void) dumpProjectionMatrixToBuffer:(id<MTLBuffer>)outBuffer atOffset:(size_t)inOffset	{
	//NSLog(@"%s",__func__);
	const float			geoCoords[] = {
		verts[0].position.x, verts[0].position.y,
		verts[1].position.x, verts[1].position.y,
		verts[2].position.x, verts[2].position.y,
		verts[3].position.x, verts[3].position.y,
	};
	const float			texCoords[] = {
		verts[0].texCoord.x, verts[0].texCoord.y,
		verts[1].texCoord.x, verts[1].texCoord.y,
		verts[2].texCoord.x, verts[2].texCoord.y,
		verts[3].texCoord.x, verts[3].texCoord.y,
	};
	
	//	make sure that none of the geometry coords are "too close" (we get undefined results if the verts are on top of one another)
	float		*blPtr = (float*)geoCoords;
	float		*tlPtr = (float*)geoCoords + 2;
	float		*brPtr = (float*)geoCoords + 4;
	float		*trPtr = (float*)geoCoords + 6;
	const float		hTol = 0.5;
	const float		wTol = 0.5;
	//	check BL - TL
	if (ComputeDistance( blPtr, tlPtr ) < hTol)	{
		*(blPtr+1) = *(tlPtr+1) - hTol;
	}
	//	check TL - TR
	if (ComputeDistance( tlPtr, trPtr ) < wTol)	{
		*(tlPtr+1) = *(trPtr+1) - wTol;
	}
	//	check TR - BR
	if (ComputeDistance( trPtr, brPtr ) < hTol)	{
		*(brPtr+1) = *(trPtr+1) - hTol;
	}
	//	check BR - BL
	if (ComputeDistance( brPtr, blPtr ) < wTol)	{
		*(blPtr+1) = *(brPtr+1) - wTol;
	}
	
	//	calculate the local projection matrix, writing it to the buffer at the specified location
	simd_float4x4		*outWPtr = (simd_float4x4 *)((uint8_t*)outBuffer.contents + inOffset);
	
	//	calculate the homography- the projection transform necessary to make "texCoords" appear at "geoCoords"
	float		matrix[16];
	FindHomography( (float*)texCoords, (float*)geoCoords, matrix );
	
	*outWPtr = simd_matrix(
		simd_make_float4( *(matrix+0), *(matrix+1), *(matrix+2), *(matrix+3) ),
		simd_make_float4( *(matrix+4), *(matrix+5), *(matrix+6), *(matrix+7) ),
		simd_make_float4( *(matrix+8), *(matrix+9), *(matrix+10), *(matrix+11) ),
		simd_make_float4( *(matrix+12), *(matrix+13), *(matrix+14), *(matrix+15) )
	);
}


@synthesize img=_img;
- (void) setImg:(id<VVMTLTextureImage>)n	{
	_img = n;
	
	NSRect		srcRect = n.srcRect;
	//NSRect		tmpRect;
	//NSPoint		tmpPoint;
	
	const VVRectAnchor		normalOrder[] = { VVRectAnchor_BL, VVRectAnchor_TL, VVRectAnchor_BR, VVRectAnchor_TR };
	const VVRectAnchor		flipVOrder[] = { VVRectAnchor_TL, VVRectAnchor_BL, VVRectAnchor_TR, VVRectAnchor_BR };
	const VVRectAnchor		flipHOrder[] = { VVRectAnchor_BR, VVRectAnchor_TR, VVRectAnchor_BL, VVRectAnchor_TL };
	const VVRectAnchor		flipVAndHOrder[] = { VVRectAnchor_TR, VVRectAnchor_BR, VVRectAnchor_TL, VVRectAnchor_BL };
	const VVRectAnchor		*orderPtr = normalOrder;
	
	BOOL		cumulativeFlipH = n.flipH;
	BOOL		cumulativeFlipV = n.flipV;
	//	metal texture access uses the top-left corner as the origin, so we have to flip the src rect in the VVMTLTextureImage veritcally before we access it in the shader
	cumulativeFlipV = !cumulativeFlipV;
	
	if (cumulativeFlipH && cumulativeFlipV)	{
		orderPtr = flipVAndHOrder;
	}
	else if (cumulativeFlipH)	{
		orderPtr = flipHOrder;
	}
	else if (cumulativeFlipV)	{
		orderPtr = flipVOrder;
	}
	
	for (int i=0; i<4; ++i)	{
		NSPoint		tmpPoint = VVRectGetAnchorPoint(srcRect, *(orderPtr + i));
		verts[i].texCoord = simd_make_float2( tmpPoint.x, tmpPoint.y );
	}
	
}
- (id<VVMTLTextureImage>) img	{
	return _img;
}

- (void) populateVertexPositionsWithRect:(NSRect)n	{
	NSRect		tmpRect = n;
	NSPoint		tmpPoint;
	
	//	BL
	tmpPoint = VVRectGetAnchorPoint(tmpRect, VVRectAnchor_BL);
	verts[0].position = simd_make_float2( tmpPoint.x, tmpPoint.y );
	//	TL
	tmpPoint = VVRectGetAnchorPoint(tmpRect, VVRectAnchor_TL);
	verts[1].position = simd_make_float2( tmpPoint.x, tmpPoint.y );
	//	BR
	tmpPoint = VVRectGetAnchorPoint(tmpRect, VVRectAnchor_BR);
	verts[2].position = simd_make_float2( tmpPoint.x, tmpPoint.y );
	//	TR
	tmpPoint = VVRectGetAnchorPoint(tmpRect, VVRectAnchor_TR);
	verts[3].position = simd_make_float2( tmpPoint.x, tmpPoint.y );
}
- (void) populateVertexPositionsWithRectFlippedVertically:(NSRect)n	{
	NSRect		tmpRect = n;
	NSPoint		tmpPoint;
	
	//	TL
	tmpPoint = VVRectGetAnchorPoint(tmpRect, VVRectAnchor_TL);
	verts[0].position = simd_make_float2( tmpPoint.x, tmpPoint.y );
	//	BL
	tmpPoint = VVRectGetAnchorPoint(tmpRect, VVRectAnchor_BL);
	verts[1].position = simd_make_float2( tmpPoint.x, tmpPoint.y );
	//	TR
	tmpPoint = VVRectGetAnchorPoint(tmpRect, VVRectAnchor_TR);
	verts[2].position = simd_make_float2( tmpPoint.x, tmpPoint.y );
	//	BR
	tmpPoint = VVRectGetAnchorPoint(tmpRect, VVRectAnchor_BR);
	verts[3].position = simd_make_float2( tmpPoint.x, tmpPoint.y );
}
- (void) populateVertexOpacities:(float)n	{
	float		tmpFloat = fmax(0, fmin(1, n));
	for (int i=0; i<4; ++i)	{
		verts[i].opacity = tmpFloat;
	}
}

- (BOOL) populateCompModeWithName:(NSString *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if (n == nil)
		return NO;
	MSLCompMode		*compMode = [MSLCompModeController.global compModeWithName:n];
	if (compMode == nil)	{
		NSLog(@"ERR: unable to find comp mode named \"%@\" in %s",n,__func__);
		return NO;
	}
	uint16_t		compModeIndex = compMode.compModeIndex;
	for (int i=0; i<4; ++i)	{
		verts[i].compModeIndex = compModeIndex;
	}
	return YES;
}
- (BOOL) populateCompModeWithIndex:(uint16_t)n	{
	MSLCompMode		*compMode = [MSLCompModeController.global compModeWithIndex:n];
	if (compMode == nil)
		return NO;
	for (int i=0; i<4; ++i)	{
		verts[i].compModeIndex = n;
	}
	return YES;
}
- (BOOL) populateWithCompMode:(MSLCompMode *)n	{
	if (n == nil)
		return NO;
	uint16_t		compModeIndex = n.compModeIndex;
	for (int i=0; i<4; ++i)	{
		verts[i].compModeIndex = compModeIndex;
	}
	return YES;
}


@end




@implementation NSObject (MSLCompModeRecipeStepNSObjectAdditions)

- (BOOL) isMSLCompModeRecipeStep	{
	return NO;
}

@end




static inline float ComputeDistance(float *pt1, float *pt2)	{
	float		*pt1x = pt1;
	float		*pt1y = pt1 + 1;
	float		*pt2x = pt2;
	float		*pt2y = pt2 + 1;
	return sqrt((*pt2x - *pt1x) * (*pt2x - *pt1x) + (*pt2y - *pt1y) * (*pt2y - *pt1y));
}
//void FindHomography(float src[4][2], float dst[8], float homography[16])	{
void FindHomography(float *s, float *d, float homography[16])	{
	// create the equation system to be solved
	//
	// from: Multiple View Geometry in Computer Vision 2ed
	//       Hartley R. and Zisserman A.
	//
	// x' = xH
	// where H is the homography: a 3 by 3 matrix
	// that transformed to inhomogeneous coordinates for each point
	// gives the following equations for each point:
	//
	// x' * (h31*x + h32*y + h33) = h11*x + h12*y + h13
	// y' * (h31*x + h32*y + h33) = h21*x + h22*y + h23
	//
	// as the homography is scale independent we can let h33 be 1 (indeed any of the terms)
	// so for 4 points we have 8 equations for 8 terms to solve: h11 - h32
	// after ordering the terms it gives the following matrix
	// that can be solved with gaussian elimination:
	
	float	src[4][2];
	float	dst[8];
	for (int x=0; x<4; ++x)	{
		for (int y=0; y<2; ++y)	{
			src[x][y] = *(s+2*x+y);
			dst[(2*x+y)] = *(d+2*x+y);
		}
	}
	
	float P[8][9]={
		{-src[0][0], -src[0][1], -1,   0,   0,  0, src[0][0]*dst[0], src[0][1]*dst[0], -dst[0] }, // h11
		{  0,   0,  0, -src[0][0], -src[0][1], -1, src[0][0]*dst[1], src[0][1]*dst[1], -dst[1] }, // h12
		
		{-src[1][0], -src[1][1], -1,   0,   0,  0, src[1][0]*dst[2], src[1][1]*dst[2], -dst[2] }, // h13
		{  0,   0,  0, -src[1][0], -src[1][1], -1, src[1][0]*dst[3], src[1][1]*dst[3], -dst[3] }, // h21
		
		{-src[2][0], -src[2][1], -1,   0,   0,  0, src[2][0]*dst[4], src[2][1]*dst[4], -dst[4] }, // h22
		{  0,   0,  0, -src[2][0], -src[2][1], -1, src[2][0]*dst[5], src[2][1]*dst[5], -dst[5] }, // h23
		
		{-src[3][0], -src[3][1], -1,   0,   0,  0, src[3][0]*dst[6], src[3][1]*dst[6], -dst[6] }, // h31
		{  0,   0,  0, -src[3][0], -src[3][1], -1, src[3][0]*dst[7], src[3][1]*dst[7], -dst[7] }, // h32
	};
	
	GaussianElimination(&P[0][0],9);
	
	// gaussian elimination gives the results of the equation system
	// in the last column of the original matrix.
	// opengl needs the transposed 4x4 matrix:
	float aux_H[]={ P[0][8],P[3][8],0,P[6][8], // h11  h21 0 h31
		P[1][8],P[4][8],0,P[7][8], // h12  h22 0 h32
		0      ,      0,0,0,       // 0    0   0 0
		P[2][8],P[5][8],0,1};      // h13  h23 0 h33
	
	BOOL negate = NO;
	
	//	Apply the matrix to one of the input points to test the w value
	//	So far it looks like we only need to test one point
	
	//	Create the 4 value vector, xyzw, for src[0][0] & src[0][1] with z = 0 and w = 1
	float input[4] = {src[0][0],src[0][1],0,1};
	float result[4];
	
	//	This for loop performs the matrix x vector multiplication for aux_H(4x4) x pt1(4)
	for (int i=0;i<4;++i)	{
		result[i]=0;
		for (int j=0;j<4;++j)	{
			result[i] = result[i] + aux_H[j*4+i] * input[j];
		}
	}
	//NSLog(@"\t\tcheck result 1: %f %f %f %f",result[0],result[1],result[2],result[3]);
	
	//	If the resulting w value is negative we need to negate the matrix
	if (result[3]<0)
		negate = YES;	
	
	//	Populate the return matrix and negate if needed
	if (negate)	{
		for(int i=0;i<16;i++) homography[i] = -1*aux_H[i];
	}
	else	{
		for(int i=0;i<16;i++) homography[i] = aux_H[i];
	}
}
static inline void GaussianElimination(float *input, int n)	{
	// ported to c from pseudocode in
	// http://en.wikipedia.org/wiki/Gaussian_elimination
	
	float * A = input;
	int i = 0;
	int j = 0;
	int m = n-1;
	while (i < m && j < n){
		// Find pivot in column j, starting in row i:
		int maxi = i;
		for(int k = i+1; k<m; k++){
			if(fabs(A[k*n+j]) > fabs(A[maxi*n+j])){
				maxi = k;
			}
		}
		if (A[maxi*n+j] != 0){
			//swap rows i and maxi, but do not change the value of i
			if(i!=maxi)
				for(int k=0;k<n;k++){
					float aux = A[i*n+k];
					A[i*n+k]=A[maxi*n+k];
					A[maxi*n+k]=aux;
				}
			//Now A[i,j] will contain the old value of A[maxi,j].
			//divide each entry in row i by A[i,j]
			float A_ij=A[i*n+j];
			for(int k=0;k<n;k++){
				A[i*n+k]/=A_ij;
			}
			//Now A[i,j] will have the value 1.
			for(int u = i+1; u< m; u++){
				//subtract A[u,j] * row i from row u
				float A_uj = A[u*n+j];
				for(int k=0;k<n;k++){
					A[u*n+k]-=A_uj*A[i*n+k];
				}
				//Now A[u,j] will be 0, since A[u,j] - A[i,j] * A[u,j] = A[u,j] - 1 * A[u,j] = 0.
			}
			
			i++;
		}
		j++;
	}
	
	//back substitution
	for(int i=m-2;i>=0;i--){
		for(int j=i+1;j<n-1;j++){
			A[i*n+m]-=A[i*n+j]*A[j*n+m];
			//A[i*n+j]=0;
		}
	}
}
