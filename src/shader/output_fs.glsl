#version 330

out vec4 FragColor;
in vec2 TexCoords;

uniform sampler2D imgTex;

void main()
{
    vec3 color = texture(imgTex, TexCoords).rgb;
    FragColor = vec4(pow(color, vec3(1.0 / 2.2)), 1.0);
}