#version 330 core

#define WIDTH 800
#define HEIGHT 600

#define DEPTH 5

#define INFINITY 100000000.0
#define PI 3.141592653
#define EPSILON 0.00001

struct Material
{
    bool isEmissive;    // 是否发光
    vec3 color; // 颜色
    float specularRate; // 反射光的占比
    float roughness;    // 粗糙度
    float refractRate;  // 折射光占比
    float refractAngle; // 折射率
    float refractRoughness; // 折射粗糙度
};

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

struct Triangle
{
    vec3 p0, p1, p2;    // 位置
    vec3 n0, n1, n2;    // 法线
    // Material material;
};

struct Intersection
{
    vec3 position;
    float t;
    vec3 normal;
    Material material;
};

uniform uint frame_count;

// 生成随机数https://blog.demofox.org/2020/05/25/casual-shadertoy-path-tracing-1-basic-camera-diffuse-emissive/
uint seed = uint(
    uint((gl_FragCoord.x * 0.5 + 0.5) * WIDTH)  * uint(1973) + 
    uint((gl_FragCoord.y * 0.5 + 0.5) * HEIGHT) * uint(9277) + 
    uint(frame_count) * uint(26699)) | uint(1);

uint wang_hash(inout uint seed) {
    seed = uint(seed ^ uint(61)) ^ uint(seed >> uint(16));
    seed *= uint(9);
    seed = seed ^ (seed >> 4);
    seed *= uint(0x27d4eb2d);
    seed = seed ^ (seed >> 15);
    return seed;
}
 
float rand() {
    return float(wang_hash(seed)) / 4294967296.0;
}

// 半球面均匀采样
vec3 sampleHemisphere()
{
    float z = rand();
    float r = max(0, sqrt(1 - z*z));
    float phi = 2.0 * PI * rand();
    return vec3(r * cos(phi), r * sin(phi), z);
}

// 将半球上的光线方向转换为世界方向
vec3 toWorld(vec3 v, vec3 normal)
{
    vec3 B, C;
	if (abs(normal.x) > abs(normal.y))
	{
		float inv_len = 1.0 / sqrt(normal.x * normal.x + normal.z * normal.z);
		C = vec3(normal.z * inv_len, 0.0f, -normal.x * inv_len);
	}
	else
	{
		float inv_len = 1.0f / sqrt(normal.y * normal.y + normal.z * normal.z);
		C = vec3(0.0f, normal.z * inv_len, -normal.y * inv_len);
	}
	B = cross(C, normal);
	return B * v.x + C * v.y + normal * v.z;
}

bool hitSphere(Ray ray, Sphere sphere, float t_min, float t_max, out Intersection inter)
{
    vec3 oc = ray.ori - sphere.center;
    float a = dot(ray.dir, ray.dir);
    float h = dot(oc, ray.dir);
    float c = dot(oc, oc) - sphere.radius * sphere.radius;
    float discriminant = h * h - a * c;

    if(discriminant < 0)
    {
        return false;
    }

    float sqrtd = sqrt(discriminant);
    float root = (-h - sqrtd) / a;
    if(root < t_min || root > t_max)
    {
        root = (-h + sqrtd) / a;
        if(root < t_min || root > t_max)
        {
            return false;
        }
    }

    inter.t = root;
    inter.position = pointAt(root, ray);
    inter.normal = (inter.position - sphere.center) / sphere.radius;

    if(dot(inter.normal, ray.dir) > 0)  // 如果光源打到球的内部
    {
        inter.normal = -inter.normal;
    }

    return true;
}

bool hitTriangle(Ray ray, Triangle tri, float t_min, float t_max, out Intersection inter)
{
    vec3 edge1 = tri.p1 - tri.p0;
    vec3 edge2 = tri.p2 - tri.p0;

    vec3 s = ray.ori - tri.p0;
    vec3 s1 = cross(ray.dir, edge2);
    vec3 s2 = cross(s, edge1);

    float a = dot(s1, edge1);
    if(abs(a) < EPSILON || a < 0)
        return false;
    float t = dot(s2, edge2) / a;
    if(t < EPSILON || t < t_min || t > t_max)
        return false;
    float b1 = dot(s1, s) / a;
    if(b1 < 0 || b1 > 1)
        return false;
    float b2 = dot(s2, ray.dir) / a;
    if(b2 < 0 || b1 + b2 > 1)
        return false;
    vec3 norm = tri.n0 * (1 - b1 - b2) + tri.n1 * b1 + tri.n2 * b2;
    if(dot(norm, ray.dir) > 0)
        return false;
    
    inter.t = t;
    inter.position = pointAt(t, ray);
    // inter.material = tri.material;
    inter.normal = norm;

    return true;
}


uniform Camera camera;
uniform Sphere spheres[2];

bool hitWorld(Ray ray, out Intersection inter)
{
    float closet_inter_t = INFINITY;
    bool if_tag = false;
    for(int i = 0; i < 2; ++i)
    {
        Intersection inter_temp;
        if(hitSphere(ray, spheres[i], 0, closet_inter_t, inter_temp))
        {
            if_tag = true;
            closet_inter_t = inter.t;
            inter = inter_temp;
        }
    }
    return if_tag;
}

vec3 trace(Intersection inter)
{
    vec3 indir = vec3(1);

    for(int i = 0; i < DEPTH; ++i)
    {
        vec3 wi = toWorld(sampleHemisphere(), inter.normal);

        Ray ray;
        ray.dir = wi;
        ray.ori = inter.position;
        
        Intersection new_inter;
        if(!hitWorld(ray, new_inter))
        {
            float t = 0.5 * (normalize(ray.dir).y + 1.0);
            indir *= (1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);
            break;
        }

        indir *= inter.normal;

        inter = new_inter;
    }

    return indir;
}

out vec4 FragColor;
uniform sampler2D imgTex;
in vec2 TexCoords;

uniform Triangle tri;

void main()
{
    float u = (gl_FragCoord.x - 0.5 + rand()) / (WIDTH - 1);
    float v = (gl_FragCoord.y - 0.5 + rand()) / (HEIGHT - 1);
    Ray ray;
    ray.ori = camera.ori;
    ray.dir = camera.lower_left_corner + u * camera.horizontal + v * camera.vertical - camera.ori;

    vec3 color = vec3(0);
    Intersection inter;
    // if(hitWorld(ray, inter))
    // {
    //     color += trace(inter);
    // }
    // else // 如果没有命中
    // {
    //     float t = 0.5 * (normalize(ray.dir).y + 1.0);
    //     color += ((1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0));
    // }
    if(hitTriangle(ray, tri, 0, INFINITY, inter))
        color = vec3(1.0, 0.0, 0.0);
    else color = tri.p0;
    // if(hitSphere(ray, spheres[0], 0, INFINITY, inter))
    //     color = vec3(1.0, 0.0, 0.0);

    vec4 pixColor =  vec4(pow(color, vec3(1.0 / 2.2)), 1.0);
    vec4 textureColor = texture(imgTex, TexCoords);
    FragColor = mix(textureColor, pixColor, 1.0 / (frame_count));
}