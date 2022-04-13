#version 330 core

#define WIDTH 800
#define HEIGHT 600

struct Ray
{
    vec3 ori;
    vec3 dir;
};

vec3 pointAt(float t, Ray ray)
{
    return ray.ori + t * ray.dir;
}

struct Camera
{
    vec3 ori;
    vec3 horizontal;
    vec3 vertical;
    vec3 lower_left_corner;
};

uniform Camera camera;

out vec4 FragColor;

void main()
{
    float u = (gl_FragCoord.x - 0.5) / (WIDTH - 1);
    float v = (gl_FragCoord.y - 0.5) / (HEIGHT - 1);
    Ray ray;
    ray.ori = camera.ori;
    ray.dir = camera.lower_left_corner + u * camera.horizontal + v * camera.vertical - camera.ori;
    float t = 0.5 * (normalize(ray.dir).y + 1.0);
    FragColor = vec4((1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0), 1.0);
}