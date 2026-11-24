/*
 * 多段法线阴影  /  Unity URP 教学版
 *
 * 阅读顺序
 * 1. ForwardVertex 把网格位置、法线和切线转到世界空间。
 * 2. DecodeNormalWS 用贴图 RG 重建切线空间法线，再转到世界空间。
 * 3. ForwardFragment 计算 N·L、B 通道偏置和可选的投影影响，得到色阶坐标 x。
 * 4. EvaluatePalette 根据 x 混合七个预设颜色。
 * 5. 将色阶配色用于主光，再与环境光、底色及雾合成。
 *
 * 观察方法
 * - 把材质挂到球体上，旋转场景方向光。默认由网格法线产生色阶。
 * - Debug View 选 LightingCoordinate 看 x 的灰度，选 Palette 看七段配色。
 * - Center 决定交界的位置，Width 决定交界的过渡范围。改一项就能看出区别。
 * - 使用 RG+B 打包图时，设为 Default 并关闭 sRGB。RG 法线强度可从 1 开始，
 *   B 偏置强度可从 2 开始。两个强度各自控制对应的数据通道。
 *
 * Forward 负责着色和接收主光投影。ShadowCaster 写入光源的阴影图。
 * DepthOnly 供相机深度预通道使用。
 */
Shader "Effects/Multi-Band Normal Shadow"
{
    Properties
    {
        [Header(Surface)]
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Color", Color) = (1, 1, 1, 1)

        // RG 存切线空间法线 XY，B 存明暗偏置。强度默认是 0，
        // 所以即使没有绑定数据贴图，也能用网格法线观察全部色阶。
        [Header(Packed Normal and Bias)]
        _NormalDataMap ("Packed Data (RG Normal, B Bias)", 2D) = "gray" {}
        _NormalStrength ("RG Normal Strength", Range(0, 2)) = 0
        _BlueBiasStrength ("B Bias Strength", Range(0, 3)) = 0

        // 七个颜色是主光的 RGB 乘色。材质底色会在最后参与合成。
        // 相邻两段的色差越大，同样的过渡宽度下，分界越容易看清。
        [Header(Band Colors)]
        _DeepColor ("1  Deep Shadow", Color) = (0.20, 0.25, 0.43, 1)
        _ShadowColor ("2  Shadow", Color) = (0.42, 0.46, 0.65, 1)
        _SoftShadowColor ("3  Soft Shadow", Color) = (0.64, 0.65, 0.79, 1)
        _MidColor ("4  Midtone", Color) = (0.83, 0.83, 0.92, 1)
        _WarmColor ("5  Warm Transition", Color) = (1.0, 0.78, 0.63, 1)
        _LightColor ("6  Light", Color) = (0.98, 0.93, 0.86, 1)
        _BrightColor ("7  Bright Light", Color) = (1, 1, 1, 1)

        // 每条分界一对参数。Center 是中点，Width 是过渡的总宽度。
        // Center 往正方向移时，像素需要更大的受光量才会进入下一段。
        [Header(Transition Centers and Full Widths)]
        _Center1 ("1 to 2 Center", Range(-1, 1)) = -0.72
        _Width1 ("1 to 2 Width", Range(0, 1)) = 0.30
        _Center2 ("2 to 3 Center", Range(-1, 1)) = -0.36
        _Width2 ("2 to 3 Width", Range(0, 1)) = 0.06
        _Center3 ("3 to 4 Center", Range(-1, 1)) = -0.04
        _Width3 ("3 to 4 Width", Range(0, 1)) = 0.28
        _Center4 ("4 to 5 Center", Range(-1, 1)) = 0.26
        _Width4 ("4 to 5 Width", Range(0, 1)) = 0.09
        _Center5 ("5 to 6 Center", Range(-1, 1)) = 0.45
        _Width5 ("5 to 6 Width", Range(0, 1)) = 0.06
        _Center6 ("6 to 7 Center", Range(-1, 1)) = 0.76
        _Width6 ("6 to 7 Width", Range(0, 1)) = 0.32

        [Header(Lighting)]
        _DirectStrength ("Main Light Strength", Range(0, 2)) = 1
        _AmbientStrength ("Ambient Strength", Range(0, 1)) = 0.15
        _CastShadowStrength ("Cast Shadow Influence", Range(0, 1)) = 0
        _CastShadowLimit ("Occluded Lighting Coordinate", Range(-1, 1)) = -0.36
        [Enum(Lit,0,Palette,1,LightingCoordinate,2)] _DebugView ("Debug View", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }
        Cull Back

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        TEXTURE2D(_BaseMap);
        SAMPLER(sampler_BaseMap);
        TEXTURE2D(_NormalDataMap);
        SAMPLER(sampler_NormalDataMap);

        // 材质的数值与颜色由 UnityPerMaterial 提供，三个 Pass 共用同一份布局。
        // 纹理独立声明。纹理的 _ST.xy 是 UV 缩放，_ST.zw 是 UV 偏移。
        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _NormalDataMap_ST;
            float4 _BaseColor;
            float4 _DeepColor;
            float4 _ShadowColor;
            float4 _SoftShadowColor;
            float4 _MidColor;
            float4 _WarmColor;
            float4 _LightColor;
            float4 _BrightColor;

            float _NormalStrength;
            float _BlueBiasStrength;
            float _Center1, _Center2, _Center3, _Center4, _Center5, _Center6;
            float _Width1, _Width2, _Width3, _Width4, _Width5, _Width6;
            float _DirectStrength;
            float _AmbientStrength;
            float _CastShadowStrength;
            float _CastShadowLimit;
            float _DebugView;
        CBUFFER_END

        // OS 是物体空间。Tangent.w 携带切线坐标系的方向符号。
        struct MeshInput
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            float2 uv : TEXCOORD0;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct DepthInput
        {
            float4 positionCS : SV_POSITION;
            UNITY_VERTEX_OUTPUT_STEREO
        };
        ENDHLSL

        Pass
        {
            // 前向着色 Pass。屏幕像素的最终颜色从这里输出。
            Name "Forward"
            Tags { "LightMode" = "UniversalForward" }
            ZWrite On

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex ForwardVertex
            #pragma fragment ForwardFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            // 顶点送往片元的数据。CS 是裁剪空间，WS 是世界空间。
            // 法线和切线经过光栅化插值，片元阶段会重新校正方向。
            struct SurfaceInput
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float2 uv : TEXCOORD3;
                half fog : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            SurfaceInput ForwardVertex(MeshInput input)
            {
                SurfaceInput output = (SurfaceInput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs pos = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs basis = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                // 裁剪空间位置用于光栅化，世界空间位置用于查询阴影。
                // GetOddNegativeScale() 修正镜像缩放时切线坐标系的手性。
                output.positionCS = pos.positionCS;
                output.positionWS = pos.positionWS;
                output.normalWS = basis.normalWS;
                output.tangentWS = float4(basis.tangentWS, input.tangentOS.w * GetOddNegativeScale());
                output.uv = input.uv;
                output.fog = ComputeFogFactor(pos.positionCS.z);
                return output;
            }

            // 打包法线解码。先恢复切线空间里的 XYZ，再用 TBN 转到世界空间。
            // TBN 的三个轴依次是切线 T、副切线 B、网格法线 N。
            float3 DecodeNormalWS(SurfaceInput input, float2 packedXY)
            {
                float3 normalWS = SafeNormalize(input.normalWS);

                // 减去切线沿法线的分量，使插值后的 T 与 N 重新垂直。
                // RG 强度为 0 或切线无效时，直接使用网格法线。
                float3 tangentWS = input.tangentWS.xyz - normalWS * dot(input.tangentWS.xyz, normalWS);
                float tangentLengthSq = dot(tangentWS, tangentWS);
                if (_NormalStrength <= 0 || tangentLengthSq <= 1e-6 || abs(input.tangentWS.w) < 0.5)
                    return normalWS;

                tangentWS *= rsqrt(tangentLengthSq);
                float3 bitangentWS = cross(normalWS, tangentWS) * input.tangentWS.w;
                // RG 从 0～1 映射到 −1～1。RG=(0.5,0.5) 时，XY 为 0。
                // 限制 XY 的长度，再由单位法线关系 X²+Y²+Z²=1 求出正半球的 Z。
                float2 xy = (packedXY * 2.0 - 1.0) * _NormalStrength;
                xy *= rsqrt(max(1.0, dot(xy, xy)));
                float z = sqrt(saturate(1.0 - dot(xy, xy)));
                // 将三个分量沿着 T、B、N 三个世界空间轴展开。
                return SafeNormalize(tangentWS * xy.x + bitangentWS * xy.y + normalWS * z);
            }

            // 某条分界的混合因子。区间左侧为 0，右侧为 1，中点为 0.5。
            // 例如 Center=-0.36、Width=0.06 时，过渡约为 -0.39 到 -0.33。
            float BandTransition(float x, float center, float width, float pixelWidth)
            {
                // 用屏幕上 x 的变化量限制最窄过渡，减轻细边界的闪烁。
                // 即使 Width 为 0，smoothstep 的两端仍会留出间距。
                float halfWidth = 0.5 * max(max(width, pixelWidth), 1e-4);
                return smoothstep(center - halfWidth, center + halfWidth, x);
            }

            // 从深影色开始，依次把下一段颜色混进来。
            // 当窄过渡彼此分离时，交界之间会留下单一配色的区间。
            float3 EvaluatePalette(float x)
            {
                float pixelWidth = fwidth(x);

                // 约束每个后续中心至少等于前一个中心，保持从暗到亮的顺序。
                // 如果两个过渡重叠，多个颜色会参与同一个像素的混合。
                float center2 = max(_Center1, _Center2);
                float center3 = max(center2, _Center3);
                float center4 = max(center3, _Center4);
                float center5 = max(center4, _Center5);
                float center6 = max(center5, _Center6);

                // lerp(当前颜色, 下一段颜色, t)。t 越大，越接近下一段颜色。
                // 例如默认第二条分界的中心处，阴影色和软阴影色各占一半，
                // 前提是屏幕抗锯齿宽度没有把相邻过渡扩到这个位置。
                float3 color = lerp(_DeepColor.rgb, _ShadowColor.rgb, BandTransition(x, _Center1, _Width1, pixelWidth));
                color = lerp(color, _SoftShadowColor.rgb, BandTransition(x, center2, _Width2, pixelWidth));
                color = lerp(color, _MidColor.rgb, BandTransition(x, center3, _Width3, pixelWidth));
                color = lerp(color, _WarmColor.rgb, BandTransition(x, center4, _Width4, pixelWidth));
                color = lerp(color, _LightColor.rgb, BandTransition(x, center5, _Width5, pixelWidth));
                return lerp(color, _BrightColor.rgb, BandTransition(x, center6, _Width6, pixelWidth));
            }

            half4 ForwardFragment(SurfaceInput input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // ① 准备法线数据。任一通道启用时采样一次贴图，RG 和 B 共用采样结果。
                float3 packed = float3(0.5, 0.5, 0.5);
                if (_NormalStrength > 0 || _BlueBiasStrength > 0)
                {
                    float2 dataUV = TRANSFORM_TEX(input.uv, _NormalDataMap);
                    packed = SAMPLE_TEXTURE2D(_NormalDataMap, sampler_NormalDataMap, dataUV).rgb;
                }
                float3 normalWS = DecodeNormalWS(input, packed.rg);

                // ② 读取 URP 主光。GetShadowCoord 按当前阴影变体选择采样坐标，
                // GetMainLight 返回光方向、颜色、距离衰减与阴影可见度。
                VertexPositionInputs positionInputs = (VertexPositionInputs)0;
                positionInputs.positionWS = input.positionWS;
                positionInputs.positionCS = TransformWorldToHClip(input.positionWS);
                Light mainLight = GetMainLight(GetShadowCoord(positionInputs));

                // ③ 计算色阶坐标 x。N·L 为正表示朝光，为负表示背光。
                // B 偏置移动 x。B=0.5 时偏置为 0，B=0.4 且强度为 2 时偏置为 -0.4。
                // 因此同样是 N·L=0.5，后者会用 x=0.1 查找配色。
                float x = dot(normalWS, mainLight.direction) + (packed.b * 2.0 - 1.0) * _BlueBiasStrength;
                // ④ 可选的投影接收。被遮挡时，x 朝较暗的坐标上限移动。
                // 默认影响强度为 0，方便先观察由法线和贴图形成的色阶。
                float occlusion = (1.0 - mainLight.shadowAttenuation) * _CastShadowStrength;
                x = lerp(x, min(x, _CastShadowLimit), occlusion);
                // ⑤ 把一维受光坐标转换成 RGB 色阶配色。
                float3 palette = EvaluatePalette(x);

                // 调试先看原因再看结果。灰度显示 x，Palette 显示配色函数的输出。
                // 灰度只映射 -1～1，超出范围的值会显示为纯黑或纯白。
                if (_DebugView > 1.5)
                {
                    half gray = saturate(x * 0.5 + 0.5);
                    return half4(gray, gray, gray, 1.0);
                }
                if (_DebugView > 0.5)
                    return half4(palette, 1.0);

                // ⑥ 颜色合成。主光带有色阶配色，SH 提供随法线变化的环境光。
                // 将两种光相加并乘底色，最后按距离混入场景雾。
                float2 baseUV = TRANSFORM_TEX(input.uv, _BaseMap);
                half3 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV).rgb * _BaseColor.rgb;
                half3 direct = palette * mainLight.color * mainLight.distanceAttenuation * _DirectStrength;
                half3 ambient = max(0.0, SampleSH(normalWS)) * _AmbientStrength;
                return half4(MixFog(albedo * (direct + ambient), input.fog), 1.0);
            }
            ENDHLSL
        }

        Pass
        {
            // 投影 Pass。从光源视角写入深度，ColorMask 0 禁止写入颜色。
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex ShadowVertex
            #pragma fragment ShadowFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            float3 _LightDirection;
            float3 _LightPosition;

            DepthInput ShadowVertex(MeshInput input)
            {
                DepthInput output = (DepthInput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float3 worldPos = TransformObjectToWorld(input.positionOS.xyz);
                float3 worldNormal = TransformObjectToWorldNormal(input.normalOS);
                // 点光源和聚光灯按位置求方向，平行光使用固定方向。
                #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
                    float3 lightDirection = SafeNormalize(_LightPosition - worldPos);
                #else
                    float3 lightDirection = _LightDirection;
                #endif

                // 写阴影图前施加 URP 的 shadow bias 以减轻自遮挡伪影。
                // 随后按当前深度方向处理近裁剪面。
                output.positionCS = TransformWorldToHClip(ApplyShadowBias(worldPos, worldNormal, lightDirection));
                #if UNITY_REVERSED_Z
                    output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif
                return output;
            }

            half4 ShadowFragment(DepthInput input) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            // 相机深度 Pass。URP 在需要深度预通道时可调用这个 Pass。
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask R

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex DepthVertex
            #pragma fragment DepthFragment
            #pragma multi_compile_instancing

            DepthInput DepthVertex(MeshInput input)
            {
                DepthInput output = (DepthInput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half DepthFragment(DepthInput input) : SV_Target
            {
                return input.positionCS.z;
            }
            ENDHLSL
        }
    }
    FallBack Off
}