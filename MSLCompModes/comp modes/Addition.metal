
float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)	{
	float		TA = (topAlpha*top.a);
	float4		DT = top * float4(TA);
	//float4		DT = top * float4(topAlpha);
	DT.a = TA;
	
	float4		returnMe;
	//returnMe = bottom*float4(bottom.a) + DT;
	returnMe = bottom + DT;
	returnMe.a = max(bottom.a, TA);
	
	return returnMe;
}

float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha, thread MSLCompModeFragData & fragData)	{
	//return float4(bottom.r, bottom.g, bottom.b, bottom.a*bottomAlpha);
	//return float4(bottomAlpha)*bottom;
	float4		returnMe;
	returnMe = float4(bottomAlpha)*bottom;
	//returnMe.a = 1.0;
	returnMe.a = bottom.a*bottomAlpha;
	return returnMe;
}
