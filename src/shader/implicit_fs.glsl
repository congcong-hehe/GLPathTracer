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

uniform Material materials[5];
uniform uint frame_count;
uniform sampler2D imgTex;
uniform Camera camera;
uniform Triangle tris[12];
uniform vec3 aabb_min;
uniform vec3 aabb_max;

in vec2 TexCoords;
out vec4 FragColor;

uint static_seed;

// Reduced Affine Arithmetic
vec3 IAtoRAA(vec2 ia)   // 区间算术转化为仿射算术
{
    vec3 raa;
    raa.x = (ia.x + ia.y) / 2.0;
    raa.y = (ia.y - ia.x) / 2.0;
    raa.z = 0;
    return raa;
}

float raa_radius(vec3 raa)
{
    return abs(raa.y) + raa.z;
}

vec3 add_num(vec3 raa, float num)
{
    raa.x += num;
    return raa;
}

vec3 sub_num(vec3 raa, float num)
{
    raa.x -= num;
    return raa;
}

vec3 mul_num(vec3 raa, float num)
{
    raa.x *= num;
    raa.y *= num;
    raa.z *= abs(num);
    return raa;
}

vec3 add_raa(vec3 raa, vec3 other)
{
    raa += other;
    return raa;
}

vec3 sub_raa(vec3 raa, vec3 other)
{
    raa.x -= other.x;
    raa.y -= other.y;
    raa.z += other.z;
    return raa; 
}

vec3 mul_raa(vec3 raa, vec3 other)
{
    vec3 ans;
    ans.x = raa.x * other.x;
    ans.y = raa.x * other.y + raa.y * other.x;
    ans.z = abs(raa.x) * other.z + abs(other.x) * raa.z + (abs(raa.y) + raa.z) * (abs(other.y) + other.z);
    return ans;
}

vec3 pow_num(vec3 raa, int num)
{
    vec3 ans = raa;
    for(int i = 1; i < num; ++i)
    {
        ans = mul_raa(ans, raa);
    }
    return ans;
}

bool rejectTest(vec3 raa_t, vec3 enter, vec3 span)
{
    vec3 raa_x = add_num(mul_num(raa_t, span.x), enter.x);
    vec3 raa_y = add_num(mul_num(raa_t, span.y), enter.y);
    vec3 raa_z = add_num(mul_num(raa_t, span.z), enter.z);

    vec3 raa_x2 = mul_raa(raa_x, raa_x);
    vec3 raa_y2 = mul_raa(raa_z, raa_z);
    vec3 raa_z2 = mul_raa(raa_y, raa_y);
    vec3 raa_z3 = mul_raa(raa_y, raa_z2);
    
    vec3 left = raa_x2 + mul_num(raa_y2, 9.0 / 4.0) + raa_z2;
    left = pow_num(sub_num(left, 1), 3);
    vec3 right = mul_raa(raa_x2, raa_z3) + mul_num(mul_raa(raa_y2, raa_z3), 9.0 / 80.0);
    vec3 r = left - right;

    float radius = raa_radius(r);
    float low = r.x - radius;
    float high = r.x + radius;
    if(low < 0 && high > 0)
        return true;
    else return false;
}

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

bool hitImplicitSurface(Ray ray, float t_min, float t_max, out Intersection inter)
{
    vec3 a = (aabb_min - ray.ori) / ray.dir;
    vec3 b = (aabb_max - ray.ori) / ray.dir;

    float t_enter = max(max(min(a.x, b.x), min(a.y, b.y)), min(a.z, b.z));
    float t_exit = min(min(max(a.x, b.x), max(a.y, b.y)), max(a.z, b.z));

    if(t_enter > t_exit || t_exit < 0)
        return false;
    
    vec3 vec_enter = ray.ori + t_enter * ray.dir;
    vec3 vec_span = ray.dir * (t_exit - t_enter);
    vec2 ia = vec2(0.0, 1.0);
    float t_span = 0.5;
    int d_max = 6;
    int d = 0;

    for(int i = 0; i < 30; ++i) // 设定一个循环的上限，不然程序会崩溃
    {
        ia.y = ia.x + t_span;
        if(ia.y > 1.0) break;
        vec3 aa_t = IAtoRAA(ia);
        if(rejectTest(aa_t, vec_enter, vec_span))
        {
            if(d == d_max)
            {
                float t = (ia.x + ia.y) / 2;
                if(t < t_min || t > t_max) return false;
                inter.position = vec_enter + t * vec_span;
                inter.t = ((inter.position - ray.ori) / ray.dir).x;
                inter.normal = normalize(vec3(inter.position));
                inter.material = materials[2];
                return true;
            }
            t_span *= 0.5;
            d ++;
            continue;
        }
        ia.x = ia.y;
    }

    return false;
}

bool hitWorld(Ray ray, out Intersection inter)
{
    float closet_inter_t = INFINITY;
    bool if_tag = false;
    Intersection inter_temp;
    for(int i = 0; i < 12; ++i)
    {
        if(hitTriangle(ray, tris[i], 0, closet_inter_t, inter_temp))
        {
            if_tag = true;
            closet_inter_t = inter_temp.t;
            inter = inter_temp;
        }
    }
    if(hitImplicitSurface(ray, 0, closet_inter_t, inter_temp))
    {
        if_tag = true;
        closet_inter_t = inter_temp.t;
        inter = inter_temp;
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
            result += vec3(2) * indir_filtration * NdotL / PDF;
            break;
        }
        
        if(new_inter.material.isEmissive)
        {
            result += new_inter.material.color * indir_filtration * NdotL / PDF;
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
    // Intersection inter;
    // if(hitImplicitSurface(ray, 0, INFINITY, inter))
    // {
    //     color = vec3(1);
    // }

    vec3 textureColor = texture(imgTex, TexCoords).rgb;
    FragColor = vec4(mix(textureColor, color, 1.0 / float(frame_count)), 1.0);
}