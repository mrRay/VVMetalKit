

float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	float2		loc = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
	float4		darkenedBottom = float4(bottom.a) * bottom;
	darkenedBottom.a = bottom.a;
	float4		returnMe = darkenedBottom;
	returnMe = (topAlpha < loc.y) ? returnMe : top;
	return returnMe;
}

float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha, thread MSLCompModeFragData & fragData)	{
    float2        loc = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
    float4        returnMe = (bottomAlpha < loc.y) ? float4(0.) : bottom;
    return returnMe;
}

//vec4 CompositeTop(vec4 top, float topAlpha)	{
//	return vec4(0.0, 0.0, 0.0, 0.0);
//}
