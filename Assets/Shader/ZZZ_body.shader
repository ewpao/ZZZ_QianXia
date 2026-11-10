Shader "ZZZ/ZZZ_body"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map" ,2D) = "white" {} //基础贴图采样
        // Optional surface controls. Existing opaque materials retain their original defaults.
        [HideInInspector] _SrcBlend("Source Blend", Float) = 1
        [HideInInspector] _DstBlend("Destination Blend", Float) = 0
        [HideInInspector] _ZWrite("Depth Write", Float) = 1
        [HideInInspector] _Opacity("Opacity", Range(0,1)) = 1
        [HideInInspector] _AlphaClip("Alpha Clip", Float) = 0
        [HideInInspector] _Cutoff("Alpha Cutoff", Range(0,1)) = 0.33
        _LightContrast("Light Contrast", Range(0.01,3)) = 1
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
        [Normal] _NormalMap("Normal Map", 2D) = "bump"{}
        _NormalMapIntensity("Normal Map Intensity", Range(0,1)) = 1 
        [Space(30)]

        [Header(Ramp)]
        [Toggle(_USE_RAMPMAP)] _UseRampMap("Use RampMap" , Range(0,1)) = 1
        _RampMap("Ramp Map" ,2D) = "black"{}
        _RampID("RampID" , 2D) = "white"{}
        _ShadowThreshold("Shadow Threshold",Range(0,1)) = 0.3 //阴影阈值（边缘位置）
        _ShadowSoftness("Shadow Softness" ,Range(0.001,1)) = 0.001 //阴影边界柔和度（调节阴影软硬）
        _ShadowIntensity("Shadow Intensity" , Range(0,1)) = 1 //阴影强度
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

        [Header(Debug)]
        [Enum(Off,0,Vertex Color,1,View Normal,2,Smooth Normal,3,Noise,4)] _DebugMode("Debug Mode", Float) = 0 //调试可视化下拉：0=正常渲染，1=顶点色，2=观察空间法线，3=平滑法线(uv1)，4=柏林噪声预览
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

            #pragma shader_feature_local _USE_RAMPMAP
            #pragma shader_feature_local _USE_RIM_LIGHT
            #pragma shader_feature_local _USE_OUTLINE_NOISE

            // 纹理声明
            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_AOMap);              SAMPLER(sampler_AOMap);
            TEXTURE2D(_SpecularMap);        SAMPLER(sampler_SpecularMap);
            TEXTURE2D(_NormalMap);          SAMPLER(sampler_NormalMap);
            TEXTURE2D(_RampMap);            SAMPLER(sampler_RampMap);
            TEXTURE2D(_RampID);             SAMPLER(sampler_RampID);

            // 材质属性常量缓冲区
            CBUFFER_START(UnityPerMaterial)
                // 基础纹理
                float4 _BaseMap_ST;
                half _Opacity;
                half _AlphaClip;
                half _Cutoff;
                half _LightContrast;

                // AO
                float4 _AOMap_ST;
                half _AOIntensity;
                half _UseAOMap;

                // 高光项
                float4 _SpecularMap_ST;
                half _SpecularPower;
                half _SpecularRegion;
                half _SpecularSoftness;

                // NormalMap
                float4 _NormalMap_ST;
                half _UseNormalMap;
                half _NormalMapIntensity;

                // Ramp色阶阴影
                half _ShadowThreshold;
                half _ShadowSoftness;
                half _ShadowIntensity;

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
                float4 _NoiseTillOffset;
                half _OutlineNoiseStrength;
                half _OutlineNoiseAnimSpeed;
                half _NoiseContrast;

                // 调试
                half _DebugMode;
            CBUFFER_END

            half GetrampV(half3 rampIDtu)
            {
                half v = 0.1;
                v = lerp(v, 0.9, step(0.6, rampIDtu.r));
                v = lerp(v, 0.5, step(0.6, rampIDtu.g));
                v = lerp(v, 0.3, step(0.6, rampIDtu.b));
                return v;
            }

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
                float3 tangentWS     : TEXCOORD2;   // 世界空间切线
                float3 normalVS     : TEXCOORD3;   // 观察空间法线
                float3 positionVS   : TEXCOORD4;   // 观察空间坐标
                float3 positionWS   : TEXCOORD6;   // 世界空间坐标
                float3 positionOS   : TEXCOORD7;   // 模型空间坐标（噪声调试预览用，与描边 Pass 同源）
                float3 uv1          : TEXCOORD8;   // 平滑法线
                float3 bitangentWS   : TEXCOORD9;
                float2 normalUV      : TEXCOORD5;
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

            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag
                #pragma shader_feature_local _USE_NORMAL_MAP

                Varyings vert(Attributes i)
                {
                    Varyings o;

                    // 空间转换函数
                    VertexPositionInputs posInputs = GetVertexPositionInputs(i.positionOS.xyz);
                    VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS);//转换法线空间
                    VertexNormalInputs tbn = GetVertexNormalInputs(i.normalOS, i.tangentOS);//转换切线空间

                    // 空间转换
                    o.positionCS = posInputs.positionCS;
                    o.positionVS = posInputs.positionVS;
                    o.positionWS = posInputs.positionWS;
                    o.positionOS = i.positionOS.xyz;

                    // UV 传递（应用 Tiling/Offset）
                    o.uv0 = TRANSFORM_TEX(i.uv0, _BaseMap);
                    o.normalUV = TRANSFORM_TEX(i.uv0, _NormalMap);
                    o.uv1 = i.uv1;

                    // normal
                    o.normalWS = normalInput.normalWS;//将世界坐标法线传递给输出变量
                    o.normalVS = TransformWorldToViewDir(normalInput.normalWS, true);

                    //TBN
                    o.normalWS = tbn.normalWS;
                    o.tangentWS = tbn.tangentWS;
                    o.bitangentWS = tbn.bitangentWS;

                    // 顶点颜色
                    o.color = i.color;

                    return o;
                }

                half4 frag(Varyings i) : SV_TARGET
                {
                    // 采样光源
                    Light light = GetMainLight();

                    // 采样顶点色
                    half3 vertexcolor = i.color.rgb;

                    // Lambert Diffuse
                    half4 basecolor    = SAMPLE_TEXTURE2D(_BaseMap,    sampler_BaseMap,    i.uv0);
                    basecolor.a *= _Opacity;
                    if (_AlphaClip > 0.5) clip(basecolor.a - _Cutoff);
                    half4 specularMap  = SAMPLE_TEXTURE2D(_SpecularMap, sampler_SpecularMap, i.uv0);
                    half4 normalMap    = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.normalUV);
                    // normalmap
                    half3 N = normalize(i.normalWS);
                    #if defined(_USE_NORMAL_MAP)
                        half3 normalTS = UnpackNormalScale(normalMap, _NormalMapIntensity);
                        float3x3 TBN = float3x3(i.tangentWS, i.bitangentWS, i.normalWS);
                        N = normalize(mul(normalTS, TBN));
                    #endif
                    
                    half3 L = normalize(light.direction);
                    half NdotL = saturate(dot(N, L));
                    half halfLambert = saturate(NdotL * 0.5 + 0.5); //半lambert
                    halfLambert = pow(halfLambert,_LightContrast); //增加效果

                    // AO 强度调节：1 = 无AO效果，ao值越小遮蔽越强
                    half ao = SAMPLE_TEXTURE2D(_AOMap,sampler_AOMap,i.uv0);
                    ao = lerp(1.0, ao, _AOIntensity * _UseAOMap);
                    half ambient = halfLambert * ao;
                    half shadow = (ambient+halfLambert)*0.5;
                    shadow = lerp(shadow,0,step(shadow,0.05));
                    shadow = lerp(shadow,1,step(0.95,shadow));

                    // Ramp色阶阴影
                    half rampU = smoothstep(_ShadowThreshold - _ShadowSoftness,_ShadowThreshold + _ShadowSoftness,halfLambert);
                    half3 RampID = SAMPLE_TEXTURE2D(_RampID,sampler_RampID,i.uv0);
                    half2 rampUV = half2(rampU,GetrampV(RampID));
                    half3 rampColor = SAMPLE_TEXTURE2D(_RampMap,sampler_RampMap,rampUV).rgb;

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
                    float rimRatio = 1.0 - saturate(dot(viewDirectionWS, i.normalWS));
                    // 调整菲涅尔柔和度
                    rimRatio = pow(rimRatio, exp2(lerp(4.0, 0.0, _FresnelMask)));
                    // 应用遮罩
                    rimIntensity = lerp(0.0, rimIntensity, rimRatio);


                    // 最终颜色
                    half3 duffuse = basecolor.rgb * light.color * shadow;
                    half3 color = duffuse;

                    // 叠加边缘光
                    color.rgb += _RimColor.rgb * rimIntensity * _RimIntensity;

                    #if defined(_USE_RAMPMAP)
                        // Ramp色阶阴影：用 ramp 贴图对颜色做阴影调色
                        color = lerp(color, color * rampColor, _ShadowIntensity);
                    #endif

                    // 高光（smoothstep 软化边界，替代硬 if；_SpecularSoftness 越大边缘越虚）
                    half specThreshold = 1.0 - _SpecularRegion;
                    half specWeight = smoothstep(specThreshold - _SpecularSoftness, specThreshold + _SpecularSoftness, halfLambert);
                    half3 specInner = lerp(color.rgb, color.rgb + specularMap.a, halfLambert);
                    color.rgb = lerp(color.rgb, specInner, specWeight * _SpecularPower);

                    // ===== 调试可视化（_DebugMode 下拉，0=正常渲染）=====
                    // 噪声预览与描边 Pass 同一采样坐标（模型空间 XY 投影），所见即所得
                    if (_DebugMode == 1) // 顶点色
                        return half4(vertexcolor.ggg, 1.0);
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

                    return half4(color, basecolor.a);
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
                    float outlineWidth = _OutlineWidth * noiseFactor;

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
    }
}
