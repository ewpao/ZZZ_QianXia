Shader "ZZZ/ZZZ_face"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map" ,2D) = "white" {}
        [Space(30)]

        [Header(Outline)]
        _OutlineWidth("Outline Width", Range(0, 10)) = 2.0 //描边宽度（像素级）
        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1) //描边颜色
        _OutlineMaxDistance("Outline Max Distance", Range(0.1, 100)) = 10.0 //衰减起点(米)：该距离内保持满粗细，超出按距离衰减变细
        _OutlineZOffset("Outline Z Offset", Range(-1, 1)) = 0.0 //描边深度偏移：正值沉后(URP Reverse-Z)，负值前移
        [Space(30)]

        [Header(Outline Noise)]
        [Toggle(_USE_OUTLINE_NOISE)] _UseOutlineNoise("Use Outline Noise", Range(0,1)) = 1 //描边噪声总开关（关闭后宽度均匀，且剔除噪声计算）
        _NoiseTillOffset("Noise Tiling(XY) Offset(ZW)", Vector) = (10, 10, 0, 0) //噪声平铺(xy,物体空间/米)/偏移(zw)
        _OutlineNoiseStrength("Outline Noise Strength", Range(0, 1)) = 0.3 //噪声对粗细的影响强度（0=均匀，1=±100%）
        _OutlineNoiseAnimSpeed("Outline Noise Anim Speed", Range(0, 5)) = 0 //噪声流动速度（0=静态，沿对角线滚动采样坐标）
        _NoiseContrast("Noise Contrast", Range(0.5, 4)) = 1.0 //噪声对比度（>1 拉开黑白差距，<1 变柔和）
        [Space(30)]

        [Header(SDF)]
        [Toggle(_USE_SDF)] _UseSDF("Use SDF", Range(0,1)) = 0 //sdf开关
        _SDFMap("SDF Map", 2D) = "white"{}
        _SDFWidth("SDF阴影过渡宽度", Range(0.01,0.25)) = 0.05
        _SDFWidthScale("SDF阴影过渡宽度倍率", Range(0.1,3)) = 1

        [Space(10)]
        _FaceForwardOS("Forward Direction", vector) = (0,0,1,0)
        _FaceRightOS("Right Direction", vector) = (1,0,0,0)
        _FaceUpOS("Up Direction", vector) = (0,1,0,0)
        [Space(20)]

        [Header(Band Colors)]
        _DeepColor("1 Deep Shadow", Color) = (0.62, 0.48, 0.50, 1)
        _ShadowColor("2 Shadow", Color) = (0.72, 0.58, 0.59, 1)
        _SoftShadowColor("3 Soft Shadow", Color) = (0.82, 0.69, 0.68, 1)
        _MidColor("4 Midtone", Color) = (0.90, 0.79, 0.76, 1)
        _WarmColor("5 Warm Transition", Color) = (1.00, 0.80, 0.72, 1)
        _LightColor("6 Light", Color) = (0.99, 0.96, 0.94, 1)
        _BrightColor("7 Bright Light", Color) = (1, 1, 1, 1)
        [Space(10)]

        [Header(Transition Centers and Full Widths)]
        _Center1("1 to 2 Center", Range(-1, 1)) = -0.72
        _Width1("1 to 2 Width", Range(0, 1)) = 0.30
        _Center2("2 to 3 Center", Range(-1, 1)) = -0.36
        _Width2("2 to 3 Width", Range(0, 1)) = 0.06
        _Center3("3 to 4 Center", Range(-1, 1)) = -0.04
        _Width3("3 to 4 Width", Range(0, 1)) = 0.28
        _Center4("4 to 5 Center", Range(-1, 1)) = 0.26
        _Width4("4 to 5 Width", Range(0, 1)) = 0.09
        _Center5("5 to 6 Center", Range(-1, 1)) = 0.45
        _Width5("5 to 6 Width", Range(0, 1)) = 0.06
        _Center6("6 to 7 Center", Range(-1, 1)) = 0.76
        _Width6("6 to 7 Width", Range(0, 1)) = 0.32
        [Space(10)]

        [Header(Lighting)]
        _DirectStrength("Main Light Strength", Range(0, 2)) = 1.0
        _AmbientStrength("Ambient Strength", Range(0, 1)) = 0.15
        _CastShadowStrength("Cast Shadow Influence", Range(0, 1)) = 0.0
        _CastShadowLimit("Occluded Lighting Coordinate", Range(-1, 1)) = -0.36
        [Space(20)]

        [Header(Debug)]
        [Enum(Off,0,Vertex Color,1,View Normal,2,Smooth Normal,3,Noise,4,Palette,5,LightingCoordinate,6,FaceAO Mask,7)] _DebugMode("Debug Mode", Float) = 0 //调试可视化下拉：0=正常渲染，1=顶点色，2=观察空间法线，3=平滑法线(uv1)，4=柏林噪声预览，5=7段色阶配色，6=色阶坐标x灰度，7=FaceAO(SDF与法线混合遮罩)
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

            #include "ZZZ_User.hlsl"

            #pragma shader_feature_local _USE_OUTLINE_NOISE
            #pragma shader_feature_local _USE_SDF

            // 纹理声明
            TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
            TEXTURE2D(_SDFMap);         SAMPLER(sampler_SDFMap);

            // 材质属性常量缓冲区（所有 Pass 共用，保证 SRP Batcher 兼容）
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _SDFMap_ST;

                half _OutlineWidth;
                half4 _OutlineColor;
                float _OutlineMaxDistance;
                float _OutlineZOffset;

                // 描边噪声
                half _UseOutlineNoise;
                float4 _NoiseTillOffset;
                half _OutlineNoiseStrength;
                half _OutlineNoiseAnimSpeed;
                half _NoiseContrast;

                // SDF
                half _UseSDF;
                half _SDFWidth;
                half _SDFWidthScale;
                float4 _FaceForwardOS;
                float4 _FaceRightOS;
                float4 _FaceUpOS;

                // 7 段色阶颜色与 6 条交界 (MultiBandNormalShadow)
                float4 _DeepColor;
                float4 _ShadowColor;
                float4 _SoftShadowColor;
                float4 _MidColor;
                float4 _WarmColor;
                float4 _LightColor;
                float4 _BrightColor;

                float _Center1, _Center2, _Center3, _Center4, _Center5, _Center6;
                float _Width1, _Width2, _Width3, _Width4, _Width5, _Width6;

                float _DirectStrength;
                float _AmbientStrength;
                float _CastShadowStrength;
                float _CastShadowLimit;

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

            float CalculateSignedFaceAngle(float lightRight, float lightForward) //atan2函数
            {
                float shorter = min(abs(lightRight), abs(lightForward));
                float longer = max(abs(lightRight), abs(lightForward));
                float ratio = shorter / max(longer, 1e-8);
                float ratioSquared = ratio * ratio;

                // 原程序的多项式系数：用小角度近似还原 atan2。
                float polynomial = ratioSquared * 0.0208350997 - 0.0851330012;
                polynomial = ratioSquared * polynomial + 0.180141002;
                polynomial = ratioSquared * polynomial - 0.330299497;
                polynomial = ratioSquared * polynomial + 0.999866009;
                float smallAngle = ratio * polynomial;

                float angle = smallAngle;
                if (abs(lightForward) < abs(lightRight))
                    angle += 1.57079637 - 2.0 * smallAngle;
                if (lightForward < 0.0)
                    angle -= 3.141593;
                if (min(-lightRight, lightForward) < 0.0 &&
                    max(-lightRight, lightForward) >= 0.0)
                    angle = -angle;
                return angle;
            }
            
            float CalculateFaceLightAngle(float3 lightDirWS)
            {
                float3 faceForwardWS = normalize(TransformObjectToWorldDir(_FaceForwardOS.xyz));
                float3 faceRightWS = normalize(TransformObjectToWorldDir(_FaceRightOS.xyz));
                float3 faceUpWS = normalize(TransformObjectToWorldDir(_FaceUpOS.xyz));

                float3 sdfuselight = normalize(lightDirWS);

                float axisBias = abs(dot(sdfuselight,faceUpWS) * 0.5); // 轴向偏置，0.5是系数
                sdfuselight.xz += faceForwardWS.xz * axisBias;

                sdfuselight = normalize(sdfuselight);

                sdfuselight.y = 1e-5;
                sdfuselight = normalize(sdfuselight);

                // 获得投影
                float lightForward = dot(sdfuselight,faceForwardWS);
                float lightRight = -dot(sdfuselight,faceRightWS);
                
                float angleRadians = CalculateSignedFaceAngle(lightRight,lightForward); //得到-PI到PI

                return angleRadians * 0.318309873; //约等于除以PI，转为-1到1
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
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
                #pragma multi_compile_fragment _ _SHADOWS_SOFT

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
                    float3 positionWS : TEXCOORD4;   // 世界空间坐标（实时阴影与距离去饱和用）
                    float4 color      : COLOR;       // 顶点颜色
                };

                Varyings vert(Attributes i)
                {
                    Varyings o;

                    // 模型空间 -> 裁剪空间 / 世界空间
                    VertexPositionInputs posInputs = GetVertexPositionInputs(i.positionOS.xyz);
                    o.positionCS = posInputs.positionCS;
                    o.positionWS = posInputs.positionWS;

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
                    // ① 采样 URP 主光（含实时投影，兼容 Cascade / Screen Space Shadows）
                    VertexPositionInputs posInputs = (VertexPositionInputs)0;
                    posInputs.positionWS = i.positionWS;
                    posInputs.positionCS = TransformWorldToHClip(i.positionWS);
                    Light light = GetMainLight(GetShadowCoord(posInputs));
                    float3 L = normalize(light.direction);

                    // 采样底色与法线
                    half4 basecolor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv0);
                    float3 N = SafeNormalize(i.normalWS);

                    // ② 计算 1 维受光色阶坐标 x：默认由 3D 法线 dot(N, L) 决定
                    float xNormal = dot(N, L);
                    float x = xNormal;
                    float faceAO = 0.0;

                    // 开启 SDF 时，将 SDF 亮暗映射到 [-1, 1]，再按 A 通道 (FaceAO) 与法线坐标融合：
                    // 脸颊/额头平展区 (FaceAO=1) 走 SDF，耳廓/下颌/颈部立体区 (FaceAO=0) 走 3D 法线
                    #if defined(_USE_SDF)
                        float angle = CalculateFaceLightAngle(L);
                        float2 mirroredUV = float2((angle > 0.0) ? (1.0 - i.uv0.x) : i.uv0.x, i.uv0.y);
                        float absAngle = abs(angle);

                        float4 mirroredsdfmap = SAMPLE_TEXTURE2D(_SDFMap, sampler_SDFMap, mirroredUV);
                        float4 originalsdfmap = SAMPLE_TEXTURE2D(_SDFMap, sampler_SDFMap, i.uv0);

                        float sdfR = mirroredsdfmap.r;
                        bool isValidG = (mirroredsdfmap.g > 0.4 && mirroredsdfmap.g < 0.95);
                        float sdfG = isValidG ? mirroredsdfmap.g : originalsdfmap.g;
                        faceAO = mirroredsdfmap.a;

                        // G 通道控制局部软硬（鼻梁等硬边走 _SDFWidth，脸颊软边向 0.25 过渡）
                        float softnessFactor = saturate((sdfG - 0.5) * 2.5);
                        float width = max(1e-4, lerp(_SDFWidth, 0.25, softnessFactor) * _SDFWidthScale);
                        float sdfLit = saturate((sdfR - absAngle) / width);
                        float xSDF = sdfLit * 2.0 - 1.0;

                        x = lerp(xNormal, xSDF, faceAO);
                    #endif

                    // ③ 可选接收实时投影：被遮挡时把 x 压向不超过 _CastShadowLimit
                    x = ApplyCastShadowToCoord(x, light.shadowAttenuation, _CastShadowStrength, _CastShadowLimit);

                    // ④ 用 6 条 (Center, Width) 分界顺序混合 7 段色阶颜色（调用 ZZZ_User.hlsl）
                    float3 palette = EvaluateMultiBandPalette(
                        x,
                        _DeepColor.rgb, _ShadowColor.rgb, _SoftShadowColor.rgb,
                        _MidColor.rgb, _WarmColor.rgb, _LightColor.rgb, _BrightColor.rgb,
                        _Center1, _Width1,
                        _Center2, _Width2,
                        _Center3, _Width3,
                        _Center4, _Width4,
                        _Center5, _Width5,
                        _Center6, _Width6
                    );

                    // ⑤ 颜色合成：主光乘 7 段配色 + SH 环境光，再乘底色
                    half3 direct  = palette * light.color * light.distanceAttenuation * _DirectStrength;
                    half3 ambient = max(0.0, SampleSH(N)) * _AmbientStrength;
                    half4 color   = half4(basecolor.rgb * (direct + ambient), basecolor.a);

                    // 采样顶点色
                    half3 vertexcolor = i.color.rgb;

                    // ===== 调试可视化（_DebugMode 下拉，0=正常渲染）=====
                    if (_DebugMode == 1) // 顶点色
                        return half4(vertexcolor, 1.0);
                    if (_DebugMode == 2) // 观察空间法线
                    {
                        half3 normalVS = TransformWorldToViewDir(i.normalWS, true);
                        return half4(abs(normalVS), 1);
                    }
                    if (_DebugMode == 3) // uv1 中烘焙的平滑法线
                        return half4(i.uv1, 1);
                    if (_DebugMode == 4) // Perlin 噪声预览
                    {
                        float2 nuv = i.positionOS.xy * _NoiseTillOffset.xy + _NoiseTillOffset.zw + _Time.y * _OutlineNoiseAnimSpeed;
                        float n = applyNoiseContrast(perlinNoise2D(nuv), _NoiseContrast) * 0.5 + 0.5;
                        return half4(n, n, n, 1);
                    }
                    if (_DebugMode == 5) // 7 段色阶配色预览（对应 MultiBandNormalShadow 的 Palette）
                        return half4(palette, 1.0);
                    if (_DebugMode == 6) // 色阶坐标 x 灰度预览（-1~1 映射到 0~1）
                    {
                        half gray = saturate(x * 0.5 + 0.5);
                        return half4(gray, gray, gray, 1.0);
                    }
                    if (_DebugMode == 7) // FaceAO 融合遮罩预览（白=SDF，黑=3D 法线）
                        return half4(faceAO, faceAO, faceAO, 1.0);

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

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
                #pragma vertex ShadowPassVertex
                #pragma fragment ShadowPassFragment
                #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

                float3 _LightDirection;
                float3 _LightPosition;

                struct ShadowAttributes
                {
                    float4 positionOS : POSITION;
                    float3 normalOS   : NORMAL;
                };

                struct ShadowVaryings
                {
                    float4 positionCS : SV_POSITION;
                };

                ShadowVaryings ShadowPassVertex(ShadowAttributes input)
                {
                    ShadowVaryings output;
                    float3 worldPos    = TransformObjectToWorld(input.positionOS.xyz);
                    float3 worldNormal = TransformObjectToWorldNormal(input.normalOS);
                    #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
                        float3 lightDir = SafeNormalize(_LightPosition - worldPos);
                    #else
                        float3 lightDir = _LightDirection;
                    #endif
                    output.positionCS = TransformWorldToHClip(ApplyShadowBias(worldPos, worldNormal, lightDir));
                    #if UNITY_REVERSED_Z
                        output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                    #else
                        output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                    #endif
                    return output;
                }

                half4 ShadowPassFragment(ShadowVaryings input) : SV_TARGET
                {
                    return 0;
                }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
                #pragma vertex DepthOnlyVertex
                #pragma fragment DepthOnlyFragment

                struct DepthAttributes
                {
                    float4 positionOS : POSITION;
                };

                struct DepthVaryings
                {
                    float4 positionCS : SV_POSITION;
                };

                DepthVaryings DepthOnlyVertex(DepthAttributes input)
                {
                    DepthVaryings output;
                    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                    return output;
                }

                half DepthOnlyFragment(DepthVaryings input) : SV_TARGET
                {
                    return input.positionCS.z;
                }
            ENDHLSL
        }
    }
}
