// 1. 计算明暗主变量 shad
float d0   = dot(Nw, L);
float t    = saturate(1.5 + Nw.y - 0.5 * min(1.0, 3.0 * L.y));
float d    = lerp(d0, (1.0 + d0) * t - 1.0, v7.y);
float bias = 2.0 * _LightTex.b - 1.0;
float shad = 2.0 * bias + d;

// 2. 7 段单位分解基函数 (sum(a0..a6) == 1)
float s = max(1e-5, _AlbedoSmoothness_k);
float W = rcp(s);
float D = 2.0 - 3.0 * s;

float A = ( 3.0 + 3.0 * shad) / D;
float B = ( 1.0 + 3.0 * shad - 1.5 * s) / D;
float C = (-1.0 + 3.0 * shad - 4.5 * s) / D;

float Tx = W * (shad + 0.3333) + 0.5;
float Ty = W * (shad - 0.3333) + 0.5;
float Tz = W * (shad - 0.3333) - 0.5;

float a0 = saturate(1.0 - A);              // ShadowFade
float a1 = saturate(min(1.0 - Tx, A));     // Shadow
float a2 = saturate(min(Tx, 1.0 - B));     // ShallowFade
float a3 = saturate(min(1.0 - Ty, B));     // Shallow
float a4 = saturate(min(1.0 - Tz, Ty));    // SSS 窄带 (宽 2s)
float a5 = saturate(min(Tz, 1.0 - C));     // Front
float a6 = saturate(C);                    // White (纯白直射)

// 3. 实时阴影 S ∈ [0, 1] -> 三态三角基 -> 重路由进 7 段权重
float Sh = saturate(1.0 - 2.0 * S);
float Pe = saturate(min(2.0 * S, 2.0 - 2.0 * S));
float Li = saturate(2.0 * S - 1.0);
// (实机模式：Sh *= entityVal32; Pe *= entityVal32;)

float wShadowFade  = v7.x * a0;
float wShadow      = (1.0 - v7.x) * a0 + a1;
float wShallowFade = a2 + Sh * (1.0 - a0 - a1 - a2); // 全阴区落点
float wShallow     = a3 * (Pe + Li);
float wSss         = a4 * (Pe + Li) + (a5 + a6) * Pe; // 半影自动生 SSS 暖边
float wFront       = a5 * Li;
float wWhite       = a6 * Li;

// 4. 局部色距离去饱和归一化 C(c) + 全局 6 元组 Tint
float wDist = min(1.0, 0.43725 * distance(_WorldSpaceCameraPos, P));
float alpha = _ShadowColorFadeByZ * (1.0 - wDist * (1.0 - _PackedParams0.w));
float3 normChroma(float3 c) {
    c += 6.10351562e-5;
    return lerp(c, saturate(c / dot(c, 0.33333)), alpha);
}

float3 shC = normChroma(_ShallowColor_k);
float3 sdC = normChroma(_ShadowColor_k);
// isSkin ? _Skin*Tint : _Post*Tint
float3 darkSum = wShadowFade  * (sdC * TintShadowFade)
               + wShadow      * (sdC * TintShadow)
               + wShallowFade * (shC * TintShallowFade)
               + wShallow     * (shC * TintShallow);
float3 litSum  = wFront * TintFront + wSss * TintSss + wWhite;

// 5. 双轨主光防过曝合成
float3 L_eff  = lightColor * distAttenEff;
float3 L_dark = L_eff * min(1.0, rcp(max(max(lightColor.r, lightColor.g), lightColor.b)));
float3 finalLight = lerp(lightColor, L_dark * darkSum + L_eff * litSum, _Color.a);