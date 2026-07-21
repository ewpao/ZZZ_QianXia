Shader "ZZZ/ZZZ_body"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map" ,2D) = "white" {} //基础贴图采样

        [Header(AO)]
        [Toggle(_USE_AO_MAP)] _UseAOMap("Use AO Map" , Range(0,1)) = 1
        _AOMap("AO Map" ,2D) = "white" {} //AO贴图采样
        _AOIntensity("AO Intensity", Range(0,1)) = 1.0 //AO强度

        [Header(Specular)]
        _SpecularMap("Specular Map" ,2D) = "black"{} //高光贴图采样
        _SpecularPower("Specular Power", Range(0,1)) = 0.25 //高光强度
        _SpecularRegion("Specular Region", Range(0,1)) = 0.3 //高光范围

        [Header(Ramp)]
        [Toggle(_USE_RAMPMAP)] _UseRampMap("Use RampMap" , Range(0,1)) = 1
        _RampMap("Ramp Map" ,2D) = "black"{}
        _RampID("RampID" , 2D) = "white"{}
        _ShadowThreshold("Shadow Threshold",Range(0,1)) = 0.3 //阴影阈值（边缘位置）
        _ShadowSoftness("Shadow Softness" ,Range(0.001,1)) = 0.001 //阴影边界柔和度（调节阴影软硬）
        _ShadowIntensity("Shadow Intensity" , Range(0,1)) = 1 //阴影强度

        [Header(Rim)]
        _RimIntensity("Rim Intensity" ,Range(0,1)) = 1
        _RimColor ("Rim Color", Color) = (1, 1, 1, 1)
        _RimWidth ("Rim Width (View Space)", Range(0.001, 0.1)) = 0.01
        _DepthThreshold ("Depth Threshold", Range(0.0001, 0.1)) = 0.01
        _FresnelMask ("Fresnel Mask", Range(0.0, 1.0)) = 0.5


        [Header(Colour Modulation)]
        _ColourModulation("Colour Modulation" ,Color) = (1,1,1,1)//调色
        _Saturation("Saturation", Range(0,2)) = 1.0//饱和度调节
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

            // 纹理声明
            TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
            TEXTURE2D(_AOMap);          SAMPLER(sampler_AOMap);
            TEXTURE2D(_SpecularMap);    SAMPLER(sampler_SpecularMap);
            TEXTURE2D(_RampMap);        SAMPLER(sampler_RampMap);
            TEXTURE2D(_RampID);         SAMPLER(sampler_RampID);

            // 材质属性常量缓冲区
            CBUFFER_START(UnityPerMaterial)
                // 基础纹理
                float4 _BaseMap_ST;
                
                // AO
                float4 _AOMap_ST;
                half _AOIntensity;

                // 高光项
                float4 _SpecularMap_ST;
                half _SpecularPower;
                half _SpecularRegion;
                
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
            CBUFFER_END

            half GetrampV(half3 rampIDtu)
            {
                half v = 0.1;
                if (rampIDtu.r>0.6){
                    v=0.9;
                }
                if (rampIDtu.g>0.6){
                    v=0.5;
                }
                if (rampIDtu.b>0.6){
                    v=0.3;
                }
                return v;
            }

            float4 TransformHClipToViewPortPos(float4 positionCS)
            {
                float4 o = positionCS * 0.5f;
                o.xy = float2(o.x, o.y * _ProjectionParams.x) + o.w;
                o.zw = positionCS.zw;
                return o / o.w;
            }

            struct Attributes
            {
                float4 positionOS : POSITION;   // 模型空间坐标
                float2 uv0        : TEXCOORD0;  // 主纹理 UV
                float2 uv1        : TEXCOORD1;  // 高光贴图 UV
                float3 normalOS   : NORMAL;     // 模型空间法线
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION; // 裁剪空间坐标
                float2 uv0          : TEXCOORD0;   // 主纹理 UV
                float2 uv1          : TEXCOORD1;   // 高光贴图 UV
                float3 normalWS     : TEXCOORD2;   // 世界空间法线
                float3 normalVS     : TEXCOORD3;   // 观察空间法线
                float3 positionVS   : TEXCOORD4;   // 观察空间坐标
                float4 positionNDC  : TEXCOORD5;   // NDC空间坐标
                float3 positionWS   : TEXCOORD6;   // 世界空间坐标
            };

        ENDHLSL

        pass
        {
            Name "UniversalForward"//给pass通道命名

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Cull back //背面剔除关闭

            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag

                Varyings vert(Attributes i)
                {
                    Varyings o;

                    VertexPositionInputs posInputs = GetVertexPositionInputs(i.positionOS.xyz);
                    VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS);//转换法线空间

                    // 空间转换
                    o.positionCS = posInputs.positionCS;
                    o.positionVS = posInputs.positionVS;
                    o.positionNDC = posInputs.positionNDC;
                    o.positionWS = posInputs.positionWS;

                    // UV 传递（应用 Tiling/Offset）
                    o.uv0 = TRANSFORM_TEX(i.uv0, _BaseMap);
                    o.uv1 = TRANSFORM_TEX(i.uv1, _SpecularMap);

                    // normal
                    o.normalWS = normalInput.normalWS;//将世界坐标法线传递给输出变量
                    o.normalVS = TransformWorldToViewDir(normalInput.normalWS, true);
                    
                    return o;
                }

                half4 frag(Varyings i) : SV_TARGET
                {
                    // 采样光源
                    Light light = GetMainLight();

                    // Lambert Diffuse
                    half4 basecolor    = SAMPLE_TEXTURE2D(_BaseMap,    sampler_BaseMap,    i.uv0);
                    half4 specularMap  = SAMPLE_TEXTURE2D(_SpecularMap, sampler_SpecularMap, i.uv1);
                    half3 N = normalize(i.normalWS);
                    half3 L = normalize(light.direction);
                    half NdotL = saturate(dot(N, L));
                    half halfLambert = saturate(NdotL * 0.5 + 0.5); //半lambert 
                    halfLambert = halfLambert * halfLambert;// * halfLambert; //增加效果

                    // AO 强度调节：1 = 无AO效果，ao值越小遮蔽越强
                    half ao = SAMPLE_TEXTURE2D(_AOMap,sampler_AOMap,i.uv0);
                    ao = lerp(1.0, ao, _AOIntensity);
                    #if _USE_AO_MAP
                        half ambient = halfLambert * ao;
                    #else
                        half ambient = halfLambert;
                    #endif
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

                    // 高光（大于0.3使用）
                    if(halfLambert > 1- _SpecularRegion)
                    {
                        color.rgb = lerp(color.rgb,lerp(color.rgb , color.rgb+specularMap.a , halfLambert),_SpecularPower);
                    }

                    return half4(color.rgb,basecolor.a);
                }

            ENDHLSL
        }
    }
}
