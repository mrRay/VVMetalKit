//	adapted from http://transitions.glsl.io/transition/d71472a550601b96d69d

const constant float2 heartSize = float2(0.5,0.4);

bool inHeart (float2 p, float2 center, float size) {
	if (size == 0.0) return false;
	float2 o = (p-center)/(1.6*size);
	return pow(o.x*o.x+o.y*o.y-0.3, 3.0) < o.x*o.x*pow(o.y, 3.0);
}
 
float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)	{
	float		side = max(fragData._VVCanvasRect.z,fragData._VVCanvasRect.w) / 1.25;

	float		m = inHeart(fragData.gl_FragCoord.xy, heartSize * fragData._VVCanvasRect.zw, side*topAlpha) ? 1.0 : 0.0;

	float4		darkenedBottom = float4(bottom.a) * bottom;
	darkenedBottom.a = bottom.a;
	float4		returnMe = darkenedBottom;
	returnMe = (m > 0.0) ? top : returnMe;
	return returnMe;
}

float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha, thread MSLCompModeFragData & fragData)	{
	float		side = max(fragData._VVCanvasRect.z,fragData._VVCanvasRect.w) / 1.25;

	float		m = inHeart(fragData.gl_FragCoord.xy, heartSize * fragData._VVCanvasRect.zw, side*bottomAlpha) ? 1.0 : 0.0;

	float4		darkenedBottom = float4(0.0);
	float4		returnMe = darkenedBottom;
	returnMe = (m > 0.0) ? bottom : returnMe;
	return returnMe;
}

//vec4 CompositeTop(vec4 top, float topAlpha)	{
//	return vec4(0.0, 0.0, 0.0, 0.0);
//}
