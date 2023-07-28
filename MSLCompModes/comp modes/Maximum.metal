float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	//	This code behavior designed to match the CoreImage Maximum mode
	float4		returnMe;
	returnMe.r = (top.r * topAlpha > bottom.r * bottom.a) ? (top.r * topAlpha) : (bottom.r * bottom.a);
	returnMe.g = (top.g * topAlpha > bottom.g * bottom.a) ? (top.g * topAlpha) : (bottom.g * bottom.a);
	returnMe.b = (top.b * topAlpha > bottom.b * bottom.a) ? (top.b * topAlpha) : (bottom.b * bottom.a);
	returnMe.a = (top.a * topAlpha > bottom.a * bottom.a) ? (top.a * topAlpha) : (bottom.a * bottom.a);
		
	//	This code does maximum brightness by overall pixel
	//	Might be useful as its own shader
	//float		brightBot = bottomAlpha * bottom.a * (bottom.r + bottom.g + bottom.b) / 3.0;
	//float		brightTop = topAlpha * top.a * (top.r + top.g + top.b) / 3.0;
	//float4		returnMe;
	//returnMe = (brightBot > brightTop) ? (bottom * bottomAlpha) : (top * topAlpha);
	
	return returnMe;
}


float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha, thread MSLCompModeFragData & fragData)	{
	float4		returnMe = float4(bottomAlpha)*bottom;
	//returnMe.a = 1.0;
	return returnMe;
}
//vec4 CompositeTop(vec4 top, float topAlpha)	{
//	vec4		returnMe = vec4(topAlpha)*top;
//	//returnMe.a = 1.0;
//	return returnMe;
//}
