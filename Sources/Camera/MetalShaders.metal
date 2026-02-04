//
//  MetalShaders.metal
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex_In {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct Vertex_Out {
    float4 position [[position]];
    float2 texCoord;
};

vertex Vertex_Out vertexFunc(Vertex_In in [[stage_in]]) {
    Vertex_Out out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 fragmentFunc(Vertex_Out in [[stage_in]], texture2d<float> texture [[texture(0)]]) {
    constexpr sampler textureSample(mag_filter::linear, min_filter::linear);
    float4 color = texture.sample(textureSample, in.texCoord);
    return color;
}
