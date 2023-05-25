
float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha)	{
	float4		DB = float4(bottom.a)*bottom;
	DB.a = bottom.a;
	float		TA = top.a*topAlpha;
	float4		DT = float4(TA) * top;
	DT.a = TA;
	float4		returnMe = DT+DB;
	returnMe.r = (returnMe.r > 1.0) ? (returnMe.r - 1.0) : returnMe.r;
	returnMe.g = (returnMe.g > 1.0) ? (returnMe.g - 1.0) : returnMe.g;
	returnMe.b = (returnMe.b > 1.0) ? (returnMe.b - 1.0) : returnMe.b;
	//returnMe.a = (returnMe.a > 1.0) ? (returnMe.a - 1.0) : returnMe.a;
	returnMe.a = 1.0;
	return returnMe;
}

float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha)	{
	return float4(bottom.r, bottom.g, bottom.b, bottom.a*bottomAlpha);
}
