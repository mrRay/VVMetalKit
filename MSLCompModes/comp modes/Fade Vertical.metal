//	adapted from http://transitions.glsl.io/transition/90000743fedc953f11a4

const constant float2 fadeVertDirection = float2(0.0,1.0);
const constant float2 fadeVertCenter = float2(0.5, 0.5);
const constant float fadeVertSmoothness = 0.5;


float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	float2		p = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
	float4		darkenedBottom = float4(bottom.a) * bottom;
	darkenedBottom.a = bottom.a;
	float4		returnMe = darkenedBottom;
	float2		v = normalize(fadeVertDirection);
	v /= abs(v.x)+abs(v.y);
	float d = v.x * fadeVertCenter.x + v.y * fadeVertCenter.y;
	float m = smoothstep(-fadeVertSmoothness, 0.0, v.x * p.x + v.y * p.y - (d-0.5+topAlpha*(1.+fadeVertSmoothness)));
	returnMe = mix(top, darkenedBottom, m);
	return returnMe;
}


float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha, thread MSLCompModeFragData & fragData)	{
	float2		p = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
	float4		darkenedBottom = float4(0.0);
	float4		returnMe = darkenedBottom;
	float2		v = normalize(fadeVertDirection);
	v /= abs(v.x)+abs(v.y);
	float d = v.x * fadeVertCenter.x + v.y * fadeVertCenter.y;
	float m = smoothstep(-fadeVertSmoothness, 0.0, v.x * p.x + v.y * p.y - (d-0.5+bottomAlpha*(1.+fadeVertSmoothness)));
	returnMe = mix(bottom, darkenedBottom, m);
	return returnMe;
}
//vec4 CompositeTop(vec4 top, float topAlpha)	{
//	return vec4(0.0, 0.0, 0.0, 0.0);
//}
