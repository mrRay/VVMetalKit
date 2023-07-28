//	adapted from http://transitions.glsl.io/transition/90000743fedc953f11a4


const constant float2 fadeHorizDirection = float2(1.0,0.0);
const constant float2 fadeHorizCenter = float2(0.5, 0.5);
const constant float fadeHorizSmoothness = 0.5;


float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	float2		p = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
	float4		darkenedBottom = float4(bottom.a) * bottom;
	darkenedBottom.a = bottom.a;
	float4		returnMe = darkenedBottom;
	float2		v = normalize(fadeHorizDirection);
	v /= abs(v.x)+abs(v.y);
	float d = v.x * fadeHorizCenter.x + v.y * fadeHorizCenter.y;
	float m = smoothstep(-fadeHorizSmoothness, 0.0, v.x * p.x + v.y * p.y - (d-0.5+topAlpha*(1.+fadeHorizSmoothness)));
	returnMe = mix(top, darkenedBottom, m);
	return returnMe;
}


float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha, thread MSLCompModeFragData & fragData)	{
	float2		p = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
	float4		darkenedBottom = float4(0.0);
	float4		returnMe = darkenedBottom;
	float2		v = normalize(fadeHorizDirection);
	v /= abs(v.x)+abs(v.y);
	float d = v.x * fadeHorizCenter.x + v.y * fadeHorizCenter.y;
	float m = smoothstep(-fadeHorizSmoothness, 0.0, v.x * p.x + v.y * p.y - (d-0.5+bottomAlpha*(1.+fadeHorizSmoothness)));
	returnMe = mix(bottom, darkenedBottom, m);
	return returnMe;
}
//vec4 CompositeTop(vec4 top, float topAlpha)	{
//	return vec4(0.0, 0.0, 0.0, 0.0);
//}
