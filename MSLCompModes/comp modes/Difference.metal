
float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha)	{
	float4		DB = float4(bottom.a)*bottom;
	DB.a = bottom.a;
	float		TA = top.a*topAlpha;
	float4		DT = float4(TA) * top;
	DT.a = TA;
	float4		returnMe = abs(DT-DB);
	returnMe.a = 1.0;
	return returnMe;
}

float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha)	{
	return float4(bottom.r, bottom.g, bottom.b, bottom.a*bottomAlpha);
}
