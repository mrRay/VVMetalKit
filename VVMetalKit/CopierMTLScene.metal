#include <metal_stdlib>
#include "MTLImgBufferShaderTypes.h"
#include "SizingTool_metal.h"

using namespace metal;


kernel void CopierMTLSceneFunc(
	texture2d<float, access::sample> srcTexture [[ texture(0) ]],
	texture2d<float, access::write> outTexture [[ texture(1) ]],
	constant MTLImgBufferStruct * geoBuffer [[ buffer(2) ]],
	uint2 gid [[ thread_position_in_grid ]])
{
	if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height())
		return;
	
	//	if 'gid' is not in geoBuffer's "dstRect" then draw transparent black and we're done immediately
	GPoint		gidPoint = MakePoint(gid.x, gid.y);
	if (!PointInRect(gidPoint, geoBuffer->dstRect))	{
		outTexture.write(float4(0,0,0,0), gid);
		return;
	}
	
	//	calculate the normalized position of "gid" within geoBuffer's "dstRect"
	GRect		dstRect = geoBuffer->dstRect;
	GPoint		normCoords = NormCoordsOfPixelInRect(gidPoint, dstRect);
	if (geoBuffer->flipped)
		normCoords.y = 1.0 - normCoords.y;
	//	convert this normalized position into pixel coords of the normalized pos within geoBuffer's "srcRect"
	GRect		srcRect = geoBuffer->srcRect;
	GPoint		pxlCoords = PixelForNormCoordsInRect(normCoords, srcRect);
	//	sample srcTexture at these pixel coords
	constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::pixel);
	const float4			srcColor = srcTexture.sample(sampler, float2(pxlCoords.x,pxlCoords.y));
	outTexture.write(srcColor, gid);
	
	
	/*
	float2		normLoc = float2( float(gid.x)/geoBuffer->dstRect.size.width, float(gid.y)/geoBuffer->dstRect.size.height );
	float2		readLoc;
	if (geoBuffer->flipped)	{
		readLoc = float2(
			((geoBuffer->srcRect.size.width-1) * normLoc.x) + geoBuffer->srcRect.origin.x,
			((geoBuffer->srcRect.size.height-1) * (1.0-normLoc.y)) + geoBuffer->srcRect.origin.y
		);
	}
	else	{
		readLoc = float2(
			((geoBuffer->srcRect.size.width-1) * normLoc.x) + geoBuffer->srcRect.origin.x,
			((geoBuffer->srcRect.size.height-1) * normLoc.y) + geoBuffer->srcRect.origin.y
		);
	}
	
	constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::pixel);
	const float4		srcColor = srcTexture.sample(sampler, readLoc);
	outTexture.write(srcColor, gid);
	*/
	
	/*
	//	crop reading automatically to the srcRect of the geometry buffer
	uint2		readLoc = uint2(gid.x + geoBuffer->srcRect.origin.x, gid.y + geoBuffer->srcRect.origin.y);
	//	if the readLoc is outside the bounds of the src image's src rect, just write clear alpha
	if (readLoc.x > geoBuffer->srcRect.size.width || readLoc.y > geoBuffer->srcRect.size.height)	{
		outTexture.write( float4(0,0,0,0), gid );
		return;
	}
	
	const float4		srcColor = srcTexture.read(readLoc);
	outTexture.write(srcColor, gid);
	*/
	
	//const float4		srcColor = srcTexture.read(gid);
	//outTexture.write(srcColor, gid);
}

