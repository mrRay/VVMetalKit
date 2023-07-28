float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	float4		adjustedTop = float4(topAlpha)*top;
	float4		adjustedBottom = float4(bottom.a)*bottom;
	adjustedTop.a = 1.0;
	adjustedBottom.a = 1.0;
	return (adjustedTop*adjustedBottom);
	
}


float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha, thread MSLCompModeFragData & fragData)	{
	return float4(0.0, 0.0, 0.0, 0.0);
}
//vec4 CompositeTop(vec4 top, float topAlpha)	{
//	return vec4(0.0, 0.0, 0.0, 0.0);
//}
