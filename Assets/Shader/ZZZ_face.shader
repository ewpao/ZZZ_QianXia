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
        [Toggle(_USE_OUTLINE_NOISE)] _UseOutlineNoise("Use Outline Noise", Range(0,1)) = 1 //描边噪声总开关（关闭后宽度均匀，且剔除噪声计算）
        _NoiseTillOffset("Noise Tiling(XY) Offset(ZW)", Vector) = (10, 10, 0, 0) //噪声平铺(xy,物体空间/米)/偏移(zw)
        _OutlineNoiseStrength("Outline Noise Strength", Range(0, 1)) = 0.3 //噪声对粗细的影响强度（0=均匀，1=±100%）
        _OutlineNoiseAnimSpeed("Outline Noise Anim Speed", Range(0, 5)) = 0 //噪声流动速度（0=静态，沿对角线滚动采样坐标）
        _NoiseContrast("Noise Contrast", Range(0.5, 4)) = 1.0 //噪声对比度（>1 拉开黑白差距，<1 变柔和）

        [Header(Debug)]
        [Enum(Off,0,Vertex Color,1,View Normal,2,Smooth Normal,3,Noise,4)] _DebugMode("Debug Mode", Float) = 0 //调试可视化下拉：0=正常渲染，1=顶点色，2=观察空间法线，3=平滑法线(uv1)，4=柏林噪声预览
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

            #pragma shader_feature_local _USE_OUTLINE_NOISE

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
                half _NoiseContrast;

                // 调试
                half _DebugMode;
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

            // 噪声对比度：sign(n)*|n|^(1/c)，c>1 拉开黑白、c<1 变柔和，零点结构不变
            float applyNoiseContrast(float n, float c)
            {
                return sign(n) * pow(abs(n), 1.0 / c);
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
                    float3 uv1        : TEXCOORD1;  // 平滑法线（脚本写入，调试预览用）
                    float3 normalOS   : NORMAL;     // 模型空间法线
                    float4 color      : COLOR;      // 顶点颜色
                };

                struct Varyings
                {
                    float4 positionCS : SV_POSITION; // 裁剪空间坐标
                    float2 uv0        : TEXCOORD0;   // 主纹理 UV
                    float3 positionOS : TEXCOORD1;   // 模型空间坐标（噪声调试预览用，与描边 Pass 同源）
                    float3 normalWS   : TEXCOORD2;   // 世界空间法线
                    float3 uv1        : TEXCOORD3;   // 平滑法线（调试预览用）
                    float4 color      : COLOR;       // 顶点颜色
                };

                Varyings vert(Attributes i)
                {
                    Varyings o;

                    // 模型空间 -> 裁剪空间
                    o.positionCS = TransformObjectToHClip(i.positionOS.xyz);

                    // UV 传递（应用 Tiling/Offset）
                    o.uv0 = TRANSFORM_TEX(i.uv0, _BaseMap);
                    o.positionOS = i.positionOS.xyz;
                    // 法线：模型空间 -> 世界空间
                    o.normalWS = TransformObjectToWorldNormal(i.normalOS);

                    // 平滑法线透传（调试预览用）
                    o.uv1 = i.uv1;

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

                    // ===== 调试可视化（_DebugMode 下拉，0=正常渲染）=====
                    // 噪声预览与描边 Pass 同一采样坐标（模型空间 XY 投影），所见即所得
                    if (_DebugMode == 1) // 顶点色
                        return half4(vertexcolor.ggg, 1.0);
                    if (_DebugMode == 2) // 观察空间法线
                    {
                        half3 normalVS = TransformWorldToViewDir(i.normalWS, true);
                        return half4(abs(i.normalWS), 1);
                    }
                    if (_DebugMode == 3) // uv1 中烘焙的平滑法线
                        return half4(i.uv1, 1);
                    if (_DebugMode == 4) // Perlin 噪声预览
                    {
                        float2 nuv = i.positionOS.xy * _NoiseTillOffset.xy + _NoiseTillOffset.zw + _Time.y * _OutlineNoiseAnimSpeed;
                        float n = applyNoiseContrast(perlinNoise2D(nuv), _NoiseContrast) * 0.5 + 0.5;
                        return half4(n, n, n, 1);
                    }

                    return color;
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
                    float2 uv0        : TEXCOORD0;  // 主纹理 UV
                    float3 uv1        : TEXCOORD1;  // 平滑法线（脚本写入）
                    float4 color      : COLOR;      // 顶点颜色
                };

                struct OutlineVaryings
                {
                    float4 positionCS : SV_POSITION;
                };

                OutlineVaryings vertOutline(OutlineAttributes v)
                {
                    OutlineVaryings o;

                    // 1. 视图空间位置与法线（背面法核心：在视图空间沿法线膨胀后再投影）
                    VertexPositionInputs posInputs = GetVertexPositionInputs(v.positionOS.xyz);
                    float3 positionVS = posInputs.positionVS;
                    // 平滑法线优先：从 TEXCOORD1（脚本写入的平滑法线）取，解决硬边/UV缝合处描边断裂；
                    // 未烘焙时 uv1 为 0，回退到硬法线 normalOS
                    float3 smoothNormalOS = dot(v.uv1, v.uv1) > 1e-6 ? v.uv1 : v.normalOS;
                    float3 normalVS = normalize(TransformWorldToViewDir(TransformObjectToWorldNormal(smoothNormalOS)));

                    // 2. Perlin 噪声调制描边粗细（_USE_OUTLINE_NOISE 关闭时 noiseFactor=1，宽度均匀）：
                    //    - 采样坐标用模型空间 positionOS.xy 投影而非 UV：UV 缝合两侧的同位置副本
                    //      会采到不同噪声值导致宽度跳变（描边断裂），物体空间坐标天然无缝
                    //    - 经 _NoiseTillOffset(xy 平铺, zw 偏移) 变换后采样 2D Perlin
                    //    - _OutlineNoiseAnimSpeed 沿对角线滚动采样坐标实现流动（0=静态）
                    //    - noiseFactor = 1 + n*strength，恒正、在 [1-s, 1+s] 区间围绕基准起伏
                    float noiseFactor = 1.0;
                    #if defined(_USE_OUTLINE_NOISE)
                        float2 noiseCoord = v.positionOS.xy * _NoiseTillOffset.xy + _NoiseTillOffset.zw + _Time.y * _OutlineNoiseAnimSpeed;
                        float n = applyNoiseContrast(perlinNoise2D(noiseCoord), _NoiseContrast);
                        noiseFactor = 1.0 + n * _OutlineNoiseStrength;
                    #endif
                    float outlineWidth = _OutlineWidth * noiseFactor;

                    // 3. 沿视图空间法线膨胀（背面法）：
                    //    - 只用 normalVS.xy 在屏幕平面方向外扩，z 方向不动，避免拉近时穿模
                    //    - 乘 viewDepth 抵消透视投影的 1/z 缩放，使屏幕空间描边宽度近似一致（不受距离影响）
                    //    - clampW 距离衰减：viewDepth < _OutlineMaxDistance 保持满粗细，超出按比例变细
                    //    - 0.001 是 _OutlineWidth(0~10) 到视图空间单位的缩放系数
                    float viewDepth = -positionVS.z;
                    float clampW = saturate(_OutlineMaxDistance / viewDepth);
                    positionVS.xy += normalVS.xy * outlineWidth * 0.001 * viewDepth * clampW;

                    // 4. 投影到裁剪空间
                    o.positionCS = mul(UNITY_MATRIX_P, float4(positionVS, 1.0));

                    // 5. Z 偏移：调整描边与主体的深度关系，防穿模/控遮挡
                    //    正值沉后(URP Reverse-Z)，负值前移；clip 空间常数偏移，近处效果更强
                    o.positionCS.z += -_OutlineZOffset * o.positionCS.w;

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
