#version 330

out vec4 FragColor;
in vec2 TexCoords;

uniform sampler2D imgTex;

vec3 toneMapping(in vec3 c, float limit) {
    float luminance = 0.3*c.x + 0.6*c.y + 0.1*c.z;
    return c * 1.0 / (1.0 + luminance / limit);
}

void main()
{
    vec3 color = texture(imgTex, TexCoords).rgb;
    color = toneMapping(color, 1.5);
    FragColor = vec4(pow(color, vec3(1.0 / 2.2)), 1.0);
}