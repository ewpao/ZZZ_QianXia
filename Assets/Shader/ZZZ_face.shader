Shader "ZZZ/ZZZ_face"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map" ,2D) = "white" {}

        [Header(Outline)]
        _OutlineWidth("Outline Width", Range(0, 10)) = 2.0 //描边宽度（像素级）
        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1) //描边颜色
        _OutlineMaxDistance("Outline Max Distance", Range(0.1, 100)) = 10.0 //衰减起点(米)：该距离内保持满粗细，超出按距离衰减变细
        _OutlineZOffset("Outline Z Offset", Range(-1, 1)) = 0.0 //描边深度偏移：正值沉后(URP Reverse-Z)，负值前移

        [Header(Outline Noise)]
        _NoiseTillOffset("Noise Tiling(XY) Offset(ZW)", Vector) = (10, 10, 0, 0) //噪声平铺(xy)/偏移(zw)，对齐 Unity Tiling/Offset 用法
        _OutlineNoiseStrength("Outline Noise Strength", Range(0, 1)) = 0.3 //噪声对粗细的影响强度（0=均匀，1=±100%）
        _OutlineNoiseAnimSpeed("Outline Noise Anim Speed", Range(0, 5)) = 0 //噪声流动速度（0=静态，沿对角线滚动 UV）

        [Header(Debug)]
        _DebugNoise("Debug Noise", Range(0,1)) = 0 //临时查看柏林噪声贴图（1=显示噪声，0=正常渲染）
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        HLSLINCLUDE//公共代码块

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库

            // 材质属性常量缓冲区（所有 Pass 共用，保证 SRP Batcher 兼容）
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half _OutlineWidth;
                half4 _OutlineColor;
                float _OutlineMaxDistance;
                float _OutlineZOffset;

                // 描边噪声
                float4 _NoiseTillOffset;
                half _OutlineNoiseStrength;
                half _OutlineNoiseAnimSpeed;

                // 调试
                half _DebugNoise;
            CBUFFER_END

            // ===== 2D Perlin 梯度噪声（sin 哈希版，轻量/SM2.0 友好）=====
            // 梯度由 hash22 直接给出（未归一化，幅度有轻微不均，描边够用）；返回约 [-1,1]
            float2 hash22(float2 p)
            {
                p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
                return -1.0 + 2.0 * frac(sin(p) * 43758.5453123);
            }

            float perlinNoise2D(float2 p)
            {
                float2 pi = floor(p);
                float2 pf = frac(p);
                // quintic 衰减（C²），比 smoothstep(3-2t) 更平滑，消除网格接缝
                float2 u = pf * pf * pf * (pf * (pf * 6.0 - 15.0) + 10.0);

                float n00 = dot(hash22(pi + float2(0.0, 0.0)), pf - float2(0.0, 0.0));
                float n10 = dot(hash22(pi + float2(1.0, 0.0)), pf - float2(1.0, 0.0));
                float n01 = dot(hash22(pi + float2(0.0, 1.0)), pf - float2(0.0, 1.0));
                float n11 = dot(hash22(pi + float2(1.0, 1.0)), pf - float2(1.0, 1.0));

                return lerp(lerp(n00, n10, u.x), lerp(n01, n11, u.x), u.y);
            }

        ENDHLSL

        pass
        {
            Name "UniversalForward"//给pass通道命名

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag

                // 纹理声明
                TEXTURE2D(_BaseMap);
                SAMPLER(sampler_BaseMap);

                struct Attributes
                {
                    float4 positionOS : POSITION;   // 模型空间坐标
                    float2 uv0        : TEXCOORD0;  // UV
                    float3 normalOS   : NORMAL;     // 模型空间法线
                    float4 color      : COLOR;      // 顶点颜色
                };

                struct Varyings
                {
                    float4 positionCS : SV_POSITION; // 裁剪空间坐标
                    float2 uv0        : TEXCOORD0;   // 主纹理 UV
                    float3 normalWS   : TEXCOORD2;   // 世界空间法线
                    float4 color      : COLOR;       // 顶点颜色
                };

                Varyings vert(Attributes i)
                {
                    Varyings o;

                    // 模型空间 -> 裁剪空间
                    o.positionCS = TransformObjectToHClip(i.positionOS.xyz);

                    // UV 传递（应用 Tiling/Offset）
                    o.uv0 = TRANSFORM_TEX(i.uv0, _BaseMap);
                    // 法线：模型空间 -> 世界空间
                    o.normalWS = TransformObjectToWorldNormal(i.normalOS);

                    // 顶点颜色
                    o.color = i.color;

                    return o;
                }

                half4 frag(Varyings i) : SV_TARGET
                {
                    // 采样光源
                    Light light = GetMainLight();

                    // 采样纹理
                    half4 basecolor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv0);

                    // 归一化向量
                    half3 N = normalize(i.normalWS);
                    half3 L = normalize(light.direction);

                    // ===== 漫反射（Half-Lambert）=====
                    half NdotL = saturate(dot(N, L));
                    half halfLambert = saturate(NdotL * 0.5 + 0.5);
                    halfLambert = halfLambert * halfLambert * halfLambert;

                    // ===== 最终颜色 = 漫反射 + 高光贴图 =====
                    half4 color = half4(basecolor.rgb * light.color * halfLambert, basecolor.a);

                    // 采样顶点色
                    half3 vertexcolor = i.color.rgb;

                    // 临时调试：直出 Perlin 噪声贴图（_DebugNoise=1 时生效）
                    // 注意此处用经过 BaseMap Tiling/Offset 的 i.uv0；若 BaseMap 平铺≠1，图案与描边噪声会有差异
                    if (_DebugNoise > 0.5)
                    {
                        float2 nuv = i.uv0 * _NoiseTillOffset.xy + _NoiseTillOffset.zw + _Time.y * _OutlineNoiseAnimSpeed;
                        float n = perlinNoise2D(nuv) * 0.5 + 0.5;
                        return half4(n, n, n, 1);
                    }

                    return color;
                    //return half4(vertexcolor.ggg,1); // 调试：直出顶点色
                }

            ENDHLSL
        }

        pass
        {
            Name "Outline"

            Tags
            {
                "LightMode" = "SRPDefaultUnlit" // URP 默认会绘制，保证主相机下描边可见
            }

            Cull Front  // 剔除正面，只渲染膨胀后的背面，形成轮廓
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM

                #pragma vertex vertOutline
                #pragma fragment fragOutline

                struct OutlineAttributes
                {
                    float4 positionOS : POSITION;   // 模型空间坐标
                    float3 normalOS   : NORMAL;     // 模型空间法线
                    float2 uv0        : TEXCOORD0;  // UV（用于噪声采样）
                    float4 color      : COLOR;      // 顶点颜色
                };

                struct OutlineVaryings
                {
                    float4 positionCS : SV_POSITION;
                };

                OutlineVaryings vertOutline(OutlineAttributes v)
                {
                    OutlineVaryings o;

                    VertexPositionInputs posInputs = GetVertexPositionInputs(v.positionOS.xyz);
                    o.positionCS = posInputs.positionCS;

                    // 1. 观察空间法线（用于决定膨胀方向）
                    VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS); // 转换法线空间
                    float3 normalVS = TransformWorldToViewDir(normalInput.normalWS, true);

                    // 2. Perlin 噪声调制描边粗细：
                    //    - UV 经 _NoiseTillOffset(xy 平铺, zw 偏移) 变换后采样 2D Perlin
                    //    - _OutlineNoiseAnimSpeed 沿对角线滚动 UV 实现流动（0=静态）
                    //    - noiseFactor = 1 + n*strength，恒正、在 [1-s, 1+s] 区间围绕基准起伏
                    //    - 顶点色 G 通道仍作为整体粗细遮罩：G=0 无描边，G=1 全宽
                    float2 noiseUV = v.uv0 * _NoiseTillOffset.xy + _NoiseTillOffset.zw + _Time.y * _OutlineNoiseAnimSpeed;
                    float noiseFactor = 1.0 + perlinNoise2D(noiseUV) * _OutlineNoiseStrength;
                    float outlineWidth = _OutlineWidth * v.color.g * noiseFactor;

                    // 3. 裁剪空间下沿法线方向膨胀：
                    //    - normalize 后乘 outlineWidth 得到像素级偏移量
                    //    - 除以 _ScreenParams.xy*0.5 把像素偏移转为 NDC 偏移，修正屏幕宽高比（分辨率无关）
                    //    - 乘 positionCS.w 从 NDC 还原到裁剪空间
                    //    - clampW 距离衰减：w < _OutlineMaxDistance 保持满粗细，超出按 _OutlineMaxDistance/w 衰减
                    float2 extent = normalize(normalVS.xy) * outlineWidth;
                    extent /= _ScreenParams.xy * 0.5;
                    float clampW = clamp(_OutlineMaxDistance / o.positionCS.w, 0.0, 1.0);
                    o.positionCS.xy += extent * o.positionCS.w * clampW;

                    // 4. Z 偏移：调整描边与主体的深度关系，防穿模/控遮挡
                    //    正值沉后(URP Reverse-Z)，负值前移；clip 空间常数偏移，近处效果更强
                    o.positionCS.z += -_OutlineZOffset;

                    return o;
                }

                half4 fragOutline(OutlineVaryings i) : SV_TARGET
                {
                    return half4(_OutlineColor.rgb, 1.0);
                }

            ENDHLSL
        }
    }
}
