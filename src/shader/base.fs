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

struct Sphere
{
    vec3 center;
    float radius;
};

bool hitSphere(Ray ray, Sphere sphere)
{
    vec3 oc = ray.ori - sphere.center;
    float a = dot(ray.dir, ray.dir);
    float b = 2.0 * dot(oc, ray.dir);
    float c = dot(oc, oc) - sphere.radius * sphere.radius;
    float discriminant = b * b - 4 * a * c;
    return discriminant > 0;
}

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
    Sphere sphere;
    sphere.radius = 0.5;
    sphere.center = vec3(0, 0, -1);
    if(hitSphere(ray, sphere))
        FragColor = vec4(1.0, 0.0, 0.0, 1.0);
    else FragColor = vec4((1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0), 1.0);
}