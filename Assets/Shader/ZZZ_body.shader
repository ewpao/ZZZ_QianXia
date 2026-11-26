Shader "ZZZ/ZZZ_body"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map" ,2D) = "white" {} //基础贴图采样
        _MixColor("Mix Color", Color) = (1,1,1,1)
        // Optional surface controls. Existing opaque materials retain their original defaults.
        [HideInInspector] _SrcBlend("Source Blend", Float) = 1
        [HideInInspector] _DstBlend("Destination Blend", Float) = 0
        [HideInInspector] _ZWrite("Depth Write", Float) = 1
        [HideInInspector] _Opacity("Opacity", Range(0,1)) = 1
        [HideInInspector] _AlphaClip("Alpha Clip", Float) = 0
        [HideInInspector] _Cutoff("Alpha Cutoff", Range(0,1)) = 0.33
        [Space(30)]

        [Header(MatCap)]
        [NoScaleOffset] _MatCapMap("MatCap Map", 2D) = "black" {} //MatCap 贴图（用视图空间法线采样的球面光照图）
        _MatCapStrength("MatCap Strength", Range(0, 2)) = 1.0 //MatCap 叠加强度
        [ToggleUI] _UseMatCapMask("Use MatCap Mask(A map B Channel)", Float) = 1
        [NoScaleOffset] _MatCapMaskTex("MatCap Mask Tex", 2D) = "white"{}

        [Space(30)]

        [Header(Material Regions)]
        [Toggle(_USE_MATERIAL_REGIONS)] _UseMaterialRegions("Enable Material Regions", Float) = 0
        [NoScaleOffset] _RampID("Region ID (Red Skin - Blue Cloth)", 2D) = "black" {}
        [Space(30)]

        [Header(AO)]
        [Toggle(_USE_AO_MAP)] _UseAOMap("Use AO Map" , Range(0,1)) = 1
        _AOMap("AO Map" ,2D) = "white" {} //AO贴图采样
        _AOIntensity("AO Intensity", Range(0,1)) = 1.0 //AO强度
        [Space(30)]

        [Header(Specular)]
        _SpecularMap("Specular Map" ,2D) = "black"{} //高光贴图采样
        _SpecularPower("Specular Power", Range(0,1)) = 0.25 //高光强度
        _SpecularRegion("Specular Region", Range(0,1)) = 0.3 //高光范围
        _SpecularSoftness("Specular Softness", Range(0.001,1)) = 0.1 //高光边界柔和度（0.001≈硬切，越大边缘越虚）
        [Space(30)]

        [Header(Normal)]
        [Toggle(_USE_NORMAL_MAP)] _UseNormalMap("Use Normal Map", Float) = 1
        _NormalMap("Normal Map (RG Normal, B Bias)", 2D) = "gray"{}
        _NormalMapIntensity("RG Normal Strength", Range(0, 2)) = 1
        _BlueBiasStrength("B Bias Strength", Range(0, 3)) = 2.0
        [Space(30)]

        [Header(Band Colors)]
        _DeepColor("1 Deep Shadow", Color) = (0.20, 0.25, 0.43, 1)
        _ShadowColor("2 Shadow", Color) = (0.42, 0.46, 0.65, 1)
        _SoftShadowColor("3 Soft Shadow", Color) = (0.64, 0.65, 0.79, 1)
        _MidColor("4 Midtone", Color) = (0.83, 0.83, 0.92, 1)
        _WarmColor("5 Warm Transition", Color) = (1.0, 0.78, 0.63, 1)
        _LightColor("6 Light", Color) = (0.98, 0.93, 0.86, 1)
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
        [Space(30)]

        [Header(Cloth Band Colors)]
        _ClothDeepColor("Cloth 1 Deep Shadow", Color) = (0.8235294, 0.8235294, 0.8235294, 1)
        _ClothShadowColor("Cloth 2 Shadow", Color) = (0.8207547, 0.8207547, 0.8207547, 1)
        _ClothSoftShadowColor("Cloth 3 Soft Shadow", Color) = (0.8509804, 0.8509804, 0.8509804, 1)
        _ClothMidColor("Cloth 4 Midtone", Color) = (0.8490566, 0.8490566, 0.8490566, 1)
        _ClothWarmColor("Cloth 5 Warm Transition", Color) = (1, 0.97990155, 0.9669811, 1)
        _ClothLightColor("Cloth 6 Light", Color) = (1, 1, 1, 1)
        _ClothBrightColor("Cloth 7 Bright Light", Color) = (1, 1, 1, 1)
        [Space(10)]

        [Header(Cloth Transition Centers and Full Widths)]
        _ClothCenter1("Cloth 1 to 2 Center", Range(-1, 1)) = -0.869
        _ClothWidth1("Cloth 1 to 2 Width", Range(0, 1)) = 0
        _ClothCenter2("Cloth 2 to 3 Center", Range(-1, 1)) = -0.479
        _ClothWidth2("Cloth 2 to 3 Width", Range(0, 1)) = 0.078
        _ClothCenter3("Cloth 3 to 4 Center", Range(-1, 1)) = -0.04
        _ClothWidth3("Cloth 3 to 4 Width", Range(0, 1)) = 0.574
        _ClothCenter4("Cloth 4 to 5 Center", Range(-1, 1)) = 0.283
        _ClothWidth4("Cloth 4 to 5 Width", Range(0, 1)) = 0.062
        _ClothCenter5("Cloth 5 to 6 Center", Range(-1, 1)) = 0.346
        _ClothWidth5("Cloth 5 to 6 Width", Range(0, 1)) = 0.122
        _ClothCenter6("Cloth 6 to 7 Center", Range(-1, 1)) = 0.76
        _ClothWidth6("Cloth 6 to 7 Width", Range(0, 1)) = 0.216
        [Space(10)]

        [Header(Cloth Lighting)]
        _ClothDirectStrength("Cloth Main Light Strength", Range(0, 2)) = 1.05
        _ClothAmbientStrength("Cloth Ambient Strength", Range(0, 1)) = 0.15
        _ClothCastShadowStrength("Cloth Cast Shadow Influence", Range(0, 1)) = 0
        _ClothCastShadowLimit("Cloth Occluded Lighting Coordinate", Range(-1, 1)) = -0.36
        [Space(30)]

        [Header(Rim)]
        _RimIntensity("Rim Intensity" ,Range(0,1)) = 1
        _RimColor ("Rim Color", Color) = (1, 1, 1, 1)
        _RimWidth ("Rim Width (View Space)", Range(0.001, 0.1)) = 0.01
        _DepthThreshold ("Depth Threshold", Range(0.0001, 0.1)) = 0.01
        _FresnelMask ("Fresnel Mask", Range(0.0, 1.0)) = 0.5
        [Space(30)]

        [Header(Colour Modulation)]
        _ColourModulation("Colour Modulation" ,Color) = (1,1,1,1)//调色
        _Saturation("Saturation", Range(0,2)) = 1.0//饱和度调节
        [Space(30)]

        [Header(Outline)]
        _OutlineWidth("Outline Width", Range(0, 10)) = 2.0 //描边宽度（像素级）
        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1) //描边颜色
        _OutlineMaxDistance("Outline Max Distance", Range(0.1, 100)) = 5 //衰减起点(米)：该距离内保持满粗细，超出按距离衰减变细
        _OutlineZOffset("Outline Z Offset", Range(-1, 1)) = 0.0 //描边深度偏移：正值沉后(URP Reverse-Z)，负值前移
        [Space(30)]

        [Header(Outline Noise)]
        [Toggle(_USE_OUTLINE_NOISE)] _UseOutlineNoise("Use Outline Noise", Range(0,1)) = 1 //描边噪声总开关（关闭后宽度均匀，且剔除噪声计算）
        _NoiseTillOffset("Noise Tiling(XY) Offset(ZW)", Vector) = (10, 10, 0, 0) //噪声平铺(xy,物体空间/米)/偏移(zw)
        _OutlineNoiseStrength("Outline Noise Strength", Range(0, 1)) = 0.3 //噪声对粗细的影响强度（0=均匀，1=±100%）
        _OutlineNoiseAnimSpeed("Outline Noise Anim Speed", Range(0, 5)) = 0 //噪声流动速度（0=静态，沿对角线滚动采样坐标）
        _NoiseContrast("Noise Contrast", Range(0.5, 4)) = 1.0 //噪声对比度（>1 拉开黑白差距，<1 变柔和）
        [Space(30)]

        [Header(Stencil)]
        _StencilRef("Stencil Ref (32=Bangs)", Range(0,255)) = 0
        _StencilWhiteMask("Stencil White Mask (32=Bangs)", Range(0,255)) = 32

        [Header(Debug)]
        [Enum(ZZZ.BodyDebugMode)] _DebugMode("Debug Mode", Float) = 0 //调试可视化下拉：0=正常渲染，1=顶点色，2=观察空间法线，3=平滑法线(uv1)，4=柏林噪声预览，5=顶点色Alpha，6=基础贴图Alpha，7=7段色阶配色，8=色阶坐标x灰度
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
        }

        HLSLINCLUDE//公共代码块

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl" // 深度纹理（声明 _CameraDepthTexture）
            #include "ZZZ_User.hlsl"

            #pragma shader_feature_local _USE_OUTLINE_NOISE

            // 纹理声明
            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_AOMap);              SAMPLER(sampler_AOMap);
            TEXTURE2D(_SpecularMap);        SAMPLER(sampler_SpecularMap);
            TEXTURE2D(_NormalMap);          SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MatCapMap);          SAMPLER(sampler_MatCapMap);
            TEXTURE2D(_MatCapMaskTex);      SAMPLER(sampler_MatCapMaskTex);

            // 材质属性常量缓冲区
            CBUFFER_START(UnityPerMaterial)
                // 基础纹理
                float4 _BaseMap_ST;
                float4 _MixColor;
                half _Opacity;
                half _AlphaClip;
                half _Cutoff;

                // AO
                float4 _AOMap_ST;
                half _AOIntensity;
                half _UseAOMap;

                // 高光项
                float4 _SpecularMap_ST;
                half _SpecularPower;
                half _SpecularRegion;
                half _SpecularSoftness;

                // NormalMap 与 B 通道明暗偏置
                float4 _NormalMap_ST;
                half _UseNormalMap;
                float _NormalMapIntensity;
                float _BlueBiasStrength;

                // MatCap
                half _MatCapStrength;
                half _UseMatCapMask;

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

                // 红色皮肤沿用上面的参数，衣服额外使用一套色阶和光照参数。
                float _UseMaterialRegions;
                float4 _ClothDeepColor;
                float4 _ClothShadowColor;
                float4 _ClothSoftShadowColor;
                float4 _ClothMidColor;
                float4 _ClothWarmColor;
                float4 _ClothLightColor;
                float4 _ClothBrightColor;

                float _ClothCenter1, _ClothCenter2, _ClothCenter3, _ClothCenter4, _ClothCenter5, _ClothCenter6;
                float _ClothWidth1, _ClothWidth2, _ClothWidth3, _ClothWidth4, _ClothWidth5, _ClothWidth6;

                float _ClothDirectStrength;
                float _ClothAmbientStrength;
                float _ClothCastShadowStrength;
                float _ClothCastShadowLimit;

                // Rim边缘光
                half _RimIntensity;
                half4 _RimColor;
                float _RimWidth;
                float _DepthThreshold;
                float _FresnelMask;

                // 调色
                float4 _ColourModulation;
                half _Saturation;

                // 描边
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

                // 调试
                half _DebugMode;
            CBUFFER_END

            float4 TransformHClipToViewPortPos(float4 positionCS)
            {
                float4 o = positionCS * 0.5f;
                o.xy = float2(o.x, o.y * _ProjectionParams.x) + o.w;
                o.zw = positionCS.zw;
                return o / o.w;
            }

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

            struct Attributes
            {
                float4 positionOS : POSITION;   // 模型空间坐标
                float2 uv0        : TEXCOORD0;  // 主纹理 UV
                float3 uv1        : TEXCOORD1;  // 平滑法线
                float3 normalOS   : NORMAL;     // 模型空间法线
                float4 tangentOS  : TANGENT;    // 模型空间切线
                float4 color      : COLOR;      // 顶点颜色
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION; // 裁剪空间坐标
                float2 uv0          : TEXCOORD0;   // 主纹理 UV
                float3 normalWS     : TEXCOORD1;   // 世界空间法线
                float4 tangentWS    : TEXCOORD2;   // 世界空间切线 (xyz) + 手性符号 (w)
                float3 normalVS     : TEXCOORD3;   // 观察空间法线
                float3 positionVS   : TEXCOORD4;   // 观察空间坐标
                float4 normalAndRampUV : TEXCOORD5; // xy: 法线贴图 UV，zw: ID 图的原始 UV0
                float3 positionWS   : TEXCOORD6;   // 世界空间坐标
                float3 positionOS   : TEXCOORD7;   // 模型空间坐标（噪声调试预览用，与描边 Pass 同源）
                float3 uv1          : TEXCOORD8;   // 平滑法线
                float4 color        : COLOR;       // 顶点颜色
            };

        ENDHLSL

        pass
        {
            Name "UniversalForward"//给pass通道命名

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Cull off //背面剔除关闭
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            Stencil
            {
                Ref [_StencilRef]
                ReadMask 255
                WriteMask [_StencilWhiteMask]
                Comp Always
                Pass Replace
            }

            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag
                #pragma shader_feature_local _USE_NORMAL_MAP
                #pragma shader_feature_local_fragment _USE_MATERIAL_REGIONS
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
                #pragma multi_compile_fragment _ _SHADOWS_SOFT

                TEXTURE2D(_RampID); SAMPLER(sampler_RampID);

                Varyings vert(Attributes i)
                {
                    Varyings o;

                    // 空间转换函数
                    VertexPositionInputs posInputs = GetVertexPositionInputs(i.positionOS.xyz);
                    VertexNormalInputs tbn = GetVertexNormalInputs(i.normalOS, i.tangentOS);

                    // 空间转换
                    o.positionCS = posInputs.positionCS;
                    o.positionVS = posInputs.positionVS;
                    o.positionWS = posInputs.positionWS;
                    o.positionOS = i.positionOS.xyz;

                    // UV 传递（应用 Tiling/Offset）
                    o.uv0 = TRANSFORM_TEX(i.uv0, _BaseMap);
                    o.normalAndRampUV = float4(TRANSFORM_TEX(i.uv0, _NormalMap), i.uv0);
                    o.uv1 = i.uv1;

                    // 法线与切线（tangentWS.w 携带手性符号，匹配 DecodePackedNormalWS）
                    o.normalWS = tbn.normalWS;
                    o.tangentWS = float4(tbn.tangentWS, i.tangentOS.w * GetOddNegativeScale());
                    o.normalVS = TransformWorldToViewDir(tbn.normalWS, true);

                    // 顶点颜色
                    o.color = i.color;

                    return o;
                }

                half4 frag(Varyings i, FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC) : SV_TARGET
                {
                    // ① 采样 URP 主光（含实时投影，兼容 Cascade / Screen Space Shadows）
                    VertexPositionInputs posInputs = (VertexPositionInputs)0;
                    posInputs.positionWS = i.positionWS;
                    posInputs.positionCS = TransformWorldToHClip(i.positionWS);
                    Light light = GetMainLight(GetShadowCoord(posInputs));
                    float3 L = normalize(light.direction);

                    // 采样顶点色与基础贴图
                    half4 vertexcolor = i.color;
                    half4 basecolor   = SAMPLE_TEXTURE2D(_BaseMap,     sampler_BaseMap,     i.uv0);
                    basecolor *= _MixColor;
                    basecolor.a *= _Opacity;
                    if (_AlphaClip > 0.5) clip(basecolor.a - _Cutoff);
                    half4 specularMap = SAMPLE_TEXTURE2D(_SpecularMap, sampler_SpecularMap, i.uv0);

                    // ② 解码 RG 法线 + B 明暗偏置（调用 ZZZ_User.hlsl，支持 Cull Off 双面翻转）
                    float faceSign = IS_FRONT_VFACE(cullFace, 1.0, -1.0);
                    float3 geoN = SafeNormalize(i.normalWS) * faceSign;
                    float3 packed = float3(0.5, 0.5, 0.5);
                    float3 N = geoN;
                    #if defined(_USE_NORMAL_MAP)
                        if (_NormalMapIntensity > 0.0 || _BlueBiasStrength > 0.0)
                            packed = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.normalAndRampUV.xy).rgb;
                        N = DecodePackedNormalWS(i.normalWS, i.tangentWS, packed.rg, _NormalMapIntensity, faceSign);
                    #endif

                    // ③ 计算 1 维受光色阶坐标 x = N·L + (B*2 - 1) * _BlueBiasStrength
                    float x = dot(N, L) + (packed.b * 2.0 - 1.0) * _BlueBiasStrength;

                    float clothMask = 0.0;
                    #if defined(_USE_MATERIAL_REGIONS)
                        // 线性 ID 贴图的红蓝混色是边缘覆盖率。滤波只在边界混合两套参数。
                        half3 regionID = SAMPLE_TEXTURE2D(_RampID, sampler_RampID, i.normalAndRampUV.zw).rgb;
                        half skinCoverage = min(regionID.r - 2.0h * regionID.g, 1.0h - regionID.b);
                        clothMask = 1.0h - smoothstep(0.15h, 0.85h, skinCoverage);
                    #endif

                    // ④ 可选接收实时投影：按当前分区的光照参数限制 x。
                    float castShadowStrength = lerp(_CastShadowStrength, _ClothCastShadowStrength, clothMask);
                    float castShadowLimit = lerp(_CastShadowLimit, _ClothCastShadowLimit, clothMask);
                    x = ApplyCastShadowToCoord(x, light.shadowAttenuation, castShadowStrength, castShadowLimit);

                    // ⑤ 用 6 条 (Center, Width) 分界顺序混合 7 段色阶颜色（调用 ZZZ_User.hlsl）
                    float3 palette = EvaluateMultiBandPalette(
                        x,
                        lerp(_DeepColor.rgb, _ClothDeepColor.rgb, clothMask),
                        lerp(_ShadowColor.rgb, _ClothShadowColor.rgb, clothMask),
                        lerp(_SoftShadowColor.rgb, _ClothSoftShadowColor.rgb, clothMask),
                        lerp(_MidColor.rgb, _ClothMidColor.rgb, clothMask),
                        lerp(_WarmColor.rgb, _ClothWarmColor.rgb, clothMask),
                        lerp(_LightColor.rgb, _ClothLightColor.rgb, clothMask),
                        lerp(_BrightColor.rgb, _ClothBrightColor.rgb, clothMask),
                        lerp(_Center1, _ClothCenter1, clothMask), lerp(_Width1, _ClothWidth1, clothMask),
                        lerp(_Center2, _ClothCenter2, clothMask), lerp(_Width2, _ClothWidth2, clothMask),
                        lerp(_Center3, _ClothCenter3, clothMask), lerp(_Width3, _ClothWidth3, clothMask),
                        lerp(_Center4, _ClothCenter4, clothMask), lerp(_Width4, _ClothWidth4, clothMask),
                        lerp(_Center5, _ClothCenter5, clothMask), lerp(_Width5, _ClothWidth5, clothMask),
                        lerp(_Center6, _ClothCenter6, clothMask), lerp(_Width6, _ClothWidth6, clothMask)
                    );

                    // 可选 AO 仅调制环境光
                    half ao = SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, i.uv0).r;
                    ao = lerp(1.0, ao, _AOIntensity * _UseAOMap);

                    // Rim边缘光
                    float3 positionVS = i.positionVS;
                    float3 normalVS = normalize(i.normalVS);

                    // 2. 仅在 XY 平面偏移，保持 Z 不变
                    float3 samplePositionVS = float3(positionVS.xy + normalVS.xy * _RimWidth, positionVS.z);

                    // 3. 转到裁剪空间 (注意这里用 P 矩阵乘以 VS 坐标)
                    float4 samplePositionCS = mul(UNITY_MATRIX_P, float4(samplePositionVS, 1.0));

                    // 4. 转为视口坐标 (0~1 UV)
                    float4 samplePositionVP = TransformHClipToViewPortPos(samplePositionCS);

                    // 5. 采样偏移后的深度 (兼容VR写法)
                    float offsetDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, samplePositionVP.xy).r;
                    float linearEyeOffsetDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);

                    // 6. 获取自身深度（SV_POSITION 在 fragment 中已是设备深度 0~1，直接用，不除 w）
                    float selfRawDepth = i.positionCS.z;
                    float linearEyeDepth = LinearEyeDepth(selfRawDepth, _ZBufferParams);

                    // 7. 屏幕空间深度差值计算
                    float depthDiff = linearEyeOffsetDepth - linearEyeDepth;
                    float rimIntensity = step(_DepthThreshold, depthDiff);

                    // 8. 菲涅尔遮罩：剔除内部杂乱的边缘光
                    float3 viewDirectionWS = SafeNormalize(GetCameraPositionWS() - i.positionWS);
                    float rimRatio = 1.0 - saturate(dot(viewDirectionWS, geoN));
                    // 调整菲涅尔柔和度
                    rimRatio = pow(rimRatio, exp2(lerp(4.0, 0.0, _FresnelMask)));
                    // 应用遮罩
                    rimIntensity = lerp(0.0, rimIntensity, rimRatio);

                    // Matcap
                    half2 matcapUV = saturate(mul((float3x3)UNITY_MATRIX_V, N)* 0.5 + 0.5);
                    half4 matcapcolor = SAMPLE_TEXTURE2D(_MatCapMap, sampler_MatCapMap, matcapUV);
                    half3 matcapmask = (_UseMatCapMask > 0.5) ? SAMPLE_TEXTURE2D(_MatCapMaskTex,sampler_MatCapMaskTex, i.uv0).b : 1.0;
                    half matcapalpha = saturate(matcapcolor.a* matcapmask* _MatCapStrength);
                    half3 albedo = lerp(basecolor,matcapcolor,matcapalpha);


                    // ⑥ 颜色合成：主光乘 7 段配色 + SH 环境光，再乘底色
                    float directStrength = lerp(_DirectStrength, _ClothDirectStrength, clothMask);
                    float ambientStrength = lerp(_AmbientStrength, _ClothAmbientStrength, clothMask);
                    half3 direct  = palette * light.color * light.distanceAttenuation * directStrength;
                    half3 ambient = max(0.0, SampleSH(N)) * ambientStrength * ao;
                    half3 color   = albedo.rgb * (direct + ambient);

                    // 叠加边缘光
                    color.rgb += _RimColor.rgb * rimIntensity * _RimIntensity;

                    // 高光（smoothstep 软化边界，替代硬 if；_SpecularSoftness 越大边缘越虚）
                    half specThreshold = 1.0 - _SpecularRegion;
                    half specWeight = smoothstep(specThreshold - _SpecularSoftness, specThreshold + _SpecularSoftness, x);
                    half3 specInner = lerp(color.rgb, color.rgb + specularMap.a, saturate(x));
                    color.rgb = lerp(color.rgb, specInner, specWeight * _SpecularPower);

                    // ===== 调试可视化（_DebugMode 下拉，0=正常渲染）=====
                    if (_DebugMode == 1) // 顶点色
                        return half4(vertexcolor.rgb, 1.0);
                    if (_DebugMode == 2) // 观察空间法线
                        return half4(abs(normalVS), 1);
                    if (_DebugMode == 3) // uv1 中烘焙的平滑法线
                        return half4(i.uv1, 1);
                    if (_DebugMode == 4) // Perlin 噪声预览
                    {
                        float2 nuv = i.positionOS.xy * _NoiseTillOffset.xy + _NoiseTillOffset.zw + _Time.y * _OutlineNoiseAnimSpeed;
                        float n = applyNoiseContrast(perlinNoise2D(nuv), _NoiseContrast) * 0.5 + 0.5;
                        return half4(n, n, n, 1);
                    }
                    if (_DebugMode == 5) // 顶点色 Alpha
                        return half4(vertexcolor.aaa, 1.0);
                    if (_DebugMode == 6) // 基础贴图 Alpha
                        return half4(basecolor.aaa, 1.0);
                    if (_DebugMode == 7) // 7 段色阶配色预览（对应 MultiBandNormalShadow 的 Palette）
                        return half4(palette, 1.0);
                    if (_DebugMode == 8) // 色阶坐标 x 灰度预览（-1~1 映射到 0~1）
                    {
                        half gray = saturate(x * 0.5 + 0.5);
                        return half4(gray, gray, gray, 1.0);
                    }

                    return half4(color, basecolor.a);
                }

            ENDHLSL
        }

        pass //描边
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

                struct OutlineVaryings
                {
                    float4 positionCS : SV_POSITION;
                };

                OutlineVaryings vertOutline(Attributes v)
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
                    float4 vertexcolor = v.color;
                    float outlineWidth = _OutlineWidth * noiseFactor * vertexcolor.r;

                    // 3. 沿视图空间法线膨胀（背面法）：
                    //    - 乘 viewDepth 抵消透视投影的 1/z 缩放，使屏幕空间描边宽度近似一致（不受距离影响）
                    //    - clampW 距离衰减：viewDepth < _OutlineMaxDistance 保持满粗细，超出按比例变细
                    //    - 0.001 是 _OutlineWidth(0~10) 到视图空间单位的缩放系数

                    // View Direction 投影法
                    float3 viewDirVS = normalize(-positionVS);
                    float3 normalOffset = normalize(normalVS - dot(normalVS, viewDirVS)*viewDirVS);
                    float2 extent = normalOffset.xy;

                    float viewDepth = -positionVS.z;
                    float clampW = saturate(_OutlineMaxDistance / viewDepth);
                    positionVS.xy += extent * outlineWidth * 0.001 * viewDepth * clampW;

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

        Pass //ShadowCaster
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off

            HLSLPROGRAM
                #pragma vertex ShadowPassVertex
                #pragma fragment ShadowPassFragment
                #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

                float3 _LightDirection;
                float3 _LightPosition;

                struct ShadowVaryings
                {
                    float4 positionCS : SV_POSITION;
                    float2 uv0        : TEXCOORD0;
                };

                ShadowVaryings ShadowPassVertex(Attributes input)
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
                    output.uv0 = TRANSFORM_TEX(input.uv0, _BaseMap);
                    return output;
                }

                half4 ShadowPassFragment(ShadowVaryings input) : SV_TARGET
                {
                    if (_AlphaClip > 0.5)
                    {
                        half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv0).a * _MixColor.a * _Opacity;
                        clip(alpha - _Cutoff);
                    }
                    return 0;
                }
            ENDHLSL
        }

        Pass //DepthOnly
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull Off

            HLSLPROGRAM
                #pragma vertex DepthOnlyVertex
                #pragma fragment DepthOnlyFragment

                struct DepthVaryings
                {
                    float4 positionCS : SV_POSITION;
                    float2 uv0        : TEXCOORD0;
                };

                DepthVaryings DepthOnlyVertex(Attributes input)
                {
                    DepthVaryings output;
                    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                    output.uv0 = TRANSFORM_TEX(input.uv0, _BaseMap);
                    return output;
                }

                half DepthOnlyFragment(DepthVaryings input) : SV_TARGET
                {
                    if (_AlphaClip > 0.5)
                    {
                        half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv0).a * _MixColor.a * _Opacity;
                        clip(alpha - _Cutoff);
                    }
                    return input.positionCS.z;
                }
            ENDHLSL
        }
    }
}
