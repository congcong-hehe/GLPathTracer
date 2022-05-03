#version 330 core

#define WIDTH 600
#define HEIGHT 600

#define DEPTH 5

#define INFINITY 100000000.0
#define PI 3.141592653
#define EPSILON 0.00001
#define PDF 1.0 / (2 * PI)

struct Material
{
    bool isEmissive;    // 是否发光
    vec3 color; // 颜色
    float specularRate; // 反射光的占比
    float refractRate;  // 折射光占比
    float refractAngle; // 折射率
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
    uint material_id;
};

struct Triangle
{
    vec3 p0, p1, p2;    // 位置
    vec3 n0, n1, n2;    // 法线
    uint material_id;
};

struct Intersection
{
    vec3 position;
    float t;
    vec3 normal;
    Material material;
};

uniform Material materials[7];
uniform uint frame_count;
uniform sampler2D imgTex;
uniform Camera camera;
uniform Sphere spheres[3];
uniform Triangle tris[12];

in vec2 TexCoords;
out vec4 FragColor;

uint static_seed;

// 生成随机数https://blog.demofox.org/2020/05/25/casual-shadertoy-path-tracing-1-basic-camera-diffuse-emissive/
uint seed = uint(
    uint((gl_FragCoord.x * 0.5 + 0.5) * WIDTH)  * uint(1973) + 
    uint((gl_FragCoord.y * 0.5 + 0.5) * HEIGHT) * uint(9277) + 
    uint(frame_count + static_seed) * uint(26699)) | uint(1);

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
    inter.material = materials[sphere.material_id];

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
    if(a < EPSILON)
        return false;

    float b1 = dot(s1, s);
    if(b1 < 0 || b1 > a)
        return false;

    float b2 = dot(s2, ray.dir);
    if(b2 < 0 || b1 + b2 > a)
        return false;

    float inv_a = 1.0 / a;

    float t = dot(s2, edge2) * inv_a;
    if(t < EPSILON || t < t_min || t > t_max)
        return false;

    b1 *= inv_a;
    b2 *= inv_a;

    vec3 norm = tri.n0;
    if(dot(norm, ray.dir) > 0)
        return false;
    
    inter.t = t;
    inter.position = pointAt(t, ray);
    inter.material = materials[tri.material_id];
    inter.normal = norm;

    return true;
}

bool hitWorld(Ray ray, out Intersection inter)
{
    float closet_inter_t = INFINITY;
    bool if_tag = false;
    for(int i = 0; i < 12; ++i)
    {
        Intersection inter_temp;
        if(hitTriangle(ray, tris[i], 0, closet_inter_t, inter_temp))
        {
            if_tag = true;
            closet_inter_t = inter_temp.t;
            inter = inter_temp;
        }
    }
    for(int i = 0; i < 3; ++i)
    {
        Intersection inter_temp;
        if(hitSphere(ray, spheres[i], 0, closet_inter_t, inter_temp))
        {
            if_tag = true;
            closet_inter_t = inter_temp.t;
            inter = inter_temp;
        }
    }

    return if_tag;
}

vec3 trace(Intersection inter, Ray ray)
{
    // 如果打到光源
    if(inter.material.isEmissive == true)
        return inter.material.color;

    vec3 indir_filtration = vec3(1);
    vec3 result = vec3(0);

    for(int i = 0; i < DEPTH; ++i)
    {
        if(!inter.material.isEmissive)  // 把光源也看做反射项，但是光源的color太大，默认作为vec3（1）
            indir_filtration *= inter.material.color;

        vec3 wi;
        float r = rand();
        if(r < inter.material.specularRate) // 完全镜面反射
        {
            wi = reflect(ray.dir, inter.normal);
        }
        else if(r > inter.material.specularRate && r < inter.material.refractRate)  // 完全折射
        {
            wi = refract(ray.dir, inter.normal, inter.material.refractAngle);
        }
        else
        {
            wi = toWorld(sampleHemisphere(), inter.normal);    //  得到一条光线的方向
        }

        float NdotL = dot(wi, inter.normal);

        ray.dir = wi;
        ray.ori = inter.position;
        
        Intersection new_inter;
        if(!hitWorld(ray, new_inter))
        {
            break;
        }
        
        if(new_inter.material.isEmissive)
        {
            result += new_inter.material.color * indir_filtration * NdotL / PDF;
            break;
        }
        inter = new_inter;
    }

    return result;
}


void main()
{
    float u = (gl_FragCoord.x - 0.5 + rand()) / (WIDTH - 1);
    float v = (gl_FragCoord.y - 0.5 + rand()) / (HEIGHT - 1);
    Ray ray;
    ray.ori = camera.ori;
    ray.dir = normalize(camera.lower_left_corner + u * camera.horizontal + v * camera.vertical - camera.ori);

    vec3 color = vec3(0);
    int spp = 10;
    static_seed = 0u;
    for(int i = 0; i < 10; ++i)
    {
        Intersection inter;
        if(hitWorld(ray, inter))
        {
            color += trace(inter, ray) / spp;
        }
        static_seed ++;
    }

    vec3 textureColor = texture(imgTex, TexCoords).rgb;
    FragColor = vec4(mix(textureColor, color, 1.0 / float(frame_count)), 1.0);
}