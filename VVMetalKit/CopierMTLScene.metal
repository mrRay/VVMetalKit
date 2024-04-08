#include <metal_stdlib>
#include "VVMTLTextureImageShaderTypes.h"
#include "SizingTool_metal.h"

using namespace metal;


kernel void CopierMTLSceneFunc(
	texture2d<float, access::sample> srcTexture [[ texture(0) ]],
	texture2d<float, access::write> outTexture [[ texture(1) ]],
	constant VVMTLTextureImageStruct * geoBuffer [[ buffer(2) ]],
	uint2 gid [[ thread_position_in_grid ]])
{
	if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height())
		return;
	
	//	if 'gid' is not in geoBuffer's "dstRect" then draw transparent black and we're done immediately
	GRect		dstRect_tl = geoBuffer->dstRect;
	GPoint		gidPoint_tl = MakePoint(gid.x, gid.y);
	if (!PointInRect(gidPoint_tl, dstRect_tl))	{
		outTexture.write(float4(0,0,0,0), gid);
		return;
	}
	
	//	calculate the normalized position of "gid" within geoBuffer's "dstRect"
	GPoint		normCoords_dst_tl = NormCoordsOfPixelInRect(gidPoint_tl, dstRect_tl);
	if (geoBuffer->flipV)
		normCoords_dst_tl.y = 1.0 - normCoords_dst_tl.y;
	if (geoBuffer->flipH)
		normCoords_dst_tl.x = 1.0 - normCoords_dst_tl.x;
	
	//	the srcRect coords use the bottom-left as the origin- convert this to a rect using the top-left origin coordinate system
	GRect		srcRect_bl = geoBuffer->srcRectCart;
	GRect		srcRect_tl = MakeRect( srcRect_bl.origin.x, srcTexture.get_height()-(srcRect_bl.origin.y+srcRect_bl.size.height), srcRect_bl.size.width, srcRect_bl.size.height );
	
	GPoint		pxlCoords_src_tl = PixelForNormCoordsInRect( normCoords_dst_tl, srcRect_tl );
	
	//	sample srcTexture at these pixel coords
	constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::pixel);
	const float4			srcColor = srcTexture.sample(sampler, float2(pxlCoords_src_tl.x,pxlCoords_src_tl.y)) * geoBuffer->colorMultiplier;
	outTexture.write(srcColor, gid);
	
}

