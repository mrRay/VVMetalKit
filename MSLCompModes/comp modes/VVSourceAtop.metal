float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	//	assume the color to be the color of the top pixel...
	
	//	if the top pixel is transparent, something may be visible "through" it
	float		TTO = top.a*topAlpha;	//	"total top opacity". 1.0 is "fully opaque".
	//	the less opaque the top, the more the bottom should "show through"- unless the bottom is transparent!
	float		TBO = bottom.a;	//	"total bottom opacity".  1.0 is "fully opaque".
	
	//	...so use TBO to calculate the "real bottom color"...
	float4		realBottom = mix(bottom,top,(1.0-TBO));
	//	...then use TTO to calculate how much this shows through the top color...
	float4		realTop = mix(realBottom, top, TTO);
	
	
	float4		returnMe = realTop;
	//returnMe.a = 1.0;
	//returnMe.a = (top.a*topAlpha) + (bottom.a*(1.0-topAlpha));
	returnMe.a = (TTO) + (bottom.a * (1.0-TTO));
	return returnMe;
	
	
}


float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha, thread MSLCompModeFragData & fragData)	{
	return float4(bottom.r, bottom.g, bottom.b, bottom.a*bottomAlpha);
}
//vec4 CompositeTop(vec4 top, float topAlpha)	{
//	vec4		returnMe = vec4(topAlpha)*top;
//	//returnMe.a = 0.0;
//	return returnMe;
//}
