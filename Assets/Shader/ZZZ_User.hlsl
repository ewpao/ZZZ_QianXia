#ifndef ZZZ_USER_INCLUDED
#define ZZZ_USER_INCLUDED

// =============================================================================
// 多段色阶阴影公共头文件（基于 MultiBandNormalShadow 算法）
// -----------------------------------------------------------------------------
// 核心流程（完全透明，无黑盒）：
//   1. DecodePackedNormalWS     ：用 RG 通道重建切线空间法线并转到世界空间（支持双面翻转）
//   2. 计算 1 维受光坐标 x      ：身体用 N·L + (B*2-1)*Bias；脸部用 SDF/法线融合
//   3. ApplyCastShadowToCoord   ：可选把 URP 实时投影压向遮挡上限 castShadowLimit
//   4. EvaluateMultiBandPalette ：用 6 组 (Center, Width) 的抗锯齿 smoothstep 顺序混合 7 段颜色
// =============================================================================

// 打包法线解码：用贴图 RG 重建切线空间 XYZ，再通过正交化 TBN 转到世界空间。
// rawTangentWS.w 应传入 input.tangentOS.w * GetOddNegativeScale()；
// faceSign 为双面符号（正面 +1，背面 -1；单面 Cull Back 传 1.0 即可）。
float3 DecodePackedNormalWS(
    float3 rawNormalWS,
    float4 rawTangentWS,
    float2 packedXY,
    float  normalStrength,
    float  faceSign)
{
    float3 normalWS = SafeNormalize(rawNormalWS);

    // Gram-Schmidt 正交化，避免插值后切线与法线不垂直；切线无效或强度为 0 时直接回退几何法线
    float3 tangentWS = rawTangentWS.xyz - normalWS * dot(rawTangentWS.xyz, normalWS);
    float tangentLengthSq = dot(tangentWS, tangentWS);
    if (normalStrength <= 0.0 || tangentLengthSq <= 1e-6 || abs(rawTangentWS.w) < 0.5)
        return normalWS * faceSign;

    tangentWS *= rsqrt(tangentLengthSq);
    float3 bitangentWS = cross(normalWS, tangentWS) * rawTangentWS.w;

    // RG 从 [0,1] 映射到 [-1,1]，限制 XY 长度后由 X²+Y²+Z²=1 重建 Z，背面翻转 Z 方向
    float2 xy = (packedXY * 2.0 - 1.0) * normalStrength;
    xy *= rsqrt(max(1.0, dot(xy, xy)));
    float z = sqrt(saturate(1.0 - dot(xy, xy))) * faceSign;

    return SafeNormalize(tangentWS * xy.x + bitangentWS * xy.y + normalWS * z);
}

// 单条分界的混合因子：左侧为 0，右侧为 1，中点 center 处为 0.5。
// 用 fwidth(x) 限制最小过渡宽度，减轻细边界在远处的闪烁锯齿。
float BandTransition(float x, float center, float width, float pixelWidth)
{
    float halfWidth = 0.5 * max(max(width, pixelWidth), 1e-4);
    return smoothstep(center - halfWidth, center + halfWidth, x);
}

// 接收实时阴影：被阴影遮挡时，把坐标 x 压向不超过 castShadowLimit 的暗部位置。
float ApplyCastShadowToCoord(
    float x,
    float shadowAttenuation,
    float castShadowStrength,
    float castShadowLimit)
{
    float occlusion = (1.0 - saturate(shadowAttenuation)) * saturate(castShadowStrength);
    return lerp(x, min(x, castShadowLimit), occlusion);
}

// 从深影色 (1) 开始，依次把 2~7 段颜色按 6 条分界 (Center, Width) 混进来。
float3 EvaluateMultiBandPalette(
    float  x,
    float3 deepColor,
    float3 shadowColor,
    float3 softShadowColor,
    float3 midColor,
    float3 warmColor,
    float3 lightColor,
    float3 brightColor,
    float  center1, float width1,
    float  center2, float width2,
    float  center3, float width3,
    float  center4, float width4,
    float  center5, float width5,
    float  center6, float width6)
{
    float pixelWidth = fwidth(x);

    // 约束每个后续中心至少不小于前一个中心，保证从暗到亮的顺序不倒挂
    float c2 = max(center1, center2);
    float c3 = max(c2, center3);
    float c4 = max(c3, center4);
    float c5 = max(c4, center5);
    float c6 = max(c5, center6);

    float3 color = lerp(deepColor, shadowColor, BandTransition(x, center1, width1, pixelWidth));
    color = lerp(color, softShadowColor, BandTransition(x, c2, width2, pixelWidth));
    color = lerp(color, midColor,        BandTransition(x, c3, width3, pixelWidth));
    color = lerp(color, warmColor,       BandTransition(x, c4, width4, pixelWidth));
    color = lerp(color, lightColor,      BandTransition(x, c5, width5, pixelWidth));
    return  lerp(color, brightColor,     BandTransition(x, c6, width6, pixelWidth));
}

#endif // ZZZ_USER_INCLUDED
